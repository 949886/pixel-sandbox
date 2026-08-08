# V3.9.2 Debug / Runtime Profile Organization

本版本只重构调试信息与 Profile 可读性，不修改 Native Simulation、Active Block、Native Seam 或 Collision 算法。

## Debug Overlay

旧 HUD 的主要问题是不同子系统混在长字符串中：Simulation、Collision、Piece、Active Blocks、Seam Flow 和 Pipeline budget 很难快速定位。

新 HUD 使用两栏十个 section：

左栏：

1. WORLD / STREAMING
2. CURRENT CHUNK
3. PIECES / SEAMS
4. GENERATION / QUEUES
5. STRUCTURE / SPECIAL

右栏：

1. SIMULATION
2. ACTIVE BLOCKS
3. CROSS-CHUNK FLOW
4. COLLISION
5. FRAME PIPELINE

顶部统一显示 Profile、Native API 和 Canvas mode，避免各 section 重复显示 API 状态。

## Runtime Profile Inspector

`WorldRuntimeProfile.gd` 使用 Godot `@export_category` 和 `@export_group`，将字段组织为：

- Profile
- Streaming & Generation
- Visuals & Pools
- Pixel Simulation
- Cross-Chunk Flow
- Collision
- Debug
- Legacy Fallback

PC / Mobile `.tres` 的文本顺序同步调整，方便 Git diff 与人工对照。

## 数值兼容

除 Mobile 的纯显示名从 `Mobile PC Budgets` 改为 `Mobile Active Blocks` 外，PC/Mobile Profile 的运行数值保持 V3.9.1 不变。

Native API 仍为 11，不需要重新编译 GDExtension。
