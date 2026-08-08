# Native Cross-Chunk Flow — V3.8

## 目标

V3.7.3 以前，每个 512×512 Chunk 都是独立 `SandSimulation`。Chunk 内的粒子由 C++ 模拟，但跨 Chunk 由 `WorldManager.gd` 低频逐像素补偿：PC 默认 6Hz/2 seams，移动端 3Hz/1 seam。移动端又使用 `simulation_radius = 0`，因此相邻 Chunk 通常不处于 simulation active。

结果是：

- 液体在 seam 堆积后间歇性跳过去；
- 液体只能正下方或单方向水平搬运，无法保持斜向/密度交换语义；
- Gas 不能左右跨 Chunk；
- Smoke 在 Chunk 顶部会把 out-of-bounds 当成阻挡；
- 增大 `border_exchange_hz` 会制造大量 GDScript ↔ GDExtension 调用，但仍不能恢复原生运动规则。

V3.8 将 seam transport 变成 Simulation Tick 的一部分。

## Native API 9

新增：

```text
set_flow_states(states)
exchange_border_with(other, direction, phase)
get_border_flow_activity_mask()
get_native_api_version() -> 9
```

方向：

```text
1 = other 在当前 Simulation 右侧
2 = other 在当前 Simulation 下方
```

Godot 每条 seam 只进行一次 Native 调用，不再对 512 个位置逐个 `get_cell()/set_cell()`。

## Snapshot + Intent + Apply

一次 Native Seam Pass 分成四步：

1. 读取两个 Simulation 的边界快照；
2. 根据粒子类型和目标密度生成 transfer intent；
3. 使用 source/target 占用表消解多个粒子争抢同一目标的冲突；
4. 同时对两个 Simulation 开启 change batch，一次性应用所有 swap。

Seam Pass 运行在两个 Chunk 的 local `step()` 之后，因此跨过去的粒子不会在同一帧再次被目标 Chunk 处理。目标 cell 会继承 sand-slide 原有 `visited` 语义，并在下一次目标 Simulation tick 继续运动。

## 当前跨边界运动规则

### 上下 seam

上方 Chunk → 下方 Chunk：

- Liquid：支持向下和斜下候选；
- Powder：当 MaterialPalette 明确标记为 Powder 时支持正下/斜下；
- 使用 sand-slide 的 `move_and_swap` 密度规则，因此例如 Water 可以与更轻的 Oil 交换。

下方 Chunk → 上方 Chunk：

- Gas：向上跨越。

### 左右 seam

双向支持：

- Liquid；
- Gas；
- 密度允许时进行 swap。

这补齐了旧实现完全缺失的 Gas 横向跨 Chunk。

## Flow State

Built-in sand-slide 的 `Element::get_state()` 无法可靠区分 state-0 的 Powder 与 Static，因此 API 9 增加 `set_flow_states()`。

`SandSimulationConfigurator` 会从当前 `MaterialPalette` 生成 4097 项 Flow State 表：

```text
0 Powder
1 Static
2 Liquid
3 Gas
4 Energy
-1 使用 Native built-in 推断
```

Custom Element 仍可直接使用它自己的完整 state。Built-in Liquid/Gas 可由 Native 状态自动推断；Built-in state-0 默认按 Static 处理，只有 Palette 明确声明为 Powder 时才允许跨 seam，避免岩石等静态材料意外掉出 Chunk。

## Godot 调度顺序

V3.8 每帧核心顺序：

```text
Local SandSimulation.step()
→ Native Seam Bridge
→ Poll Collision Sector dirty
→ Critical collision build
→ Visual repaint
→ Streaming / warmup / recycle
```

旧的独立低频 `border_exchange_hz` 不再用于 API 9 主路径。原字段和旧 GDScript seam 函数仅作为旧 DLL 的兼容 fallback。

## 移动端：Warm + Dynamic Wake

移动端继续保留：

```text
simulation_radius = 0
```

不会永久运行 3×3 Simulation。

新增：

```text
flow_warm_radius = 1
border_neighbor_wake_ms = 750
```

玩家 Chunk 四个正交邻居保持 WARM：

```text
    W
W   A   W
    W
```

- `A`：正常 active simulation；
- `W`：Native Grid 已初始化，但默认不 step。

发生 seam transfer 后，双方调用 `wake_for_flow(750ms)`。被唤醒 Chunk 使用 `background_simulation_hz` 继续本地流动；只要它仍发生实际像素变化，wake 时间自动续期。稳定后自动停止 step，但 Native Grid 保留用于下一次跨边界流动。

如果一个 active/woken Chunk 的动态材料到达已加载但尚未 warm 的外圈 Chunk，API 9 的 edge activity mask 会按需请求该邻居 warmup。未加载 Chunk 仍被视为 sealed boundary，材料不会丢失或复制。

## 新配置

`WorldRuntimeProfile`：

```text
flow_warm_radius = 1
border_flow_max_seams_per_frame = 16
border_neighbor_wake_ms = 750
```

PC 和 Mobile 当前使用相同值。

以下旧字段已 deprecated，仅用于 API < 9 fallback：

```text
border_exchange_hz
border_seams_per_tick
```

## F1 调试

F1 的详情区新增：

```text
Native flow: yes/fallback
seams N
moved N
warm R1
wake 750ms
```

正确编译后应同时看到：

```text
native yes(api 9)
Native flow: yes
```

## 与 V3.7 Collision Sector 的关系

Native Seam 内部仍通过两个 Simulation 的 `set_cell()` 应用 swap，因此 API 8 的：

- Occupancy bitset；
- Removed/Added flags；
- 64×64 Sector revision；
- conservative snapshot；
- collision-first added-solid rule；

全部继续生效。跨 Chunk 运输不绕过动态碰撞系统。

## 当前明确未覆盖

V3.8 主要解决 **transport continuity**。以下跨边界邻域反应仍属于下一阶段 Ghost Halo：

- `touch_count()` 跨 Chunk；
- `cardinal_touch_count()` 跨 Chunk；
- Fire ↔ Wood 跨 seam；
- Water ↔ Lava 跨 seam；
- `is_on_fire()` / `is_cold()` 跨 seam；
- infectious / attractive 等邻域逻辑。

也就是说，液体和气体现在可以自然通过 Chunk 边界，但“隔着 seam 相邻的两种材料发生化学/温度反应”还需要 V3.8.x/V3.9 的 Ghost Halo。

## 构建

Windows：

```bat
cd extensions\sand-slide
build_windows_collision_sectors.bat
```

完成后完全关闭并重新打开 Godot，F1 确认 API 9。

Smoke test：

```bat
godot --headless --path game res://tests/CollisionSectorSmokeTest.tscn
godot --headless --path game res://tests/NativeSeamBridgeSmokeTest.tscn
```
