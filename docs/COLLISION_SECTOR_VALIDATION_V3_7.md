# Collision Sector V3.7 Validation

## 已执行的静态检查

- 扫描 99 个 GDScript 文件。
- 检查 84 个 `class_name`，未发现重复全局类名。
- 检查括号、字符串、函数重复、关键方法签名和 `res://` 引用。
- 检查 PixelChunkCanvas / PieceChunkRenderer / SpecialPieceRenderer / SpecialChunkManager 的新参数传递。
- 检查 WorldRuntimeProfile 新字段在 PC、Mobile 两个资源中均已设置。
- 检查 C++ 新声明、定义与 `_bind_methods()` 绑定一致。
- 检查 DebugOverlay 格式占位符数量与参数数量一致。

结果：未发现阻塞性静态错误。

## 算法模型测试

使用独立 Python 模型对 64×64 精确占用掩码执行 200 组随机矩形合并测试：

- 输出矩形无重叠。
- 输出覆盖与输入 Solid Mask 完全一致。
- 1 像素精度无膨胀。
- 位于 (64,64) 的跨界圆形破坏正确标记四个相邻 Sector。

结果：PASS。

## Native Smoke Test

新增：

```text
game/tests/CollisionSectorSmokeTest.gd
game/tests/CollisionSectorSmokeTest.tscn
```

测试内容：

- API 版本至少为 5。
- 单像素编辑只标记对应 Sector。
- Sector Snapshot 包含精确 1×1 碰撞。
- 旧 revision acknowledgement 必须失败。
- 当前 revision acknowledgement 必须成功。
- 跨四区圆形删除必须标记四个 Sector。

此测试需要先重新编译 API 5 二进制。

## 当前环境限制

当前执行环境没有可用的 Godot 4.7 编辑器、SCons 和完整 godot-cpp checkout，因此没有完成：

- Godot 编辑器导入/解析。
- GDExtension 实际编译。
- Windows、Android、Web 二进制替换。
- 实机物理帧、连续射击和移动端性能测量。

压缩包中的既有平台二进制仍是用户上传版本。源代码已经升级到 API 5，但运行时只有重新编译后才会启用 Native Sector 路径。

## 非阻塞资源警告

`.gdextension` 仍声明了一些当前包内未提供的目标：Linux、macOS、Windows x86_32、Android x86_64 等。这些是原项目已有的平台覆盖缺口，不是 V3.7 新增错误。正式发行前应补齐对应产物，或删除未支持的 library declaration。

## 建议验收指标

- 半径不超过 8 的地形破坏：PC 目标 1 个 physics frame 内提交，移动端目标 2 个 physics frame 内提交。
- 局部破坏只扫描命中的 64×64 Sector，不扫描完整 512×512 Canvas。
- 连续 7 发/秒时 dirty/build/pending 队列不持续增长。
- F6 青色 Active 碰撞与最终显示纹理一致。
- 不出现不可见墙、可见无碰撞新实体或重建期间整块墙消失。
