# Chunk 无感加载优化 V3

## 1. 原始卡顿来源

V2 虽然把世界生成放到了工作线程，但一个 chunk 到达主线程后仍会集中执行：

1. 创建并调整 512×512 `SandSimulation`；
2. 将 262,144 个材质像素写入模拟；
3. 调用 `get_color_image()` 并上传完整 512×512 RGBA 纹理；
4. 为固体区域生成大量物理节点；
5. 多个 canvas 在同一时刻各自执行模拟和重绘。

因此“生成在线程中”并不等于“加载无尖峰”。真正的瓶颈在主线程接管阶段。

## 2. 新的分阶段流水线

每个 chunk 现在依次经历：

```text
工作线程生成
  → 轻量静态预览挂载
  → 原生模拟分帧预热
  → 首张完整模拟纹理限额激活
  → 碰撞形状分帧创建
  → 统一调度模拟/重绘
```

### 静态预览先行

chunk 到达时只创建一个低分辨率 `ImageTexture`：

- PC：256×256，最近邻放大至 512×512；
- Mobile：128×128，最近邻放大至 512×512。

画面会立即出现。原生像素模拟仍在后台式的帧预算中初始化，完成后无场景节点替换地切换到完整 512×512 模拟纹理。

### 工作线程预烘焙

以下 CPU 工作已从主线程移出：

- `material_image → PackedInt32Array element_ids`；
- 固体像素粗网格化；
- 贪心矩形碰撞合并；
- 预览图降采样；
- 特殊结构的拆分、裁剪和每 chunk 数据烘焙。

正常 chunk 和特殊结构 chunk 使用同一套结果结构。

### 总帧预算

各阶段不再拥有可以无限叠加的独立额度。它们共享一个总流水线预算：

| 配置 | 每帧总预算 | 静态预览 | 模拟范围 | 预测预热 |
|---|---:|---:|---:|---:|
| PC Smooth Streaming | 6.0 ms | 256×256 | 半径 1 | 前方最多 2 个 chunk |
| Mobile Smooth Streaming | 3.0 ms | 128×128 | 当前 chunk | 前方 1 个 chunk |

额度耗尽后，剩余工作自动顺延到下一帧。加载延迟可能略增，但不会把所有工作挤进一个帧。

### 预测性预热

`WorldManager` 根据 `CharacterBody2D.velocity` 判断移动方向，在玩家越过 chunk 边界前预热前方 canvas。移动端仍只运行当前 chunk 的模拟，因此不会把周围九个 chunk 全部持续模拟；预热只用于隐藏跨边界初始化。

## 3. 原生 GDExtension 快速路径

源码新增：

```cpp
reset_grid(width, height, chunk_size)
set_cells_bulk_range(data, start, count)
```

作用：

- `reset_grid()` 避免新模拟在改尺寸时复制旧网格；
- `set_cells_bulk_range()` 允许按帧预算分段写入连续像素；
- 若新接口不存在，GDScript 自动退回逐像素分帧路径；
- 若只有旧的 `set_cells_bulk()`，仍会使用一次性原生批量路径。

当前随包 Windows DLL 是旧二进制，不包含这些新接口，所以现在会自动走**预算化兼容路径**。重新编译 GDExtension 后会自动切换至 `native ranged bulk`。

## 4. 碰撞优化

旧方案可能创建大量 `CollisionPolygon2D` 节点。新方案在工作线程中：

1. 以 PC 8px / Mobile 16px 为碰撞单元；
2. 判断单元内固体覆盖率；
3. 对相邻固体单元执行贪心矩形合并；
4. 主线程使用 `PhysicsServer2D` RID 分帧加入矩形形状。

离开碰撞半径的 chunk 会把碰撞层和 mask 设为 0，但保留已构建形状，返回时无需重建。

## 5. 队列、线程与内存

- 工作线程结果队列有严格上限；
- 主线程待挂载队列：PC 最多 6，Mobile 最多 3；
- 玩家快速移动时会裁剪过期请求和过期结果；
- 剩余请求会按与玩家的距离重新排序；
- 结果队列满时工作线程阻塞等待，不再每 1ms 自旋轮询；
- Mobile 每个生成任务后主动让出 3ms，降低内存带宽争用；
- renderer 与低分辨率静态纹理可复用；
- 完整模拟纹理在回收时释放，避免对象池持有大量 1MiB GPU 纹理。

## 6. 模拟调度

每个 `PixelChunkCanvas` 不再各自 `_process()`。`WorldManager` 统一执行：

- 预热；
- 首张模拟纹理激活；
- 碰撞创建；
- round-robin 模拟 tick；
- renderer 回收；
- 跨 chunk 边界交换。

多个 canvas 的刷新相位按坐标散列错开，避免同时重绘。

## 7. 真机调试

按 `F1` 打开 HUD。新增字段：

- `ready`：等待主线程挂载的 chunk 数；
- `Pipeline X/Yms`：上一帧流水线耗时 / 配置上限；
- `Current`：当前 canvas 的阶段；
- `warm`：本帧完成元素灌入的 canvas 数；
- `texture`：本帧激活完整模拟纹理的数量；
- `collision slices`：本帧执行的碰撞切片数；
- `sim ticks`：本帧完成的模拟 tick 数。

理想状态：移动时 `Pipeline` 大多数帧低于配置上限，`ready` 不持续增长，当前 canvas 在进入前已经显示 `native ready` 或模拟快速路径。

## 8. 调参建议

出现帧尖峰时，按以下顺序调低：

1. `streaming_pipeline_budget_ms`；
2. `simulation_update_budget_ms`；
3. `simulation_texture_activations_per_frame` 保持 1；
4. 增大 `visual_texture_downscale_factor`；
5. 增大 `collision_cell_size`；
6. 降低 `simulation_repaint_hz`。

出现加载跟不上移动时，优先：

1. 增大 `predictive_prewarm_chunks`；
2. 适度提高 `simulation_warmup_budget_ms`；
3. 减小 `generation_worker_yield_ms`；
4. 确认已重新编译并启用 `set_cells_bulk_range()`。

不要首先增大 `main_thread_upload_budget_per_frame`，因为一次上传多个纹理最容易重新制造尖峰。
