# 移动端动作按钮重构

## 控件布局

触控 HUD 现在由三个可同时操作的控件组成：

- 左侧 `CherryVirtualJoystick`：仅提供移动向量。
- 右侧 `JumpButton`：按下触发跳跃，持续按住消耗浮空能量，松开后可再次按下继续浮空。
- 右侧 `FireButton`：按住时按照角色法杖射速连续发射。

右侧按钮参考 `UI.zip` 中 `VirtualButton` 的方案，使用圆形底座、描边、按压缩放、独立颜色和多点触控索引，但不通过 `Input.action_press()` 注入全局动作。按钮状态通过信号直接传给 Player，避免触摸输入释放键盘或鼠标输入。

## 输入职责

`set_virtual_move_input(Vector2)` 只负责移动：

- 地面和空中使用 X 轴移动。
- 水中使用二维向量游动。
- 摇杆上推不再跳跃或浮空。
- 摇杆下拉不再蹲伏或快速下落。

动作按钮分别调用：

```gdscript
set_virtual_jump_fly_pressed(pressed)
set_virtual_fire_pressed(pressed)
```

Player 再把这些状态与键盘、手柄和鼠标输入合并。

## 响应式布局

按钮和摇杆根据屏幕短边缩放，并遵循移动设备安全区域。射击按钮位于右下角，跳跃按钮位于其左上方，方便右手拇指在两者之间滚动，同时支持左手保持摇杆输入。

## Web 平台

桌面浏览器隐藏触控 HUD；手机和平板浏览器显示。对设备信息不明确的浏览器，检测到真实触摸后自动切换为触控模式。隐藏 HUD 时会强制释放摇杆、跳跃和射击状态，避免切换窗口或旋转设备后出现卡键。


## Directional fire update

The fire action is now provided by `VirtualDirectionButton.gd`. Holding the
right disc continuously fires, while dragging around its center updates the
player's aim direction. The last aim direction is retained after release.
The movement joystick never changes aim, jump, levitation, crouch, or fire.
