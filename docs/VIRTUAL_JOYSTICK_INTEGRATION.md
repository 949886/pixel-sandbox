# Virtual joystick and action-button integration

## Runtime platform policy

- Windows/macOS/Linux native builds: touch controls are hidden.
- Android/iOS native builds: touch controls are shown.
- Web builds: `PlatformUtils` checks browser mobile hints, user agent, touch
  points, pointer/hover capabilities, and viewport/screen size.
- An actual `InputEventScreenTouch` promotes an ambiguous Web session to touch
  mode, covering installed PWAs and privacy-reduced browser user agents.
- Detection refreshes after viewport changes and periodically, so browser
  device emulation or orientation changes can update the UI without reloading.
- `WorldManager` uses the same detector to choose PC or mobile runtime profiles.

## Input mapping

The touch HUD does not inject synthetic InputMap events. It sends independent
state directly to `Player.gd`:

- Joystick X: ground/air horizontal movement.
- Joystick X/Y: two-dimensional swimming movement.
- Joystick upper semicircle: touch-hover request while preserving movement.
- Jump button: jump press/release only.
- Fire button: hold for continuous wand fire at the configured fire rate.

The ordinary joystick circle does not trigger jump, crouch, or fast fall. Only the extra upper semicircle requests touch hovering. Physical
keyboard/mouse/gamepad input is merged with touch state inside Player, avoiding
one device releasing another device's active input.

## Responsive layout

`TouchControls.gd` derives all radii from the viewport short side, clamps them to
usable ranges, respects native safe areas, and recalculates on resize or
orientation changes. The joystick remains lower-left. The primary fire button is
lower-right, with the jump-only button above-left in a UI.zip-style action cluster.

All three controls track separate touch indices. The left thumb can move/hover while the right thumb aims and fires; jump only needs a short independent press.

## Files

- `scripts/platform/PlatformUtils.gd`
- `scripts/ui/CherryVirtualJoystick.gd`
- `scripts/ui/VirtualActionButton.gd`
- `scripts/ui/TouchControls.gd`
- `scenes/ui/TouchControls.tscn`
- `scripts/player/Player.gd`
- `scenes/World.tscn`
