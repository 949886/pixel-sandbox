# Collision Burning Performance V3.7.2 Validation

## 静态工程检查

通过 `validate_collision_performance_v3_7_2.py` 检查：

- 99 个 GDScript 文件
- 84 个全局 `class_name`
- 修改后的 setup/new 参数数量
- `res://` 资源引用
- C++ 声明、定义和 GDExtension 方法绑定
- Native API 8 所需接口
- F1 HUD 格式参数数量

结果：无错误。

现有 12 条警告均来自 `.gdextension` 声明但包内没有提供的 Linux、macOS、Windows x86_32 和 Android x86_64 二进制，与本次修改无关。

## C++ 编译级检查

使用轻量 Godot C++ API stub 对 `sand_simulation.cpp` 执行：

```text
g++ -std=c++17 -fsyntax-only
```

结果：通过。

这不是正式 godot-cpp/Godot 4.7 链接构建，因此目标平台仍需执行项目构建脚本。

## Native API 8 行为测试

直接链接真实 `SandSimulation` 代码，验证：

1. 第一次删除后生成 Sector 快照。
2. 提交前继续删除另一个实体像素。
3. 快照被分类为 conservative。
4. conservative stale snapshot 可以 acknowledge。
5. 快照之后的删除仍保持 `REMOVED` dirty。
6. 空快照后新增实体会被分类为 unsafe。
7. Native acknowledge 会拒绝 unsafe snapshot。
8. `get_native_api_version()` 返回 8。

结果：

```text
Api8ConservativeSnapshotTest: PASS
```

## 碰撞矩形模型测试

`game/tools/collision_sector_model_test.py`：

- 200 组随机 64×64 占用掩码
- 矩形覆盖无重叠、无缺失
- 跨四个 Sector 的圆形破坏 dirty 范围

结果：通过。

## 燃烧调度模型测试

`game/tools/collision_burning_scheduler_model_test.py` 模拟 60Hz 连续 removal：

- PC 20Hz：2 秒内提交 40 次
- Mobile 10Hz：2 秒内提交 20 次
- Staging 过期不会绕过节流
- removal-only stale snapshot 可持续提交进度
- 新增实体仍被判定为 unsafe

结果：通过。

## Godot Smoke Test 更新

`CollisionSectorSmokeTest.gd` 现在要求 API 8，并覆盖：

- dirty 数据的 Removed/Added flags
- 返回 committed mask 后取消 no-op dirty
- conservative removal snapshot
- unsafe addition snapshot
- Native unsafe acknowledge 拒绝
- 跨 Sector `erase_circle()`

## 限制

当前执行环境没有 Godot 4.7 可执行程序、正式 godot-cpp checkout 和 Android/Web 工具链，因此未在此处完成：

- Godot 场景实际运行
- Windows DLL 正式链接
- Android 设备帧时间测试
- Web WASM 浏览器测试

最终验收应在目标设备上记录燃烧前后：

- 主线程 frame time
- `simulation.step()` 时间
- collision dirty/build/pending 数量
- F6 Sector 状态频率
- 玩家移动是否冻结
- Active 碰撞是否在燃烧过程中持续收缩
