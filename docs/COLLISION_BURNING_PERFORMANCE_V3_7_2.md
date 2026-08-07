# Collision Burning Performance V3.7.2

## 问题表现

V3.7.1 中，木材或其他实体材料持续燃烧时，游戏可能长时间卡顿，直到燃烧结束才恢复。F6 会看到相关 Sector 在 dirty、building 和 commit-pending 状态之间频繁切换。

这个回归不是原始 sand-slide 燃烧算法单独造成的，而是动态碰撞同步策略叠加后的结果。

## 根因

### 1. 逐像素净变化追踪进入模拟热路径

V3.7.1 为过滤临时的 `Solid -> Air -> Solid` 写入，在每次 `step()` 内为被写入像素保存 stamp、索引和原始元素值。燃烧传播会产生大量写入，这些额外的随机内存访问和动态列表操作位于 `set_cell()` 热路径中。

### 2. 删除实体也被当作必须 collision-first

木材通常从 Solid 变为非 Solid 的 Fire。旧碰撞暂时保留时只会多挡住已经烧掉的像素，不会让角色进入新的实体，因此它是保守状态。但 V3.7/V3.7.1 仍让画面刷新和玩家移动等待碰撞队列完全追上。

### 3. 连续变化使 Staging 快照持续过期

燃烧每个模拟 tick 都可能继续删除像素。Sector 快照在生成后，到下一个 physics frame 提交前，revision 往往已经再次变化。旧实现会丢弃整个 Staging Body 和 Shape，再立即重建。持续燃烧时可能一直无法提交，直到燃烧停止。

### 4. 碰撞重建频率跟随模拟频率

即使只影响 64×64 Sector，60Hz 模拟仍可能让同一区域每帧创建、释放 Rectangle Shape RID。移动端尤其容易出现明显卡顿。

## V3.7.2 方案

### 紧凑 Occupancy Bitset

每个 64×64 Sector 的实体占用使用 4096 bit，也就是 512 bytes。每个 Canvas 保存三套掩码：

- 当前模拟 Occupancy
- 已提交物理 Occupancy
- 最近生成的 Snapshot Occupancy

512×512 Canvas 的三套掩码合计约 96 KiB，不再为每次模拟事务保存逐像素原始值列表。

`set_cell()` 仅在 Solid 状态确实改变时翻转一个 bit。事务结束时只比较被触及 Sector 的 64 个 64-bit word。

### 区分 Removed 与 Added

Native dirty 数据新增变化标志：

```text
REMOVED = 1
ADDED   = 2
```

处理规则：

- Removal-only：画面可以立即刷新；旧碰撞作为保守保护低频追赶；玩家移动不冻结。
- Added：必须先提交碰撞，再显示新增实体；玩家不能进入未提交区域。
- Removed + Added：按照 Added 的安全规则处理。

### 动态碰撞节流

运行时配置新增：

```text
collision_dynamic_rebuild_hz
```

默认值：

- PC：20 Hz，最短间隔 50 ms
- Mobile：10 Hz，最短间隔 100 ms

节流时间在任务入队时推进。即使 Staging 在提交前失效，也不会绕过限制每帧立即重试。

### 保守 Stale Snapshot 渐进提交

Native API 8 会缓存生成快照时的 Occupancy，并提供：

```text
classify_collision_sector_snapshot()
```

返回状态：

- `0`：与当前 Occupancy 完全一致
- `1`：保守快照；包含当前全部实体，但多出一些已经删除的实体
- `2`：不安全；当前存在快照没有覆盖的新增实体
- `-1`：无效快照

状态 0 和 1 可以提交。状态 1 提交后，更新过的部分先进入 Active，之后发生的删除仍保持 dirty，在下一次节流窗口继续追赶。这样燃烧过程中碰撞会持续前进，而不是必须等到燃烧结束。

状态 2 必须丢弃并重建，避免新增实体缺少碰撞。

### 调度顺序调整

每帧现在先运行 SandSimulation，再从该帧最终网格生成碰撞快照：

```text
simulation step
-> collision snapshot/build
-> next physics frame commit
-> player move_and_slide
```

避免先建快照、随后同帧模拟立即让快照过期。

### 移除元素内部的临时自清空

除 Crystal 系列外，Ice、Frozen Acid、Frozen Ammonia 和 Kuiper 的邻居判断也已重写，不再通过临时清除自身再恢复来探测周围状态。

## 预期表现

燃烧期间：

- 动画和像素纹理继续按 repaint 频率更新。
- 玩家不会因为 removal-only dirty Sector 被长时间冻结。
- F6 的红/黄/紫 Sector 频率降低到 PC 约 20Hz、移动端约 10Hz。
- Active 碰撞会在燃烧过程中渐进收缩，不需要等燃烧完全结束。
- 新增实体仍保持 collision-first，不会产生可见但无碰撞的区域。

Removal-only 的设计取舍是：在下一次碰撞提交前，少数已经烧掉的像素可能暂时仍挡住角色，最长主要由 50/100ms 节流间隔和当前碰撞预算决定。它不会产生穿入新实体的安全漏洞。

## Native API

本版本要求：

```text
get_native_api_version() >= 8
```

旧 API 6/7 二进制会自动回退。请重新编译后在 F1 确认：

```text
native yes(api 8)
```

Windows：

```bat
cd extensions\sand-slide
build_windows_collision_sectors.bat
```

Headless smoke test：

```bat
godot --headless --path game res://tests/CollisionSectorSmokeTest.tscn
```

## 调优

先保持默认值测试。仍有 RID 压力时，可降低：

```text
PC collision_dynamic_rebuild_hz: 20 -> 15
Mobile collision_dynamic_rebuild_hz: 10 -> 8
```

角色附近碰撞追赶过慢时，可小幅提高 `critical_collision_budget_ms`，但不要直接恢复到每个模拟 tick 重建。
