@tool
class_name VirtualActionButton
extends Control

## Touch action button inspired by the supplied UI.zip VirtualButton.
## It emits state directly instead of injecting InputMap actions, so keyboard,
## mouse and touch inputs can coexist without releasing one another.

enum IconType {
	JUMP,
	FIRE,
}

signal button_down
signal button_up
signal pressed_changed(pressed: bool)

@export_group("Appearance")
@export var icon_type: IconType = IconType.JUMP
@export_range(20.0, 120.0, 1.0) var button_radius: float = 46.0:
	set(value):
		button_radius = maxf(value, 20.0)
		custom_minimum_size = Vector2.ONE * button_radius * 2.0
		queue_redraw()
@export_range(0.0, 40.0, 1.0) var touch_margin: float = 12.0
@export var normal_color := Color(0.10, 0.24, 0.42, 0.72)
@export var pressed_color := Color(0.20, 0.62, 0.92, 0.96)
@export var ring_color := Color(0.55, 0.78, 1.0, 0.88)
@export var icon_color := Color(0.96, 0.98, 1.0, 1.0)
@export var glow_color := Color(0.35, 0.75, 1.0, 0.24)
@export var caption: String = "JUMP"
@export_range(8, 30, 1) var caption_font_size: int = 12
@export_range(0.6, 1.0, 0.01) var pressed_scale: float = 0.90

var _is_pressed := false
var _touch_index := -1

var is_pressed: bool:
	get:
		return _is_pressed

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
	var glow_alpha := glow_color.a * (1.8 if _is_pressed else 1.0)
	var active_glow := Color(glow_color.r, glow_color.g, glow_color.b, clampf(glow_alpha, 0.0, 1.0))

	# Layered circles reproduce the clean, texture-free style of the source UI.
	draw_circle(center, radius * 1.08, active_glow, true)
	draw_circle(center, radius, fill, true)
	draw_arc(center, radius, 0.0, TAU, 96, ring_color, 2.5 if _is_pressed else 2.0, true)
	draw_arc(center, radius * 0.78, 0.0, TAU, 80, Color(1.0, 1.0, 1.0, 0.12), 1.0, true)
	_draw_edge_notches(center, radius)

	match icon_type:
		IconType.FIRE:
			_draw_fire_icon(center, radius)
		_:
			_draw_jump_icon(center, radius)
	_draw_caption(center, radius)


func cancel_input() -> void:
	_release()


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _is_pressed:
			return
		var local_pos := _screen_to_local(touch.position)
		if local_pos.distance_to(size * 0.5) <= effective_radius + touch_margin:
			_press(touch.index)
	elif touch.index == _touch_index:
		_release()


func _handle_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch_index:
		return
	var local_pos := _screen_to_local(drag.position)
	if local_pos.distance_to(size * 0.5) > effective_radius + touch_margin * 2.5:
		_release()


func _press(index: int) -> void:
	_touch_index = index
	_is_pressed = true
	button_down.emit()
	pressed_changed.emit(true)
	queue_redraw()


func _release() -> void:
	if not _is_pressed and _touch_index == -1:
		return
	_is_pressed = false
	_touch_index = -1
	button_up.emit()
	pressed_changed.emit(false)
	queue_redraw()


func _draw_edge_notches(center: Vector2, radius: float) -> void:
	var notch_color := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.72)
	for angle_index in range(4):
		var angle := float(angle_index) * PI * 0.5
		var direction := Vector2.from_angle(angle)
		draw_line(
			center + direction * radius * 0.86,
			center + direction * radius * 1.03,
			notch_color,
			2.0,
			true
		)


func _draw_jump_icon(center: Vector2, radius: float) -> void:
	var icon_center := center + Vector2(0.0, -radius * 0.13)
	var width := radius * 0.42
	var height := radius * 0.42
	var points := PackedVector2Array([
		icon_center + Vector2(-width, height * 0.20),
		icon_center + Vector2(0.0, -height),
		icon_center + Vector2(width, height * 0.20),
	])
	draw_polyline(points, icon_color, maxf(2.5, radius * 0.075), true)
	draw_line(
		icon_center + Vector2(0.0, -height * 0.72),
		icon_center + Vector2(0.0, height * 0.62),
		icon_color,
		maxf(2.5, radius * 0.075),
		true
	)
	# Two small exhaust marks visually communicate the upward jump action.
	var exhaust_color := Color(icon_color.r, icon_color.g, icon_color.b, 0.70)
	draw_line(icon_center + Vector2(-width * 0.34, height * 0.58), icon_center + Vector2(-width * 0.34, height * 0.86), exhaust_color, 2.0, true)
	draw_line(icon_center + Vector2(width * 0.34, height * 0.58), icon_center + Vector2(width * 0.34, height * 0.86), exhaust_color, 2.0, true)


func _draw_fire_icon(center: Vector2, radius: float) -> void:
	var icon_center := center + Vector2(0.0, -radius * 0.12)
	var reticle_radius := radius * 0.25
	draw_arc(icon_center, reticle_radius, 0.0, TAU, 48, icon_color, maxf(2.0, radius * 0.06), true)
	draw_circle(icon_center, radius * 0.075, icon_color, true)
	for angle_index in range(4):
		var angle := float(angle_index) * PI * 0.5
		var direction := Vector2.from_angle(angle)
		draw_line(
			icon_center + direction * reticle_radius * 1.18,
			icon_center + direction * reticle_radius * 1.72,
			icon_color,
			maxf(2.0, radius * 0.055),
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
	var baseline := center + Vector2(-text_size.x * 0.5, radius * 0.58 + text_size.y * 0.25)
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
