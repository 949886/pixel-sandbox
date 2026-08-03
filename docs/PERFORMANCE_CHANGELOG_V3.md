# Performance Changelog V3

## Streaming

- chunk 到达时仅挂载静态预览，不再立即创建完整模拟；
- 新增主线程待挂载队列上限和过期结果清理；
- 玩家移动后对工作队列重新按距离排序；
- 普通和特殊 chunk 工作线程均改为有界结果队列；
- 去除结果队列满时的 1ms busy polling；
- PC/Mobile 工作线程加入可配置 job yield。

## Pixel simulation

- `PixelChunkCanvas` 改为 `COLD → LOADING → READY_TO_UPLOAD → READY`；
- 元素写入、首张纹理上传、模拟 tick 分开预算；
- 旧 DLL 逐像素路径改为分帧执行；
- 新增移动方向预测预热；
- 统一 round-robin 模拟调度与坐标相位错峰；
- 跨 chunk 边界交换降低频率并限制每次 seam 数量。

## Native extension source

- 新增 `reset_grid()`；
- 新增 `set_cells_bulk_range()`；
- 保留 `set_cells_bulk()` 兼容路径。

## Rendering and memory

- PC 静态预览降为 256×256；
- Mobile 静态预览降为 128×128；
- 静态 `ImageTexture` 在 renderer pool 中按尺寸复用；
- 完整模拟纹理回收时释放；
- 工作线程转换后提前释放 material image；
- 待挂载队列和工作线程 backlog 分平台限制。

## Physics

- 像素轮廓三角化改为粗网格 + 贪心矩形；
- 使用 `PhysicsServer2D` RID，避免创建大量场景节点；
- 碰撞形状分帧创建；
- 远处 chunk 从 collision layer/mask 中禁用。

## Profiles

- PC 总流水线预算 6ms，预览降采样 2×；
- Mobile 总流水线预算 3ms，预览降采样 4×；
- Mobile 模拟半径保持 0，并预热前方 1 个 chunk；
- Mobile 碰撞单元为 16px，降低形状数量。
