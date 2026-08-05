@tool
class_name VirtualDirectionButton
extends Control

## Directional hold button inspired by UI.zip/VirtualDirectionButton.
## Pressing starts the action, dragging continuously updates a normalized aim
## direction, and releasing stops the action while preserving the last direction.

signal direction_changed(direction: Vector2)
signal button_down
signal button_up
signal pressed_changed(pressed: bool)

@export_group("Interaction")
@export_range(20.0, 120.0, 1.0) var button_radius: float = 54.0:
	set(value):
		button_radius = maxf(value, 20.0)
		custom_minimum_size = Vector2.ONE * button_radius * 2.0
		queue_redraw()
@export_range(0.0, 48.0, 1.0) var touch_margin: float = 16.0
@export_range(0.0, 0.75, 0.01) var dead_zone: float = 0.10
@export_range(0.6, 1.0, 0.01) var pressed_scale: float = 0.90

@export_group("Appearance")
@export var normal_color := Color(0.48, 0.12, 0.09, 0.76)
@export var pressed_color := Color(0.96, 0.34, 0.16, 0.98)
@export var ring_color := Color(1.0, 0.66, 0.38, 0.94)
@export var icon_color := Color(1.0, 0.97, 0.90, 1.0)
@export var glow_color := Color(1.0, 0.28, 0.08, 0.30)
@export var direction_arc_color := Color(1.0, 0.84, 0.52, 1.0)
@export_range(1.0, 10.0, 0.5) var direction_arc_width: float = 4.0
@export_range(0.1, 1.2, 0.01) var direction_arc_spread: float = 0.48
@export var caption: String = "FIRE"
@export_range(8, 30, 1) var caption_font_size: int = 12

var _is_pressed := false
var _touch_index := -1
var _direction := Vector2.RIGHT
var _indicator_strength := 0.0

var is_pressed: bool:
	get:
		return _is_pressed

var direction: Vector2:
	get:
		return _direction

var effective_radius: float:
	get:
		return minf(button_radius, minf(size.x, size.y) * 0.5)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * button_radius * 2.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _can_process_touch_input():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _draw() -> void:
	var center := size * 0.5
	var radius := effective_radius * (pressed_scale if _is_pressed else 1.0)
	var fill := pressed_color if _is_pressed else normal_color
	var glow_alpha := glow_color.a * (1.9 if _is_pressed else 1.0)
	var active_glow := Color(glow_color.r, glow_color.g, glow_color.b, clampf(glow_alpha, 0.0, 1.0))

	draw_circle(center, radius * 1.10, active_glow, true)
	draw_circle(center, radius, fill, true)
	draw_arc(center, radius, 0.0, TAU, 112, ring_color, 2.8 if _is_pressed else 2.1, true)
	draw_arc(center, radius * 0.77, 0.0, TAU, 88, Color(1.0, 1.0, 1.0, 0.12), 1.0, true)
	_draw_edge_notches(center, radius)
	_draw_reticle(center, radius)
	_draw_direction_indicator(center, radius)
	_draw_caption(center, radius)


func cancel_input() -> void:
	_release()


func set_direction(value: Vector2, emit_signal: bool = false) -> void:
	if value.length_squared() <= 0.0001:
		return
	_direction = value.normalized()
	_indicator_strength = 1.0
	if emit_signal and not Engine.is_editor_hint():
		direction_changed.emit(_direction)
	queue_redraw()


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _is_pressed or not _touch_is_in_activation_area(touch.position):
			return
		var local_pos := _screen_to_local(touch.position)
		_update_direction(local_pos, true)
		_press(touch.index)
	elif touch.index == _touch_index:
		_release()


func _handle_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch_index:
		return
	_update_direction(_screen_to_local(drag.position), true)


func _press(index: int) -> void:
	_touch_index = index
	_is_pressed = true
	# Emit the displayed/last direction before the pressed state so a center tap
	# fires along the same direction shown by the control.
	direction_changed.emit(_direction)
	button_down.emit()
	pressed_changed.emit(true)
	queue_redraw()


func _release() -> void:
	if not _is_pressed and _touch_index == -1:
		return
	_is_pressed = false
	_touch_index = -1
	_indicator_strength = 0.0
	button_up.emit()
	pressed_changed.emit(false)
	queue_redraw()


func _update_direction(local_pos: Vector2, should_emit: bool) -> void:
	var center := size * 0.5
	var offset := local_pos - center
	var radius := maxf(effective_radius, 1.0)
	var normalized_distance := offset.length() / radius
	_indicator_strength = clampf(normalized_distance, 0.0, 1.0)
	if normalized_distance < dead_zone or offset.length_squared() <= 0.0001:
		queue_redraw()
		return
	_direction = offset.normalized()
	if should_emit and not Engine.is_editor_hint():
		direction_changed.emit(_direction)
	queue_redraw()


func _touch_is_in_activation_area(screen_position: Vector2) -> bool:
	return get_global_rect().grow(touch_margin).has_point(screen_position)


func _draw_edge_notches(center: Vector2, radius: float) -> void:
	var notch_color := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.72)
	for angle_index in range(8):
		var angle := float(angle_index) * PI * 0.25
		var ray := Vector2.from_angle(angle)
		var inner := radius * (0.89 if angle_index % 2 == 0 else 0.93)
		draw_line(center + ray * inner, center + ray * radius * 1.02, notch_color, 1.8, true)


func _draw_reticle(center: Vector2, radius: float) -> void:
	var reticle_radius := radius * 0.22
	draw_arc(center, reticle_radius, 0.0, TAU, 48, icon_color, maxf(2.0, radius * 0.052), true)
	draw_circle(center, radius * 0.065, icon_color, true)
	for angle_index in range(4):
		var ray := Vector2.from_angle(float(angle_index) * PI * 0.5)
		draw_line(
			center + ray * reticle_radius * 1.18,
			center + ray * reticle_radius * 1.62,
			icon_color,
			maxf(1.8, radius * 0.045),
			true
		)


func _draw_direction_indicator(center: Vector2, radius: float) -> void:
	var direction_angle := _direction.angle()
	var visual_strength := maxf(_indicator_strength, 0.48 if _is_pressed else 0.28)
	var endpoint := center + _direction * radius * (0.34 + visual_strength * 0.36)
	var line_color := Color(direction_arc_color.r, direction_arc_color.g, direction_arc_color.b, 0.98 if _is_pressed else 0.58)
	draw_line(center + _direction * radius * 0.28, endpoint, line_color, maxf(2.2, radius * 0.06), true)
	draw_circle(endpoint, maxf(3.0, radius * 0.075), line_color, true)
	draw_arc(
		center,
		radius * 0.88,
		direction_angle - direction_arc_spread,
		direction_angle + direction_arc_spread,
		32,
		line_color,
		direction_arc_width if _is_pressed else maxf(2.0, direction_arc_width * 0.62),
		true
	)


func _draw_caption(center: Vector2, radius: float) -> void:
	if caption.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var scaled_size := maxi(8, int(float(caption_font_size) * radius / maxf(button_radius, 1.0)))
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_size)
	var baseline := center + Vector2(-text_size.x * 0.5, radius * 0.61 + text_size.y * 0.25)
	draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, Color(icon_color.r, icon_color.g, icon_color.b, 0.90))


func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not _can_process_touch_input():
			_release()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_PREDELETE:
		_release()


func _can_process_touch_input() -> bool:
	return not Engine.is_editor_hint() and is_visible_in_tree()
