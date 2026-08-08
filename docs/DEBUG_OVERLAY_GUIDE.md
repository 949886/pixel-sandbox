# Debug Overlay 使用说明

当前调试显示分为：

- `F1`：分组式 Runtime HUD。
- `F2`：世界空间 Piece/Socket/Seam 调试。
- `F6`：64×64 Collision Sector 状态。

## 快捷键

| 按键 | 作用 |
| --- | --- |
| `F1` | 显示/隐藏分组式 Runtime HUD |
| `F2` | 显示/隐藏世界调试绘制层 |
| `F3` | 当前 seed 重新生成 |
| `F4` | 下一个 seed 并重新生成 |
| `F5` | 开启/关闭像素模拟 |
| `F6` | 开启/关闭 Collision Sector 调试 |

## F1：新的分组结构

V3.9.2 不再把所有统计挤在 `World / Chunk / Stats / Special` 四个长文本块中。HUD 改为左右两栏，并与 `WorldRuntimeProfile` 的分类保持相近语义。

顶部状态栏：

```text
Profile PC Active Blocks 60Hz · Native API 11 · Canvas ...
```

用于先确认当前 Profile、Native 版本和 Canvas upload mode。

### 左栏：世界与生成

**WORLD / STREAMING**

- Seed / Player Chunk
- Loaded / Pending / Load Radius
- Renderer / Visual Downscale / Renderer Pool
- Chunk 尺寸与 Unit 尺寸

**CURRENT CHUNK**

- Biome / Chunk Type
- Open sides / Intended links
- Structure tags

**PIECES / SEAMS**

- Expected 四边 socket profile
- Actual 四边 socket profile
- Regular pieces / Open sockets / Glue
- Seam repairs / broken expected / broken neighbor

健康状态优先看：

```text
Broken expected/neighbor 0/0
```

**GENERATION / QUEUES**

- Chunk/Special worker 是否启用
- Chunk queue/results
- Ready attach queue
- Special pending/worker queue
- Last generation ms / last uploads

**STRUCTURE / SPECIAL**

- 当前或附近 Special Chunk
- Chamber
- Air units / Placements / Chambers

### 右栏：像素运行时

**SIMULATION**

- Pixel Sim ON/OFF
- Simulation radius
- Foreground / Background / Repaint Hz
- 本帧 simulation ticks

**ACTIVE BLOCKS**

- Block size（当前 16px）
- Active Blocks 能力是否可用
- Active / Cooling / Sleeping / Total
- Occupied / Processed Blocks
- Processed Elements / Scanned Cells / Wakes
- Quiet threshold

调优时最重要的是比较：

```text
Occupied vs Processed
```

稳定场景中 Processed 应显著低于 Occupied。

**CROSS-CHUNK FLOW**

- Native Seam Bridge YES/NO
- 本帧处理 seams
- 实际 moved cells
- Flow Warm Radius
- Neighbor Wake ms

水或气体穿越 Chunk 边界时，`Moved cells` 应出现非零值。

**COLLISION**

- Sector size / count
- Native sector capability
- Dirty / Building / Pending / Unsafe
- Rebuild Hz / commits per physics frame
- F6 状态

重点健康状态：

```text
Dirty 0 · Building 0 · Pending 0 · Unsafe 0
```

静态场景应逐渐回到接近零。

**FRAME PIPELINE**

- 实际 pipeline ms / 总 budget
- 本帧 warm / texture / collision shapes / simulation ticks
- Simulation / Collision / Critical Collision budget
- Attach / Warm / Texture / Recycle budget

这一区用于判断“任务积压”到底来自 Simulation、Collision 还是 Streaming，而不是只看总 FPS。

## Socket 字符

| 字符 | 含义 |
| --- | --- |
| `S` | SOLID |
| `s` | OPEN_SMALL |
| `d` | DOUBLE_OPEN_SMALL |
| `m` | OPEN_MEDIUM |
| `L` | OPEN_LARGE |
| `?` | ANY |

## F2：世界调试绘制层怎么看

世界调试层直接画在世界空间中，用来观察 chunk、piece、socket 和 seam 问题。

---

## Socket Marker：新的空心圆/实心点规则

当前版本已经取消“每个 slot 两个分离圆点”的显示方式，改为一个组合 marker：

```text
空心圆 / 外圈 = Expected socket
实心圆 / 内点 = Actual socket
```

也就是说，同一个 socket slot 现在只占一个位置：

- 外圈颜色代表 `WorldSeamRegistry` 要求这里是什么。
- 内点颜色代表实际生成结果是什么。
- 所有 socket 类型都使用统一 marker 尺寸：外圈半径固定，内点半径固定。
- 大小不再表达 socket 类型；socket 类型只通过颜色和 HUD 字符表达。

### 如何判断是否正常

| 看到的情况 | 含义 |
| --- | --- |
| 外圈和内点颜色一致 | expected 与 actual 一致，正常 |
| 外圈是绿色，内点是灰白 | 规划要求开口，但实际生成成了 solid，严重问题 |
| 外圈是灰白，内点是绿色/青色/黄色 | 规划要求封闭，但实际 piece 开了口 |
| 外圈和内点都是开放类但颜色不同 | 逻辑不一致，例如 small/medium 差异；chunk 外边界应修正到完全一致 |
| 出现红色边缘条 | 该 slot 的 expected 与 actual 不一致 |

---

## Socket Marker 尺寸说明

| 形状 | 表示 | 尺寸规则 |
| --- | --- | --- |
| 空心外圈 | `Expected` / canonical socket | 所有 socket 类型固定同一半径 |
| 实心内点 | `Actual` / 实际生成 socket | 所有 socket 类型固定同一半径 |

大小只用于区分“外圈”和“内点”两层含义，不再用于区分 `open_small`、`open_medium`、`open_large` 等类型。类型统一看颜色或 F1 HUD 的 socket 字符。

---

## Socket Marker 颜色说明

| 颜色 | Socket | 用途 |
| --- | --- | --- |
| 半透明白 / 灰白 | `SOLID` | 封闭边缘；正常情况下不应与开放 socket 连接 |
| 绿色 | `OPEN_SMALL` | 小型通道入口 |
| 浅蓝 | `DOUBLE_OPEN_SMALL` | 两个小入口；目前兼容性更严格，通常需要精确匹配 |
| 青绿色 | `OPEN_MEDIUM` | 中型通道入口 |
| 黄色 | `OPEN_LARGE` | 大型通道入口 |
| 白色 | `ANY` | 通配/未具体化，正常 world seam 中应较少出现 |
| 红色半透明边缘条 | mismatch | `expected != actual`，需要检查 piece 选择、glue 修复或 authored piece socket 标注 |

---

## Chunk 边框颜色说明

`WorldDebugDrawer` 会给不同 chunk 类型画不同颜色的边框/底色：

| 颜色 | Chunk 类型 | 含义 |
| --- | --- | --- |
| 青蓝 | `MAIN_PATH` | 主路径 chunk |
| 绿色 | `CAVE` | 普通洞穴 chunk |
| 黄色 | `BRANCH` | 分支路径 chunk |
| 青绿加粗 | `CHAMBER` | chamber/大型结构区域 |
| 灰色 | `SOLID` | 实心或不参与通路的 chunk |
| 粉紫色 | `SPECIAL` | special chunk 或特殊结构 |

Special chunk 额外会有粉紫色的大矩形框，表示它覆盖的 chunk 范围。

---

## Piece 边框颜色说明

当 `show_piece_bounds` 开启时，每个 placement 会被画出边框：

| 颜色 | Phase | 含义 |
| --- | --- | --- |
| 红色 | `anchor` | anchor piece，通常是 chunk 内的关键结构起点 |
| 绿色 | `regular` | 普通 piece |
| 橙色 | `glue` | glue piece，用于补缝、补洞、衔接局部空间 |
| 高亮红色 | `seam_repair` | seam 修复用 glue。若频繁出现，说明 piece 库或 socket 声明需要优化 |
| 灰色 | 其他 | 未分类/后备 placement |

---

## 推荐排查流程

当你看到某条 chunk 边界不自然或断开时，按这个顺序看：

1. 打开 `F2`，看对应 slot 是否有红色边缘条。
2. 看 marker 外圈颜色：这是全局 seam 要求。
3. 看 marker 内点颜色：这是实际 piece/glue 结果。
4. 如果外圈与内点不同，再看左上角 HUD 的 `Expected` / `Actual` 字符串确认是哪一边、哪个 slot。
5. 如果 HUD 里 `Seam broken E/N` 不是 `0/0`，优先排查该 chunk 的边缘 piece。
6. 如果外圈和内点一致但视觉仍然不对，说明 `PieceDef` 的 socket 声明可能和图片内容不一致，需要检查 authored piece 资源本身。

---

## 当前调试目标

理想情况下，普通相邻 chunk 应满足：

```text
left_chunk.actual_right_profile == right_chunk.actual_left_profile
upper_chunk.actual_bottom_profile == lower_chunk.actual_top_profile
```

同时，每个 chunk 自己也应满足：

```text
expected_top/right/bottom/left == actual_top/right/bottom/left
```

如果这两条都成立，socket/seam 层基本健康；后续问题就更可能来自 piece 图片内容、连通性 flood fill、碰撞生成或材料模拟层。

---

## F6：碰撞 Sector 调试层

V3.7 的碰撞不再按完整 Chunk 重建，而是把 512×512 Canvas 划分成 8×8 个 64×64 Sector。F6 显示的是实际 PhysicsServer2D Active 快照和增量更新状态：

| 颜色 | 状态 |
| --- | --- |
| 青色填充/边线 | 已提交并正在参与物理计算的 Active 碰撞矩形 |
| 红色 Sector | Native revision 已变化，等待构建或重新排队 |
| 黄色 Sector | 正在创建 Staging Rectangle Shape |
| 紫色 Sector | Staging 已完成，等待下一个 physics frame 原子提交 |

F1 HUD 同时显示 `native yes(api 11)` 表示当前 V3.9.2 Native 路径已加载。Collision Sector 能力来自 API 8+；Native Seam 来自 API 9+；Active Blocks 来自 API 10+。若 HUD 显示旧 API 或 fallback，应先检查 DLL/SO/WASM 是否重新编译。
