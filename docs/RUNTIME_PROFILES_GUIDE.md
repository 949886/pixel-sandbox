# Runtime Profiles Guide

`WorldRuntimeProfile` 只负责平台运行时与性能策略；世界内容生成仍由 `WorldGenConfig`、Biome、Special Chunk 和 Piece 资源负责。

当前内置资源：

- `resources/runtime_profiles/pc_runtime_profile.tres`
- `resources/runtime_profiles/mobile_runtime_profile.tres`

`WorldManager.runtime_profile_mode`：

- `Auto`：桌面/编辑器选 PC，移动平台选 Mobile。
- `PC`：强制 PC Profile。
- `Mobile`：强制 Mobile Profile。
- `Custom`：使用 `custom_runtime_profile`。

## Inspector 分组

V3.9.2 起，Profile 不再是一条很长的平铺属性列表。Inspector 顺序与运行时流水线保持一致：

### Profile

只放身份信息：

- `id`
- `display_name`

### Streaming & Generation

**World Window**：

- `load_radius`
- `predictive_prewarm_chunks`

**Workers**：

- Chunk / Special threaded generation
- worker yield
- result backlog
- ready attach queue
- per-frame main-thread upload limit

**Pipeline Budgets & Limits**：

- 总 streaming pipeline budget
- attach / warmup / texture activation / simulation / recycle budget
- warmup slice pixels
- texture activations per frame

### Visuals & Pools

只管理视觉内存和对象池：

- CPU visual image retention
- texture downscale
- normal/special renderer pool limit

### Pixel Simulation

只管理 Simulation cadence：

- enabled
- radius
- iterations
- foreground Hz
- background Hz
- repaint Hz

### Cross-Chunk Flow

只管理 API 9+ Native Seam Bridge：

- dynamic material exchange
- warm radius
- max seams per frame
- neighbor wake duration

### Collision

**Coverage & Precision**：

- collision enabled
- collision radius
- 1-pixel precision cell size
- sector size

**Dynamic Sector Rebuild**：

- critical collision budget
- background collision build budget
- shapes per slice
- sector commits per physics frame
- dynamic rebuild Hz

### Debug

只管理 F1/F2 的默认可见性、刷新间隔和 World Debug 细节。

### Legacy Fallback

最后单独放历史兼容参数，正常使用 API 11 时一般不需要调整：

- `maximum_collision_triangles`：V2 兼容入口；当前 greedy rectangles 不依赖 triangle budget。
- `border_exchange_hz`
- `border_seams_per_tick`

后两项只用于 API < 9 的 GDScript seam fallback；Native Seam Bridge 不使用它们。

## 当前 PC Profile

关键行为：

- `load_radius = 2`
- `simulation_radius = 1`
- foreground/background/repaint = `60 / 60 / 60 Hz`
- `visual_texture_downscale_factor = 2`
- Native flow warm radius = `1`
- collision sector = `64px`
- collision dynamic rebuild = `20Hz`

V3.9 Active Blocks 可用时，玩家周围 3×3 Simulation 使用统一 60Hz；性能由 16×16 Active Block 睡眠系统控制，而不是人为把邻 Chunk 降到 12Hz。

## 当前 Mobile Profile

显示名为 `Mobile Active Blocks`。关键行为：

- `load_radius = 1`
- `simulation_radius = 0`
- foreground/background/repaint = `30 / 8 / 30 Hz`
- `visual_texture_downscale_factor = 4`
- renderer pools 更小
- Flow Warm Radius = `1`，跨 Chunk 流动时临时唤醒邻 Chunk

V3.7.3 起，移动端主要 frame/collision budgets 与 PC 对齐，但加载范围、模拟频率、纹理缩放和 pool 规模仍保持移动端策略。

## 调参建议

先用 F1 HUD 找到对应分组，再回 Profile Inspector 修改同名类别：

- Chunk 来不及加载 → `Streaming & Generation`
- Simulation tick 不足 → `Pixel Simulation` / pipeline simulation budget
- 跨 Chunk 水/气体异常 → `Cross-Chunk Flow`
- Collision dirty 长期积压 → `Collision`
- GPU/纹理内存问题 → `Visuals & Pools`

不要先改 `Legacy Fallback`；API 11 正常加载时这些字段通常不是主路径。
