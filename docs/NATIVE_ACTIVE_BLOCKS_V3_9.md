# Native Active Block Simulation — V3.9

## 目标

V3.8.1 已经让材料能够通过 Native Seam Bridge 连续跨 World Chunk，但 PC 仍采用“当前 Chunk 60Hz、周围 Chunk 12Hz”的时间降频来控制成本。结果是水、烟、火进入邻 Chunk 后视觉和物理时间尺度会明显降低。

V3.9 将 `SandSimulation` 原有的 16×16 内部 `chunks[]` 从“非空气计数”升级为真正的 **Simulation Blocks**。世界 Chunk 仍然是 512×512；Block 只负责 Native 模拟调度。

```text
World Chunk          512 × 512
Collision Sector      64 × 64
Simulation Block      16 × 16
```

一个 512×512 SandSimulation 包含 32×32 = 1024 个 Simulation Blocks；一个 Collision Sector 正好包含 4×4 个 Blocks。

## 旧实现的问题

旧 `chunks[]` 只统计每个 16×16 区域的非 Air 像素数量：

```cpp
if (chunks[chunk] == 0) continue;
```

因此全是 Rock/Metal/Wood 的静态区域虽然永远不变化，只要非空，仍会在每个 Tick 扫描最多 256 个 cell 并调用 `Element::process()`。

这就是为什么 3×3 World Chunk 全部 60Hz 的成本过高，之前不得不将邻 Chunk 降到 12Hz。

## Block 状态

V3.9 使用三态调度：

```text
ACTIVE -> COOLING -> SLEEPING
```

- `ACTIVE`：本 Tick 正常扫描。
- `COOLING`：最近没有净 cell 变化，但继续观察数个 Tick。
- `SLEEPING`：完全跳过该 16×16 Block。

默认：

```text
block_sleep_after_quiet_ticks = 4
```

### Active Now / Active Next

当前 Tick 使用固定 `block_active_now` 快照。

`set_cell()` 在模拟内部产生的 Wake 只进入 `block_active_next`，下一逻辑 Tick 才运行，因此扫描顺序不会导致一个粒子从 Block A 移到 Block B 后在同一 Tick 又被 B 再处理。

外部编辑（弹丸、erase_circle、Seam transfer）同时唤醒当前调度，使下一次 `step()` 立即看到变化。

## 3×3 Neighbor Wake

任何真正的 cell identity 改变都会唤醒本 Block 及周围 8 个 Block：

```text
W W W
W X W
W W W
```

这样 Block 边缘的变化可以安全影响邻区：

- Sand / Water 跨 Block 移动；
- Fire 点燃邻区 Wood；
- 爆炸 / erase_circle；
- API 9 Native Seam 跨 World Chunk 搬运；
- 后续 Ghost Halo 邻域反应。

## Activity Policy

Flow State 与 Activity Policy 是两套独立概念。

Flow State 描述材料如何移动：Powder / Static / Liquid / Gas / Energy。

Activity Policy 描述区域是否允许睡眠：

```text
1 INERT
2 MOVABLE
3 REACTIVE
4 AUTONOMOUS
```

### INERT

不会自行变化的纯静态材料。可以快速进入 Sleep。

Pixel Palette 中 2048+ 的生成岩石、遗迹石、装饰金、神殿石等 CustomElement 当前没有 reactivity / alive / autonomous 行为，因此明确设为 INERT。

### MOVABLE

可以移动，但稳定后允许睡眠：Water、Oil、Blood、Powder 等。

外部支撑被删除或邻格变化时会由 3×3 Wake 恢复。

### REACTIVE

自身通常不移动，但周边材料可能触发反应：Wood、Iron、Crystal 等。

REACTIVE Block 在附近存在 MOVABLE 或 AUTONOMOUS 内容时继续保持 Active，避免低概率反应因为 Sleep 永久停止。

### AUTONOMOUS

即使环境不变也可能自行发生时间行为，不能自动睡眠。例如 Fire、生命元素、特殊 sand-slide 元素。

未知元素默认 AUTONOMOUS，这是兼容优先的安全策略。只有 MaterialPalette 明确覆盖的 Pixel Game 材料进入睡眠优化。

Default Palette 中额外明确：

- Lava：AUTONOMOUS（会主动产生 Fire / 冷却反应）
- Organic / Grass：AUTONOMOUS（会生长）
- Crystal：REACTIVE（水存在时生长）
- Wood / Metal：REACTIVE
- Water / Oil / Blood：MOVABLE

## visited epoch

旧版使用 `std::vector<bool> visited`，并依靠扫描 cell 时顺手清零。Sleeping Block 不再被扫描后，这种模式会留下 stale visited 状态。

V3.9 改成：

```text
uint16_t visited_epoch[cell]
uint16_t simulation_epoch
```

一个目标在本 Tick 被移动后记录当前 epoch；下一个 Tick epoch 自增，旧标记自动失效，不需要遍历 Sleeping Block 清理。

16-bit epoch 约 65,535 Tick 后回绕，此时统一清零一次 visited 数组。

## PC 时间尺度

PC Profile 现在：

```text
simulation_radius = 1
simulation_hz = 60
background_simulation_hz = 60
```

即玩家周围 3×3 World Chunk 使用统一 60Hz 逻辑时间。

区别是每个 SandSimulation 不再按“整个 512×512 是否非空”决定成本，而只扫描真正 Active 的 16×16 Blocks。

例如一个静态矿井 Chunk 即使有数十万 Rock 像素，稳定后绝大多数 Block 都可以 Sleep。

## 与 API 9 Native Seam 的关系

Native Seam `exchange_border_with()` 最终仍调用两个 Simulation 的 `set_cell()`。

因此跨 Chunk Water / Gas / Powder 搬运会自然：

```text
Source edge Block wake
Destination edge Block wake
```

移动端现有 World Chunk `WARM -> Flow Awake` 机制保持不变，但 Awake 的 512×512 Simulation 内部也只需处理被唤醒的少量 Blocks。

## 与 Collision Sector 的关系

Active Blocks 和 Collision Sectors 完全独立：

```text
cell change
  |- wake Simulation Blocks (16×16)
  |- dirty Collision Sector  (64×64)
  `- visual dirty
```

V3.7.2 API 8 的 Occupancy Bitset、Removed/Added 分类、Conservative Snapshot、PhysicsServer2D 原子提交全部保留。

## Native API 11

新增接口：

```text
set_activity_modes(PackedInt32Array)
set_block_sleep_after_quiet_ticks(int)
get_block_stats()
get_block_states()
get_block(int)
set_block_size(int)
```

V3.9.1 起旧 `get_chunk()` / `set_chunk_size()` 已从声明、实现与 ClassDB 绑定中彻底删除；Painting Demo 与运行时代码统一迁移到 `get_block()` / `set_block_size()`。Native 内部不再使用 `chunks[]`、`chunk_width`、`chunk_height`。

F1 正确状态：

```text
native yes(api 11)
Native flow: yes
Active blocks: yes
```

### 旧 Native 二进制安全回退

V3.9 的 PC Profile 将 3×3 Simulation 区域统一为 60Hz，但只有检测到 API 10+ Active Blocks 后才会对邻居真正启用 60Hz。压缩包内如果仍加载 API 9 旧 DLL，非当前 Chunk 会自动退回 12Hz，避免旧 occupied-block 全扫描在 3×3 范围内被强制拉到 60Hz。重新编译并加载 API 11 后会自动切回 Profile 中的 60Hz。

## F1 Block Stats

新增：

```text
Active blocks: yes · 16px
A/C/S active/cooling/sleeping
occupied
processed blocks
processed elements / scanned cells
wakes
```

这可以直接判断某块地形为什么没有睡眠，以及 Active Block 是否真实减少 Native 扫描量。

## 验证场景

### 静态 512×512

1024 个 INERT Block 经过 4 Tick 后全部 Sleep。下一 Tick：

```text
processed blocks = 0
scanned cells = 0
```

中心单像素外部变化后，仅唤醒中心 3×3 邻域，最多处理 9 Blocks，也就是最多约 2304 个 cell slot，而不是整张 262,144 cell。

### Reactive Interface

REACTIVE 与 MOVABLE 相邻时，即使连续无 cell change 也保持 Active，用来保护低概率 Water/Rock、Crystal/Water 等交互。

### Seam

API 9 Water transfer 到邻 World Chunk 后，目标边缘 Block 自动进入 ACTIVE。

## 本阶段刻意没有做

- Active Block 多线程；
- 每 Tick 的 Block 数硬预算；
- Ghost Halo 跨 Chunk reaction；
- 64×64 Visual Tile 局部纹理上传。

第一版保持“要么一个 Block 完整处理，要么睡眠”，避免引入新的不同步时间片。
