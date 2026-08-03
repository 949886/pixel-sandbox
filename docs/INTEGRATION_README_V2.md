> **V3 提示：** 当前性能实现已升级。请优先阅读 `PERFORMANCE_OPTIMIZATION_V3.md`；本文中的部分 V2 参数和流程仅供历史参考。

# 新版世界生成 × sand-slide 像素引擎整合说明

## 项目入口

打开：

```text
PixelPieceWorldIntegratedV2/game/project.godot
```

运行场景：

```text
res://scenes/World.tscn
```

## 本次使用的工程

- 像素引擎底座：`Pixel(2).zip`
- 世界生成模块：新版 `noita(15).zip`

这不是把旧版 Noita 文件简单覆盖回来。新版项目的 `WorldStructure`、特殊结构、异步 chunk 生成、全局 seam 注册与验证、运行时性能档位、调试系统都被保留，并重新接到了像素引擎渲染层。

## 最终运行链路

```text
WorldStructureBuilder / SpecialChunkPlanner
                ↓
PieceChunkGenerator / SpecialPieceImageBuilder
                ↓
512×512 visual_image + material_image
                ↓
MaterialPalette：RGBA 颜色 → sand-slide element ID
                ↓
每个世界 chunk 一个 PixelChunkCanvas
                ↓
每个 PixelChunkCanvas 一个 SandSimulation
                ↓
SandSimulation.get_color_image() → ImageTexture
                ↓
solid 材质蒙版 → HoledCollisionBuilder2D → StaticBody2D
```

原来的 `Sprite2D` 世界贴图渲染已不再作为运行时世界画面。`visual_image` 只保留为可选的 CPU 调试数据；真正显示的像素来自 sand-slide。

## 普通 chunk

`PieceChunkRenderer.gd` 现在只负责：

- 定位世界 chunk；
- 创建或复用一个 `PixelChunkCanvas`；
- 把 `PieceChunkData.material_image` 映射为元素 ID；
- 初始化该 chunk 的 `SandSimulation`；
- 在上传后释放不再需要的材质图内存。

普通 chunk 尺寸固定为 512×512 像素。

## 多 chunk 特殊结构

新版 `SpecialChunkManager` 和异步 `SpecialChunkImageWorker` 被保留。特殊结构生成完成后，`SpecialPieceRenderer` 会按 512×512 切片：

```text
一个 2×3 特殊结构
→ 6 个世界 chunk
→ 6 个 PixelChunkCanvas
→ 6 个独立 SandSimulation
```

因此特殊结构同样满足“一 chunk 对应一 canvas”，并能与普通 chunk 参加同一套模拟半径和边界交换。

## MaterialPalette

主要文件：

```text
res://scripts/materials/MaterialEntry.gd
res://scripts/materials/MaterialPalette.gd
res://resources/materials/default_material_palette.tres
res://scripts/pixel_world/SandSimulationConfigurator.gd
```

`MaterialEntry` 在新版 world-demo 原字段基础上增加了：

- `source_colors`：同一种材质允许多个源颜色；
- `engine_element_id`：对应 sand-slide 元素 ID；
- `simulation_state`：粉末、静态、液体、气体、能量；
- `viscosity`、`durability` 等自定义元素参数。

映射优先使用精确 RGBA；只有遇到未登记的非透明颜色时才使用带距离上限的最近色回退。生产素材建议给 `PieceDef.material_texture` 使用纯色、无抗锯齿的材质图，使视觉图和物理材质完全解耦。

## 跨 chunk 像素流动

每个 chunk 的 SandSimulation 相互独立。`WorldManager` 在活动 chunk 之间执行边界交换：

- 粉末和液体可以向下进入下方 chunk；
- 气体可以向上进入上方 chunk；
- 液体可以跨越左右边界；
- 普通 chunk 与特殊结构 chunk 使用同一接口。

频率由运行时 profile 的 `border_exchange_hz` 控制。

## 模拟与加载范围

PC 默认 profile：

```text
load_radius = 2
simulation_radius = 1
simulation_repaint_hz = 15
border_exchange_hz = 15
```

即周围 5×5 chunk 可以保持生成/显示，但只模拟玩家附近 3×3 chunk。移动端 profile 将加载半径降为 1、模拟半径降为 0，并关闭静态碰撞生成。

配置文件：

```text
res://resources/runtime_profiles/pc_runtime_profile.tres
res://resources/runtime_profiles/mobile_runtime_profile.tres
```

## 操作

```text
WASD / 方向键    移动
+ / -             摄像机缩放
F1                调试 HUD
F2                世界结构、chunk、socket 调试绘制
F3                使用当前种子重新生成
F4                种子 +1 后重新生成
F5                暂停或恢复像素模拟
```

## 原生批量写入

`sand_simulation.cpp/.h` 已加入：

```cpp
set_cells_bulk(PackedInt32Array data)
```

它能把一个 512×512 chunk 的元素数组一次写入原生模拟。压缩包中沿用的 Windows DLL 是原像素项目自带版本，尚未包含该新方法，因此脚本会自动退回逐非空像素的兼容初始化路径；功能可用，但首次载入 chunk 会明显更慢。

要启用快速路径，需要补齐 `extensions/sand-slide/godot-cpp` 并重新编译与目标 Godot 版本兼容的 GDExtension：

```text
cd extensions/sand-slide
git submodule update --init --recursive
build.bat
```

重新生成的 DLL 放到 `game/bin/fallingsand/` 后，`PixelChunkCanvas` 会自动检测并使用 `set_cells_bulk()`。

## 预编译平台

当前随包提供：

```text
Windows x86_64 debug DLL
Windows x86_64 release DLL
```

Linux、macOS、Android、Web 等平台在 `.gdextension` 中保留了目标配置，但对应二进制没有包含在原 Pixel 压缩包中，需要自行编译。

## 当前边界

- 静态碰撞根据 chunk 初始 solid 材质生成。若之后让木材、金属等 solid 材质被大规模破坏，碰撞不会持续逐帧重建。
- 边界交换解决常见的上下落体、气体上升和左右液体流动，但跨边界的复杂化学反应、爆炸邻域和斜向多格查询仍然是 chunk-local。
- chunk 卸载后会按世界种子重新生成，当前版本没有把玩家造成的像素变化写入持久化缓存。
- 当前环境没有 Godot 4.7 和 Windows GDExtension 运行环境，因此本包完成的是资源、脚本、材质覆盖和原生接口的静态验证，未进行实际 Windows 帧运行测试。

## 核心改动文件

```text
res://scripts/world/WorldManager.gd
res://scripts/piece_world/PieceChunkRenderer.gd
res://scripts/special/SpecialChunkManager.gd
res://scripts/special/SpecialPieceRenderer.gd
res://scripts/pixel_world/PixelChunkCanvas.gd
res://scripts/pixel_world/SandSimulationConfigurator.gd
res://scripts/materials/MaterialEntry.gd
res://scripts/materials/MaterialPalette.gd
res://resources/materials/default_material_palette.tres
res://scripts/resources/WorldRuntimeProfile.gd
```
