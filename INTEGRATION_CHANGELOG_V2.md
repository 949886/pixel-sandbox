# V2 整合改动清单

## 保留的 noita(15) 模块

- WorldStructure 与结构节点生成
- BiomeMap、SocketProfilePlanner、WorldSeamRegistry
- PieceLibrary、PieceChunkGenerator、GluePieceGenerator
- ChunkGenerationWorker 异步生成
- SpecialChunkPlanner、SpecialChunkImageWorker、SpecialChunkManager
- PC / Mobile runtime profiles
- DebugOverlay 与 WorldDebugDrawer

## 替换或扩展的运行层

- `PieceChunkRenderer`：Sprite2D 图像上传改为 PixelChunkCanvas。
- `SpecialPieceRenderer`：整张特殊结构 Sprite 改为逐 chunk PixelChunkCanvas。
- `MaterialPalette`：从仅保存条目扩展为 RGBA → 元素 ID 映射器。
- `WorldManager`：加入材质调色板、模拟半径、F5、跨 chunk 交换。
- `WorldRuntimeProfile`：加入模拟、碰撞和边界交换参数。
- `sand_simulation` 源码：加入 `set_cells_bulk`。

## 新增文件

```text
res://scripts/pixel_world/PixelChunkCanvas.gd
res://scripts/pixel_world/SandSimulationConfigurator.gd
res://resources/materials/default_material_palette.tres
```

## 入口修正

`project.godot` 已从原 Pixel 沙盒的 `samples/sand-test/sand_test.tscn` 改为：

```text
res://scenes/World.tscn
```
