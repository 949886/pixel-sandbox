# Native Active Block Simulation V3.9 — Validation

## 已完成

### C++17 编译级验证

`sand_simulation.cpp` 使用 g++ 与 clang++ 在轻量 Godot C++ API stub 下执行 syntax-only 编译，均通过。原 sand-slide 元素头文件中的历史 warning 不属于本次改动。

### Native Active Block 行为测试

直接链接真实 `SandSimulation` / `AllElements` 后验证：

1. 两个稳定 INERT Blocks 在 4 quiet ticks 后进入 SLEEPING；
2. Block 边界附近的外部删除在下一 Tick 唤醒两个占用邻区；
3. 孤立且无变化的 MOVABLE Block 可以 Sleep；
4. REACTIVE/MOVABLE 接口持续 Active；
5. AUTONOMOUS Block 不会 Sleep；
6. API 9 Native Seam transfer 会唤醒 API 10 目标边缘 Block；
7. Native API version = 10；
8. 512×512 全 INERT 地形稳定后 1024 Blocks 全部休眠，中心单像素改动仅唤醒局部最多 3×3 Blocks。

结果：

```text
NativeActiveBlockTest: PASS
```

### 512×512 压力模型

- 总 Simulation Blocks：1024；
- 全静态 INERT 地形在 4 Tick 后：1024 Sleeping；
- 稳定后的下一 Tick：0 processed Blocks、0 scanned cells；
- 中心单像素外部变化后：只处理局部 3×3 Block 邻域，最多 9 Blocks / 2304 cell slots。

### 既有系统回归

以下验证器重新通过：

```text
validate_collision_performance_v3_7_2.py
validate_mobile_pc_budgets_v3_7_3.py
validate_native_flow_v3_8.py
validate_active_blocks_v3_9.py
```

覆盖：

- API 8 Collision Sector / Conservative Snapshot；
- V3.7.3 移动端 PC 时间预算；
- API 9 Native Seam Bridge；
- API 10 Active Block 声明 / 定义 / binding；
- GDScript class_name / resource reference / debug format 基础结构。

## Godot Headless Smoke Test

重新编译 API 10 后：

```bat
godot --headless --path game res://tests/ActiveBlockSmokeTest.tscn
```

预期：

```text
ActiveBlockSmokeTest: PASS
```

仍建议同时运行：

```bat
godot --headless --path game res://tests/CollisionSectorSmokeTest.tscn
godot --headless --path game res://tests/NativeSeamBridgeSmokeTest.tscn
```

## 尚需目标设备验证

此外使用 AddressSanitizer + UndefinedBehaviorSanitizer 直接运行 Native Active Block 行为测试通过，未发现越界或未定义行为。

当前执行环境没有正式 Godot 4.7 + godot-cpp 目标构建链，因此仍需在 Windows/Android/Web 实机记录：

- F1 Active/Cooling/Sleeping Block 数；
- `processed blocks` 与 `scanned cells`；
- PC 3×3 60Hz 是否保持视觉连续；
- 大规模燃烧时 Active Block 比例；
- 大型水池稳定后 Sleep 比例；
- 快速爆炸后 Wake 是否覆盖完整反应区域；
- 长时间运行和移动端温度/功耗。
