class_name TouchControls
extends CanvasLayer

const PlatformUtilsScript = preload("res://scripts/platform/PlatformUtils.gd")

## Platform-aware touch HUD. The left joystick is movement-only. Jump/levitation
## and continuous wand fire are exposed as independent multi-touch buttons.

enum VisibilityMode {
	AUTO,
	ALWAYS_SHOW,
	ALWAYS_HIDE,
}

@export_group("Visibility")
@export var visibility_mode: VisibilityMode = VisibilityMode.AUTO
@export var player_path: NodePath = ^"../Player"
@export_range(0.25, 5.0, 0.25) var web_recheck_interval: float = 1.5

@export_group("Responsive layout")
@export_range(0.5, 2.0, 0.05) var control_scale: float = 1.0
@export_range(40.0, 120.0, 1.0) var minimum_radius: float = 54.0
@export_range(40.0, 140.0, 1.0) var maximum_radius: float = 88.0
@export_range(0.05, 0.2, 0.005) var short_side_radius_ratio: float = 0.105
@export_range(12.0, 72.0, 1.0) var minimum_edge_margin: float = 22.0
@export_range(0.35, 0.9, 0.01) var fire_button_radius_ratio: float = 0.64
@export_range(0.35, 0.9, 0.01) var jump_button_radius_ratio: float = 0.55

@onready var touch_root: Control = $TouchRoot
@onready var joystick: CherryVirtualJoystick = $TouchRoot/Joystick
@onready var jump_button: VirtualActionButton = $TouchRoot/JumpButton
@onready var fire_button: VirtualDirectionButton = $TouchRoot/FireButton

var _player: Node
var _web_touch_observed := false
var _web_recheck_timer := 0.0
var _controls_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_player()
	joystick.joystick_input.connect(_on_joystick_input)
	jump_button.pressed_changed.connect(_on_jump_pressed_changed)
	fire_button.direction_changed.connect(_on_fire_direction_changed)
	fire_button.pressed_changed.connect(_on_fire_pressed_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_refresh_platform_and_layout")


func _process(delta: float) -> void:
	if visibility_mode != VisibilityMode.AUTO or not PlatformUtilsScript.is_web_platform():
		return
	_web_recheck_timer -= delta
	if _web_recheck_timer <= 0.0:
		_web_recheck_timer = web_recheck_interval
		_apply_platform_visibility()


func _input(event: InputEvent) -> void:
	if visibility_mode != VisibilityMode.AUTO or not PlatformUtilsScript.is_web_platform():
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not _web_touch_observed:
		_web_touch_observed = true
		_apply_platform_visibility()


func set_controls_visible(should_show: bool) -> void:
	_controls_visible = should_show
	touch_root.visible = should_show
	if not should_show:
		joystick.cancel_input()
		jump_button.cancel_input()
		fire_button.cancel_input()
		_send_virtual_move_input(Vector2.ZERO)
		_send_virtual_jump_input(false)
		_send_virtual_fire_input(false)
	_set_player_touch_mode(should_show)


func is_controls_visible() -> bool:
	return _controls_visible


func refresh_platform_detection() -> void:
	_refresh_platform_and_layout()


func _refresh_platform_and_layout() -> void:
	_resolve_player()
	_apply_platform_visibility()
	_update_responsive_layout()


func _apply_platform_visibility() -> void:
	var should_show: bool
	match visibility_mode:
		VisibilityMode.ALWAYS_SHOW:
			should_show = true
		VisibilityMode.ALWAYS_HIDE:
			should_show = false
		_:
			should_show = PlatformUtilsScript.is_mobile_native_platform()
			if PlatformUtilsScript.is_web_platform():
				should_show = PlatformUtilsScript.is_mobile_web_browser() or _web_touch_observed
	if should_show != _controls_visible or touch_root.visible != should_show:
		set_controls_visible(should_show)


func _update_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_rect := _safe_viewport_rect(viewport_size)
	var short_side := minf(safe_rect.size.x, safe_rect.size.y)
	var joystick_radius := clampf(
		short_side * short_side_radius_ratio * control_scale,
		minimum_radius,
		maximum_radius
	)
	var joystick_diameter := joystick_radius * 2.0
	var edge_margin := maxf(minimum_edge_margin, short_side * 0.032) * control_scale

	joystick.base_radius = joystick_radius
	joystick.handle_radius = joystick_radius * 0.46
	joystick.touch_area_margin = joystick_radius * 0.72
	joystick.size = Vector2.ONE * joystick_diameter
	joystick.position = Vector2(
		safe_rect.position.x + edge_margin,
		safe_rect.end.y - edge_margin - joystick_diameter
	)

	var fire_radius := clampf(joystick_radius * fire_button_radius_ratio, 38.0, 60.0)
	var jump_radius := clampf(joystick_radius * jump_button_radius_ratio, 34.0, 54.0)
	_set_direction_button_geometry(fire_button, fire_radius)
	_set_button_geometry(jump_button, jump_radius)

	# UI.zip-style diamond arrangement: main attack button at the lower-right,
	# jump/levitation above and to its left for comfortable thumb rolling.
	var fire_center := Vector2(
		safe_rect.end.x - edge_margin - fire_radius,
		safe_rect.end.y - edge_margin - fire_radius
	)
	var jump_center := fire_center + Vector2(
		-(fire_radius + jump_radius) * 1.12,
		-(fire_radius + jump_radius) * 0.88
	)
	fire_button.position = fire_center - Vector2.ONE * fire_radius
	jump_button.position = jump_center - Vector2.ONE * jump_radius


func _set_button_geometry(button: VirtualActionButton, radius: float) -> void:
	button.button_radius = radius
	button.touch_margin = radius * 0.28
	button.size = Vector2.ONE * radius * 2.0


func _set_direction_button_geometry(button: VirtualDirectionButton, radius: float) -> void:
	button.button_radius = radius
	button.touch_margin = radius * 0.32
	button.size = Vector2.ONE * radius * 2.0


func _safe_viewport_rect(viewport_size: Vector2) -> Rect2:
	var fallback := Rect2(Vector2.ZERO, viewport_size)
	if not PlatformUtilsScript.is_mobile_native_platform():
		return fallback
	var safe_pixels := DisplayServer.get_display_safe_area()
	var window_size := Vector2(DisplayServer.window_get_size())
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return fallback
	var viewport_per_window := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	return Rect2(
		Vector2(safe_pixels.position) * viewport_per_window,
		Vector2(safe_pixels.size) * viewport_per_window
	)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_node_or_null(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_set_player_touch_mode(_controls_visible)


func _on_joystick_input(output: Vector2) -> void:
	_send_virtual_move_input(output)


func _on_jump_pressed_changed(pressed: bool) -> void:
	_send_virtual_jump_input(pressed)


func _on_fire_direction_changed(direction: Vector2) -> void:
	_send_virtual_aim_input(direction)


func _on_fire_pressed_changed(pressed: bool) -> void:
	_send_virtual_fire_input(pressed)


func _send_virtual_move_input(output: Vector2) -> void:
	_resolve_player()
	if _player != null and _player.has_method("set_virtual_move_input"):
		_player.call("set_virtual_move_input", output)


func _send_virtual_jump_input(pressed: bool) -> void:
	_resolve_player()
	if _player != null and _player.has_method("set_virtual_jump_fly_pressed"):
		_player.call("set_virtual_jump_fly_pressed", pressed)


func _send_virtual_aim_input(direction: Vector2) -> void:
	_resolve_player()
	if _player != null and _player.has_method("set_virtual_aim_direction"):
		_player.call("set_virtual_aim_direction", direction)


func _send_virtual_fire_input(pressed: bool) -> void:
	_resolve_player()
	if _player != null and _player.has_method("set_virtual_fire_pressed"):
		_player.call("set_virtual_fire_pressed", pressed)


func _set_player_touch_mode(active: bool) -> void:
	if _player != null and _player.has_method("set_virtual_controls_active"):
		_player.call("set_virtual_controls_active", active)


func _on_viewport_size_changed() -> void:
	_update_responsive_layout()
	if PlatformUtilsScript.is_web_platform():
		_apply_platform_visibility()
