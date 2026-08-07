# Collision Dirty Net-Change Fix — V3.7.1

## 修复目标

V3.7 的 change batch 只记录“事务期间是否曾经发生过实体占用变化”。某些元素为了执行邻接判断，会在同一次 `step()` 中临时执行：

```text
Solid -> Air -> 原 Solid
```

最终网格没有变化，但 Sector 仍会提升 revision、进入 staging/commit_pending，并在 F6 中显示持续跳动的粉红框。`gen_mine_lab` 的 Crystal 数量较多，因此该误报最明显。

## API 6：按净变化提交 dirty

Native batch 现在为每个被触碰的 cell 保存：

- 本次最外层事务第一次写入前的原始 element ID；
- 事务结束时的最终 element ID；
- 使用 16-bit generation stamp 避免每帧清空整个 512×512 追踪数组；原始值仅为实际被触碰的 cell 稀疏保存。

事务结束时按以下规则处理：

```text
original == final
  -> 不提升 visual revision
  -> 不产生 collision dirty

original != final，但 Solid(original) == Solid(final)
  -> 只提升 visual revision
  -> 不重建碰撞

Solid(original) != Solid(final)
  -> 提升 visual revision
  -> 只标记对应 64×64 Sector dirty
```

因此临时清空、失败后回滚、同一事务中删除后恢复等操作都不会触发无效碰撞重建。

## Crystal 系列优化

以下元素不再通过清空自身来排除源节点：

- Crystal（27）
- Lapis（78）
- Ruby（79）
- Emerald（80）

目标格的同类 cardinal neighbor 数量由旧逻辑的“清空源后等于 0”改为“保留源时等于 1”，语义等价但减少两次 cell 写入。

## Native API 版本

```text
get_native_api_version() -> 6
```

Godot 侧要求 API >= 6。旧 API 5 DLL 即使包含 Sector 接口，也会显示：

```text
native fallback(api 5)
```

并回退到兼容路径，防止误以为净变化修复已经生效。

Windows 重新编译：

```bat
cd extensions\sand-slide
build_windows_collision_sectors.bat
```

运行后在 F1 确认：

```text
native yes(api 6)
```

## 验证

Godot smoke test 新增 Ice 临时 clear/restore 场景：

```bat
godot --headless --path game res://tests/CollisionSectorSmokeTest.tscn
```

验证内容：

- 无净变化时 `is_dirty() == false`；
- 无净变化时没有 dirty Sector；
- visual revision 不变化；
- collision Sector revision 不变化；
- 真正的 Solid -> Air 修改仍正常产生 dirty 与 revision。

手动验证 `gen_mine_lab`：

1. F1 确认 `native yes(api 6)`。
2. F6 开启碰撞调试。
3. 停止移动并等待初始碰撞提交完成。
4. 不射击，保持 F5 模拟开启。
5. Crystal 的无效粉红 Sector 闪烁应停止；只有真实生长或实体变化才会短暂显示状态框。
