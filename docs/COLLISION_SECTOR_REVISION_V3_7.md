# Collision Sector + Revision — V3.7

## 目标

V3.6 以前，每次实体地形变化都会重新扫描整个 512×512 Canvas，并完整重建一个 Chunk 的碰撞快照。画面可以很快更新，但旧碰撞要等数十甚至数百个矩形重新提交后才被替换，因此 PC 和移动端都会出现“洞已经显示出来，但角色仍撞到旧墙”的延迟。

V3.7 将动态碰撞改为 **64×64 Sector 增量更新**，保留 1 像素精度与 PhysicsServer2D RID 碰撞。

```text
512×512 Canvas
└── 8×8 Collision Sectors
    └── 每个 Sector 64×64 像素
```

一次小型爆炸通常只重建 1～4 个 Sector，不再扫描和替换整个 Chunk。

## Native API 5

`SandSimulation` 新增以下接口：

```text
get_native_api_version() -> 5
configure_collision_sectors(sector_size)
get_collision_sector_revision(x, y)
get_dirty_collision_sectors(max_count)
get_collision_sector_snapshot(x, y, cell_size)
acknowledge_collision_sector(x, y, revision)
has_dirty_collision_sectors()
erase_circle(center_x, center_y, radius, replacement_type)
get_visual_revision()
```

### Revision 规则

- 每个 Sector 有独立 revision。
- 同一次 `step()`、`erase_circle()` 或批量上传中，同一 Sector 无论变化多少像素，只递增一次 revision。
- Godot 取得 revision N 的快照并完成构建后，只能确认 revision N。
- 构建期间若 Sector 已变化到 N+1，旧确认会失败，Sector 保持 dirty 并再次排队。
- 因此持续射击或模拟变化不会丢失更新。

## Native 批量破坏

旧路径在 GDScript 中逐像素调用 `get_cell()` / `set_cell()`。V3.7 改为每个受影响 Canvas 调用一次：

```text
erase_circle(...)
```

C++ 在同一个事务中完成删除、视觉 dirty、碰撞 Sector dirty、revision 更新和变化边界统计。命中区域对应的 Sector 会被提升到 Canvas 碰撞队列前端。

## Godot Sector 碰撞生命周期

每个 Sector 平时只保留一套 Active Body RID。发生变化时才临时创建 Staging Body：

```text
Active revision N 继续参与物理
→ Staging 构建 revision N+1
→ WorldManager._physics_process() 原子切换
→ 确认 native revision
→ 释放旧 Active Body/Shape RID
```

空 Sector 不保留 Body。Canvas 回收到对象池时会释放全部 Body 和 Shape RID，避免移动端对象池积累空物理对象。

## 物理帧提交顺序

`WorldManager.process_physics_priority = -100`，Sector 切换发生在 Player 默认优先级之前：

```text
提交最新地形碰撞
→ Player.move_and_slide()
```

玩家移动安全检查不再只判断“Chunk 曾经有过碰撞”，而是检查扫掠矩形触及的每个 Sector 是否已提交最新 revision。远处 Sector 正在更新不会冻结玩家。

## 视觉一致性

Solid 占用变化发生后，Canvas 保留旧纹理，直到相关碰撞更新全部提交，再上传最新纹理。优先保证：

```text
旧墙可见 + 旧碰撞存在
```

而不是：

```text
墙已消失 + 旧碰撞仍阻挡玩家
```

非 Solid 变化没有碰撞 Sector dirty，仍可按原 repaint cadence 更新。玩家所在 Canvas 在上一 physics frame 完成碰撞提交后，会在下一次 simulation step 之前优先刷新纹理，避免新一步模拟再次把刚完成的 revision 推迟。F5 暂停模拟时，外部地形编辑仍可通过独立的视觉刷新路径显示。

## 独立关键预算

动态碰撞拥有独立于 streaming pipeline 的关键预算：

| Profile | Critical budget | Background budget | Physics commits/frame |
|---|---:|---:|---:|
| PC | 1.25 ms | 0.75 ms | 24 |
| Mobile | 0.75 ms | 0.35 ms | 12 |

执行顺序为：

1. 关键碰撞 Sector 构建
2. 前景模拟
3. Chunk attach / warmup / texture activation
4. 剩余后台工作

因此碰撞不会再被 Chunk 加载和纹理上传长期饿死。

## F6 Debug 图例

按 F6 开关碰撞 Debug：

- 青色填充/边线：当前 Active PhysicsServer2D 碰撞矩形
- 红色 Sector：dirty，等待或需要新快照
- 黄色 Sector：正在构建 Staging Shape
- 紫色 Sector：构建完成，等待下一个 physics frame 原子提交

F1 HUD 会显示：

```text
sector size/count
dirty/build/pending
native yes|fallback (api N)
critical collision budget
```

只有显示 `native yes(api 5)` 时，局部 Sector 更新才真正启用。

## 旧二进制回退

压缩包保留用户上传版本中的现有 DLL/SO/WASM，确保原支持平台仍能打开项目。这些二进制不包含 API 5，因此首次运行会警告并回退到完整 Chunk 扫描。

必须重新编译 GDExtension 才能启用 V3.7：

```bat
cd extensions\sand-slide
build_windows_collision_sectors.bat
```

或构建原项目声明的 Windows、Web、Android 目标：

```bat
cd extensions\sand-slide
build.bat
```

脚本会下载并固定到 `GODOT_CPP_COMMIT.txt` 中记录的 godot-cpp commit。

## 推荐运行测试

编译 API 5 后执行：

```bat
godot --headless --path game res://tests/CollisionSectorSmokeTest.tscn
```

预期输出：

```text
CollisionSectorSmokeTest: PASS
```

随后在游戏中测试：

1. F1 确认 `native yes(api 5)`。
2. F6 打开碰撞层。
3. 在 Sector 内、Sector 边界、Chunk 边界连续射击。
4. 确认青色碰撞与画面同时切换。
5. 持续撞墙并破坏脚下/墙侧地形。
6. PC 与移动端分别观察 dirty/build/pending 是否持续积压。
