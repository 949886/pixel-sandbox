# Native Cross-Chunk Flow V3.8 — Validation

## 已完成的静态检查

- `sand_simulation.cpp` 使用 C++17 lightweight Godot API stub 完成 syntax-only 编译；
- 100 个 GDScript 文件执行括号、字符串、重复函数、混合缩进检查；
- 84 个全局 `class_name` 检查，无重复；
- `res://` 文本资源引用检查；
- Native API 9 声明 / 定义 / `_bind_methods()` 一致性检查；
- PC / Mobile Profile 新字段检查。

## Native 行为测试

`extensions/sand-slide/tests/native_seam_bridge_test.cpp` 直接实例化两个真实 `SandSimulation` 并验证：

1. Water 向下跨上下 seam；
2. 跨 seam 前后 Water 总数守恒；
3. Smoke 向上跨上下 seam；
4. Water 左右跨 seam；
5. Smoke 左右跨 seam；
6. 显式 Powder 在直下阻挡时选择斜向空位；
7. Water 与较轻 Oil 根据 density 交换；
8. `get_native_api_version() == 9`。

结果：

```text
NativeSeamBridgeTest: PASS
```

## Godot Smoke Test

新增：

```text
res://tests/NativeSeamBridgeSmokeTest.tscn
```

正式 API 9 二进制编译后运行：

```bat
godot --headless --path game res://tests/NativeSeamBridgeSmokeTest.tscn
```

预期：

```text
NativeSeamBridgeSmokeTest: PASS
```

## 尚未在当前环境执行

当前容器没有 Godot 4.7 可执行文件、正式 godot-cpp checkout 与目标平台工具链，因此没有声称完成：

- Windows DLL 正式链接；
- Android ARM64 真机测试；
- Web WASM 浏览器测试；
- 三 Chunk 长距离液体实机场景；
- 长时间温度/功耗测试。

目标设备验收时建议重点观察：

- 水在 seam 是否形成水平堆积线；
- Smoke 是否停在顶部/左右边界；
- F1 `moved` 是否在跨界时持续非零；
- Mobile 邻居是否只在有流动时增加 simulation ticks；
- 元素总量是否保持守恒（没有 duplicate/loss）。
