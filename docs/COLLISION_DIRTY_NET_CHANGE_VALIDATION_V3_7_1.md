# V3.7.1 静态与 Native 行为验证

## 已执行

- C++17 syntax-only 编译：`sand_simulation.cpp` 通过。
- 使用轻量 Godot API stub 链接并直接实例化真实 `SandSimulation`。
- Ice ID 19 在固定随机种子下执行 64 次 step，触发临时 `Solid -> Air -> Solid` 分支探测。
- 验证最终 cell、visual dirty、collision dirty、visual revision、Sector revision 均无误报。
- 随后执行真实 `Solid -> Air`，确认 dirty 与 Sector revision 仍会更新。
- 99 个 GDScript 静态检查通过。
- 84 个全局 `class_name` 重复检查通过。
- `res://` 引用检查无错误。

Native 行为测试结果：

```text
NativeNetChangeTest: PASS
```

## 尚需目标环境验证

当前容器没有 Godot 4.7 编辑器与完整正式 godot-cpp 构建环境，因此仍需在目标平台重新编译 API 6 DLL/SO/WASM，并执行 Godot headless smoke test和 `gen_mine_lab` 实机观察。
