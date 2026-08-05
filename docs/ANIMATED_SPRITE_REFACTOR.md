# AnimatedSprite2D 角色动画重构

## 目标

角色身体不再由 `Sprite2D.region_rect`、手写帧索引和累计时间驱动，而改为 Godot 4 原生的：

- `AnimatedSprite2D`
- 外部 `SpriteFrames` 资源
- `play()` / `speed_scale`
- `animation_finished` 动作结束信号

移动、飞行、游泳、瞄准、施法和像素地形交互逻辑保持不变。

## 生成的资源

### 身体

`res://assets/player/player_sprite_frames.tres`

- 来源：`player.xml` 与 `player.png`
- 动画数量：50
- 总帧数：243
- 每个 XML `RectAnimation` 都生成同名动画
- `frame_wait` 转换为 `SpriteFrames` FPS：`speed = 1 / frame_wait`
- XML 中 `loop="0"` 的动作生成非循环动画
- 每一帧使用独立 `AtlasTexture` 指向原始图集区域

资源包含当前控制器使用的动作，也保留未接入玩法的动作，例如：

- `stand`、`walk`、`run`
- `jump_up`、`jump_fall`、`land`
- `fly_idle`、`fly_move`
- `swim_idle`、`swim_move`
- `kick`、`kick_alt` 及蹲伏版本
- `burn`、`knockback`、`hurt`
- `eat`、`grab_item`、`throw_item`
- `push`、`cough`
- `intro_sleep`、`intro_stand_up`

### 手臂

`res://assets/player/player_arm_sprite_frames.tres`

包含：

- `default`
- `down`
- `without_item`

## 场景结构变化

`scenes/Player.tscn` 中：

- `BodySprite`：`Sprite2D` → `AnimatedSprite2D`
- `ArmSprite`：`Sprite2D` → `AnimatedSprite2D`
- 删除 `texture`、`region_enabled`、`region_rect`
- 添加 `sprite_frames`、`animation`、`autoplay`

法杖仍为普通 `Sprite2D`，因为当前法杖资源是单帧图片。

## 控制器变化

### 删除的旧逻辑

`Player.gd` 不再维护：

- `ANIMATIONS` 手写动画表
- `_animation_name`
- `_animation_frame`
- `_animation_elapsed`
- `_advance_animation()`
- `_apply_animation_frame()`

### 新播放流程

每个物理帧只负责选择目标动画：

```gdscript
var selected := _select_animation()
_update_animation_speed(selected)
_play_body_animation(selected)
```

真正的帧推进、循环和非循环停止由 `AnimatedSprite2D` 完成。

### 动作结束控制

踢击和落地不再使用固定倒计时猜测动画长度：

- 踢击开始时设置动作锁并重启动画
- `animation_finished` 后解除动作锁并恢复手臂、法杖显示
- 落地动画播放完后解除落地状态

因此修改 SpriteFrames 的帧数或 FPS 时，不需要同步修改动作计时常量。

### 速度联动

移动动画使用 `AnimatedSprite2D.speed_scale` 与实际速度联动：

- 普通行走与倒退
- 奔跑
- 蹲伏行走
- 游泳移动
- 飞行移动

SpriteFrames 中保存的是素材原始 FPS，`speed_scale` 只在其基础上做有限范围调整。

### 踢击变体

连续踢击会在以下动画之间交替：

- `kick` / `kick_alt`
- `kick_crouched` / `kick_alt_crouched`

### 图像原点

角色根节点仍位于脚底。动画切换时会根据首帧纹理尺寸和 XML 原点更新 `AnimatedSprite2D.position`：

```gdscript
position = frame_size * 0.5 - origin
```

默认原点为 `(31, 35)`；`intro_sleep` 和 `intro_stand_up` 使用 XML 指定的 `(10, 14)`。

## 重新生成资源

项目附带生成脚本：

```bash
python3 tools/generate_sprite_frames.py
```

修改 PNG 或 XML 后运行即可重新生成两份 `.tres`，游戏运行时不依赖 Python，也不会解析 XML。

## 扩展新动画

在 `_select_animation()` 中返回已经存在于 SpriteFrames 中的动画名即可。例如接入受击：

```gdscript
return &"hurt_fly" if flying else (&"hurt_swim" if swimming else &"hurt")
```

对于必须完整播放的非循环动作，采用与踢击相同的动作锁和 `animation_finished` 处理，不建议重新引入固定计时器。

## XML Event 标签

原 XML 中的 `step`、`jump`、`swim`、`kick` 等逐帧事件不是图像帧数据，Godot 的 `SpriteFrames` 本身也不保存事件轨道，因此本次没有把这些标签伪装成动画帧。

需要声音、踢击命中框或粒子精确落在某一帧时，可监听 `AnimatedSprite2D.frame_changed`，根据 `animation + frame` 派发事件；动作是否结束仍使用 `animation_finished`。
