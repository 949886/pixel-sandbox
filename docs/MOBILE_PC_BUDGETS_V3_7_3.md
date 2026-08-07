# Mobile PC Budgets V3.7.3

本版本仅将移动端的运行时“时间预算与单次吞吐量”调整为 PC 档，用于验证移动端卡顿是否主要来自预算不足。

## 已统一到 PC 的参数

| 参数 | 移动端旧值 | 新值 / PC 值 |
|---|---:|---:|
| `streaming_pipeline_budget_ms` | 3.0 | 6.0 |
| `chunk_attach_budget_ms` | 0.5 | 1.0 |
| `simulation_warmup_budget_ms` | 0.75 | 1.5 |
| `simulation_warmup_pixels_per_slice` | 3072 | 8192 |
| `simulation_texture_activation_budget_ms` | 0.5 | 1.0 |
| `critical_collision_budget_ms` | 0.75 | 1.25 |
| `collision_build_budget_ms` | 0.35 | 0.75 |
| `collision_shapes_per_slice` | 6 | 16 |
| `simulation_update_budget_ms` | 1.75 | 4.0 |
| `recycle_budget_ms` | 0.2 | 0.25 |
| `collision_sector_commits_per_physics_frame` | 12 | 24 |
| `collision_dynamic_rebuild_hz` | 10 | 20 |

## 仍保留移动端差异

以下参数没有改成 PC 档：

- `load_radius = 1`
- `predictive_prewarm_chunks = 1`
- `visual_texture_downscale_factor = 4`
- `chunk_renderer_pool_limit = 16`
- `special_renderer_pool_limit = 8`
- `simulation_radius = 0`
- `simulation_hz = 30`
- `background_simulation_hz = 8`
- `simulation_repaint_hz = 30`
- `border_exchange_hz = 3`
- `border_seams_per_tick = 1`
- Worker yield、队列上限和调试刷新频率仍使用移动端值。

因此本版本不是把移动端完整替换成 PC Profile，而是只放宽主线程和碰撞流水线预算。

## 风险与观察项

更高预算允许单帧执行更多工作，但不保证设备一定更流畅。较弱设备上可能出现：

- 单帧耗时上限提高，产生更长的偶发帧；
- CPU 使用率、温度和耗电上升；
- 热降频后长期帧率反而下降。

建议在 F1 HUD 中观察 `pipeline`、`critical collision`、`build/pending` 和实际 FPS，并分别测试燃烧、连续地形破坏、快速跨 Chunk 移动。

本改动仅涉及 `.tres` 运行时配置，不需要重新编译 GDExtension。V3.7.2 的 Native API 8 仍然是燃烧性能优化生效的前提。
