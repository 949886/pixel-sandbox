# Performance V3 Validation Report

## 已完成静态检查

- 87 个 GDScript 文件括号与字符串结构检查通过；
- 76 个 `class_name` 无重复；
- 修改脚本使用统一 Tab 缩进；
- 主场景仍为 `res://scenes/World.tscn`；
- PC/Mobile profile 新字段与 `WorldRuntimeProfile.gd` 一致；
- 正常 chunk 与特殊 chunk 均进入 staged `PixelChunkCanvas`；
- 过期普通/特殊生成请求及未挂载结果均可裁剪；
- 新增 C++ 方法已在头文件、实现和 `_bind_methods()` 中对应声明。

## 原生二进制状态

随包存在：

- Windows x86_64 debug DLL；
- Windows x86_64 release DLL。

随包不存在：

- Android `.so`；
- iOS/macOS framework；
- Linux `.so`；
- Web `.wasm`。

现有 Windows DLL 也不包含 V3 新增的 `reset_grid()` 和 `set_cells_bulk_range()`，因此项目会自动使用预算化兼容路径。要获得最佳 PC 与移动端性能，必须从 `extensions/sand-slide` 重新编译目标平台库。

## 尚未执行

当前环境没有 Godot 4.7、目标平台导出模板、Android NDK 和完整 `godot-cpp` 子模块，因此无法进行：

- Godot 场景实际启动；
- Windows 帧时间采样；
- Android/iOS 真机 profiler；
- 新 GDExtension 二进制编译。

因此本报告不声称具体 FPS 或毫秒提升。V3 的改动通过架构消除集中式主线程工作，但最终预算仍应使用 F1 HUD 和 Godot Profiler 在目标设备上校准。
