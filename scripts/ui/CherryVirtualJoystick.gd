@tool
class_name CherryVirtualJoystick
extends Control

## Touch-first analog joystick migrated from the supplied UI module.
##
## The circular base provides normal movement. In fixed mode an additional
## upper 120-degree sector is a combined jump/flight zone. Dragging the handle
## into it keeps emitting movement and also behaves exactly like holding the
## desktop jump/flight action: enter to jump, remain to fly upward, leave to release.

enum JoystickMode {
	FIXED,
	DYNAMIC,
	FOLLOWING,
	DYNAMIC_FOLLOWING,
}

enum VisibilityMode {
	ALWAYS,
	TOUCH_ONLY,
	FADE_IN_OUT,
}

signal joystick_input(output: Vector2)
signal joystick_pressed
signal joystick_released
signal jump_fly_zone_changed(active: bool)
# Compatibility signal for scenes created by earlier revisions.
signal flight_zone_changed(active: bool)

@export_group("Joystick")
@export var mode: JoystickMode = JoystickMode.FIXED
@export var visibility_mode: VisibilityMode = VisibilityMode.FADE_IN_OUT
@export_range(0.0, 1.0, 0.01) var dead_zone: float = 0.16
@export_range(0.05, 1.0, 0.01) var clamp_zone: float = 1.0
@export_range(0.0, 1000.0, 1.0) var touch_area_margin: float = 70.0

@export_group("Jump / Flight Zone")
@export var flight_zone_enabled: bool = true:
	set(value):
		flight_zone_enabled = value
		_update_custom_minimum_size()
		queue_redraw()
@export_range(1.1, 1.8, 0.01) var flight_zone_outer_radius_ratio: float = 1.50:
	set(value):
		flight_zone_outer_radius_ratio = maxf(value, 1.1)
		_update_custom_minimum_size()
		queue_redraw()
@export_range(0.80, 1.05, 0.01) var flight_zone_inner_radius_ratio: float = 0.94
@export_range(0.0, 0.2, 0.01) var flight_zone_exit_hysteresis: float = 0.08
@export_range(60.0, 180.0, 1.0) var flight_zone_arc_degrees: float = 120.0:
	set(value):
		flight_zone_arc_degrees = clampf(value, 60.0, 180.0)
		_update_custom_minimum_size()
		queue_redraw()
@export_range(0.0, 20.0, 0.5) var flight_zone_angle_exit_hysteresis_degrees: float = 6.0
@export var flight_zone_color := Color(0.12, 0.42, 0.62, 0.24)
@export var flight_zone_active_color := Color(0.18, 0.72, 0.96, 0.58)
@export var flight_zone_ring_color := Color(0.52, 0.88, 1.0, 0.86)
@export var flight_zone_caption: String = "JUMP / FLY"
@export_range(8, 30, 1) var flight_zone_caption_size: int = 12

@export_group("Optional InputMap Actions")
@export var emit_input_actions: bool = false
@export var action_left: StringName = &""
@export var action_right: StringName = &""
@export var action_up: StringName = &""
@export var action_down: StringName = &""

@export_group("Appearance")
@export var base_texture: Texture2D
@export var handle_texture: Texture2D
@export_range(10.0, 300.0, 1.0) var base_radius: float = 75.0:
	set(value):
		base_radius = maxf(value, 10.0)
		_update_custom_minimum_size()
		queue_redraw()
@export_range(5.0, 160.0, 1.0) var handle_radius: float = 35.0:
	set(value):
		handle_radius = maxf(value, 5.0)
		queue_redraw()
@export var base_color := Color(0.08, 0.10, 0.14, 0.58)
@export var handle_color := Color(0.78, 0.86, 0.96, 0.82)
@export var handle_pressed_color := Color(0.96, 0.98, 1.0, 0.98)
@export_range(0.0, 1.0, 0.01) var inactive_opacity: float = 0.48
@export_range(0.0, 1.0, 0.01) var active_opacity: float = 1.0
@export_range(0.0, 0.5, 0.01) var fade_duration: float = 0.15

var _is_pressed: bool = false
var _touch_index: int = -1
var _output := Vector2.ZERO
var _base_center := Vector2.ZERO
var _handle_position := Vector2.ZERO
var _flight_zone_active := false
var _fade_tween: Tween

var output: Vector2:
	get:
		return _output

var is_pressed: bool:
	get:
		return _is_pressed

var flight_zone_active: bool:
	get:
		return _flight_zone_active

var strength: float:
	get:
		return _output.length()

var angle: float:
	get:
		return _output.angle()

var effective_base_radius: float:
	get:
		return minf(base_radius, minf(size.x, size.y) * 0.5)

var effective_flight_outer_radius: float:
	get:
		var radius := effective_base_radius
		if not flight_zone_enabled or mode != JoystickMode.FIXED:
			return radius
		var horizontal_extent_scale := maxf(sin(_flight_zone_half_angle()), 0.001)
		var width_limited_radius := (size.x * 0.5) / horizontal_extent_scale
		return minf(
			radius * flight_zone_outer_radius_ratio,
			minf(
				width_limited_radius,
				maxf(radius, size.y - radius)
			)
		)

var effective_handle_radius: float:
	get:
		return minf(handle_radius, effective_base_radius * 0.72)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_custom_minimum_size()
	_reset_geometry()
	_update_visibility()


func _input(event: InputEvent) -> void:
	if not _can_process_touch_input():
		return
	if event is InputEventScreenTouch:
		_handle_touch_event(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event as InputEventScreenDrag)


func _draw() -> void:
	_draw_flight_zone()
	_draw_base()
	_draw_handle()


func cancel_input() -> void:
	_end_touch()


func _handle_touch_event(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _is_pressed or not _touch_is_in_activation_area(touch.position):
			return
		var local_pos := _screen_to_local(touch.position)
		if mode != JoystickMode.FIXED:
			_base_center = _clamp_base_center(local_pos)
			_handle_position = _base_center
		_start_touch(touch.index, local_pos)
	elif touch.index == _touch_index:
		_end_touch()


func _handle_drag_event(drag: InputEventScreenDrag) -> void:
	if drag.index == _touch_index:
		_update_handle_position(_screen_to_local(drag.position))


func _touch_is_in_activation_area(screen_position: Vector2) -> bool:
	return get_global_rect().grow(touch_area_margin).has_point(screen_position)


func _start_touch(index: int, local_pos: Vector2) -> void:
	_touch_index = index
	_is_pressed = true
	_update_handle_position(local_pos)
	_update_visibility()
	joystick_pressed.emit()
	queue_redraw()


func _end_touch() -> void:
	if not _is_pressed and _touch_index == -1 and _output.is_zero_approx() and not _flight_zone_active:
		return
	_is_pressed = false
	_touch_index = -1
	_output = Vector2.ZERO
	_set_flight_zone_active(false)
	if mode != JoystickMode.FIXED:
		_base_center = _default_base_center()
	_handle_position = _base_center
	_update_input_actions(Vector2.ZERO)
	_update_visibility()
	joystick_input.emit(Vector2.ZERO)
	joystick_released.emit()
	queue_redraw()


func _update_handle_position(local_pos: Vector2) -> void:
	var difference := local_pos - _base_center
	var distance := difference.length()
	var normal_max_distance := effective_base_radius * clamp_zone
	var active_inner_ratio := flight_zone_inner_radius_ratio
	if _flight_zone_active:
		active_inner_ratio = maxf(0.0, active_inner_ratio - flight_zone_exit_hysteresis)
	var active_half_angle := _flight_zone_half_angle()
	if _flight_zone_active:
		active_half_angle += deg_to_rad(flight_zone_angle_exit_hysteresis_degrees)
	var can_use_flight_zone := (
		flight_zone_enabled
		and mode == JoystickMode.FIXED
		and distance > effective_base_radius * active_inner_ratio
		and _direction_is_in_flight_sector(difference, active_half_angle)
	)
	var max_distance := effective_flight_outer_radius if can_use_flight_zone else normal_max_distance

	if mode in [JoystickMode.FOLLOWING, JoystickMode.DYNAMIC_FOLLOWING] and distance > normal_max_distance and normal_max_distance > 0.0:
		_base_center = _clamp_base_center(_base_center + difference.normalized() * (distance - normal_max_distance))
		difference = local_pos - _base_center
		distance = difference.length()

	if max_distance > 0.0 and distance > max_distance:
		_handle_position = _base_center + difference.normalized() * max_distance
	else:
		_handle_position = local_pos

	if normal_max_distance <= 0.0:
		_output = Vector2.ZERO
	else:
		# Movement remains normalized by the ordinary joystick radius. The extra
		# zone adds a separate jump/flight state while preserving directional input.
		var raw_vector := _handle_position - _base_center
		var raw_output := raw_vector / normal_max_distance
		var current_strength := minf(raw_output.length(), 1.0)
		if current_strength < dead_zone:
			_output = Vector2.ZERO
		else:
			var remapped_strength := (current_strength - dead_zone) / maxf(1.0 - dead_zone, 0.0001)
			_output = raw_output.normalized() * clampf(remapped_strength, 0.0, 1.0)

	_set_flight_zone_active(can_use_flight_zone and _is_pressed)
	_update_input_actions(_output)
	joystick_input.emit(_output)
	queue_redraw()



func _flight_zone_center_angle() -> float:
	return -PI * 0.5


func _flight_zone_half_angle() -> float:
	return deg_to_rad(clampf(flight_zone_arc_degrees, 60.0, 180.0) * 0.5)


func _direction_is_in_flight_sector(direction: Vector2, half_angle: float) -> bool:
	if direction.is_zero_approx():
		return false
	var angle_delta := wrapf(direction.angle() - _flight_zone_center_angle(), -PI, PI)
	return absf(angle_delta) <= half_angle

func _set_flight_zone_active(active: bool) -> void:
	if active == _flight_zone_active:
		return
	_flight_zone_active = active
	if not Engine.is_editor_hint():
		jump_fly_zone_changed.emit(active)
		flight_zone_changed.emit(active)
	queue_redraw()


func _clamp_base_center(candidate: Vector2) -> Vector2:
	var radius := effective_base_radius
	return Vector2(
		clampf(candidate.x, radius, maxf(radius, size.x - radius)),
		clampf(candidate.y, radius, maxf(radius, size.y - radius))
	)


func _update_input_actions(current_output: Vector2) -> void:
	if Engine.is_editor_hint() or not emit_input_actions:
		return
	_update_single_action(action_left, -current_output.x)
	_update_single_action(action_right, current_output.x)
	_update_single_action(action_up, -current_output.y)
	_update_single_action(action_down, current_output.y)


func _update_single_action(action: StringName, action_strength: float) -> void:
	if action.is_empty() or not InputMap.has_action(action):
		return
	if action_strength > 0.0:
		Input.action_press(action, clampf(action_strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _draw_flight_zone() -> void:
	if not flight_zone_enabled or mode != JoystickMode.FIXED:
		return
	var radius := effective_base_radius
	var inner_radius := radius * flight_zone_inner_radius_ratio
	var outer_radius := effective_flight_outer_radius
	if outer_radius <= inner_radius + 0.5:
		return

	var fill := flight_zone_active_color if _flight_zone_active else flight_zone_color
	var ring := flight_zone_ring_color
	if not _flight_zone_active:
		ring = Color(ring.r, ring.g, ring.b, ring.a * 0.68)

	var center_angle := _flight_zone_center_angle()
	var half_angle := _flight_zone_half_angle()
	var start_angle := center_angle - half_angle
	var end_angle := center_angle + half_angle
	var segments := maxi(24, int(roundf(flight_zone_arc_degrees * 0.4)))
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var progress := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, progress)
		points.append(_base_center + Vector2.from_angle(angle) * outer_radius)
	for index in range(segments, -1, -1):
		var progress := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, progress)
		points.append(_base_center + Vector2.from_angle(angle) * inner_radius)
	draw_colored_polygon(points, fill)

	draw_arc(_base_center, outer_radius, start_angle, end_angle, segments, ring, 2.6 if _flight_zone_active else 1.8, true)
	draw_arc(_base_center, inner_radius, start_angle, end_angle, segments, Color(ring.r, ring.g, ring.b, ring.a * 0.72), 1.5, true)
	for boundary_angle in [start_angle, end_angle]:
		var boundary_direction := Vector2.from_angle(boundary_angle)
		draw_line(
			_base_center + boundary_direction * inner_radius,
			_base_center + boundary_direction * outer_radius,
			ring,
			1.5,
			true
		)
	_draw_flight_zone_icon(inner_radius, outer_radius, ring)


func _draw_flight_zone_icon(inner_radius: float, outer_radius: float, color: Color) -> void:
	# Keep both the glyph and caption inside the annular jump/flight sector.
	# Their positions are derived from the sector radii so responsive scaling and
	# different arc sizes cannot push the caption back into the normal joystick.
	var zone_thickness := maxf(outer_radius - inner_radius, 1.0)
	var icon_radial_distance := lerpf(inner_radius, outer_radius, 0.78)
	var caption_radial_distance := lerpf(inner_radius, outer_radius, 0.34)
	var icon_center := _base_center + Vector2.UP * icon_radial_distance
	var icon_scale := minf(effective_base_radius * 0.13, zone_thickness * 0.22)
	for offset_index in range(2):
		var y_offset := float(offset_index) * icon_scale * 0.72
		var left := icon_center + Vector2(-icon_scale, y_offset)
		var peak := icon_center + Vector2(0.0, -icon_scale * 0.62 + y_offset)
		var right := icon_center + Vector2(icon_scale, y_offset)
		draw_polyline(PackedVector2Array([left, peak, right]), color, 2.2, true)

	if flight_zone_caption.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text_size := font.get_string_size(flight_zone_caption, HORIZONTAL_ALIGNMENT_CENTER, -1, flight_zone_caption_size)
	var caption_center := _base_center + Vector2.UP * caption_radial_distance
	# draw_string() takes a baseline position, so offset it to visually center
	# the text around caption_center while keeping it above the inner arc.
	var baseline := caption_center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline, flight_zone_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, flight_zone_caption_size, color)


func _draw_base() -> void:
	var radius := effective_base_radius
	if base_texture != null:
		_draw_scaled_texture(base_texture, _base_center, radius, base_color)
		return

	# Layered rings and segmented highlights borrow the richer visual language
	# of the supplied UI module while remaining texture-free and resolution-safe.
	var halo := Color(0.20, 0.55, 0.92, base_color.a * (0.34 if _is_pressed else 0.20))
	draw_circle(_base_center, radius * 1.05, halo, true)
	draw_circle(_base_center, radius, base_color, true)
	draw_arc(_base_center, radius, 0.0, TAU, 128, Color(0.48, 0.72, 0.96, base_color.a * 0.92), 2.4, true)
	draw_arc(_base_center, radius * 0.78, 0.0, TAU, 112, Color(0.72, 0.86, 1.0, base_color.a * 0.28), 1.2, true)

	if dead_zone > 0.0:
		var dead_zone_color := Color(0.65, 0.82, 1.0, base_color.a * 0.24)
		draw_arc(_base_center, radius * dead_zone, 0.0, TAU, 64, dead_zone_color, 1.2, true)

	var marker_color := Color(0.72, 0.88, 1.0, base_color.a * 0.72)
	for marker_index in range(4):
		var angle := float(marker_index) * PI * 0.5
		var direction := Vector2.from_angle(angle)
		draw_line(
			_base_center + direction * radius * 0.80,
			_base_center + direction * radius * 0.98,
			marker_color,
			2.2,
			true
		)

	for segment_index in range(4):
		var center_angle := float(segment_index) * PI * 0.5 + PI * 0.25
		draw_arc(
			_base_center,
			radius * 0.91,
			center_angle - 0.23,
			center_angle + 0.23,
			12,
			Color(0.38, 0.68, 1.0, base_color.a * 0.42),
			2.0,
			true
		)


func _draw_handle() -> void:
	var color := handle_pressed_color if _is_pressed else handle_color
	var radius := effective_handle_radius
	if handle_texture != null:
		_draw_scaled_texture(handle_texture, _handle_position, radius, color)
		return
	if _flight_zone_active:
		draw_circle(_handle_position, radius * 1.30, Color(0.20, 0.78, 1.0, 0.22), true)
	var shadow := Color(0.06, 0.10, 0.18, color.a * 0.72)
	draw_circle(_handle_position + Vector2(0.0, radius * 0.08), radius * 1.04, shadow, true)
	draw_circle(_handle_position, radius, color, true)
	draw_arc(_handle_position, radius, 0.0, TAU, 96, Color(0.10, 0.24, 0.42, color.a), 2.2, true)
	draw_arc(_handle_position, radius * 0.72, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, color.a * 0.30), 1.2, true)
	draw_circle(_handle_position, radius * 0.34, Color(1.0, 1.0, 1.0, color.a * 0.20), true)
	var indicator := _output.normalized() if not _output.is_zero_approx() else Vector2.UP
	draw_line(
		_handle_position - indicator * radius * 0.10,
		_handle_position + indicator * radius * 0.36,
		Color(1.0, 1.0, 1.0, color.a * 0.58),
		2.0,
		true
	)


func _draw_scaled_texture(texture: Texture2D, center: Vector2, radius: float, tint: Color) -> void:
	var texture_size := texture.get_size()
	var texture_scale := (radius * 2.0) / maxf(texture_size.x, texture_size.y)
	var draw_size := texture_size * texture_scale
	draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, tint)


func _update_visibility() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	match visibility_mode:
		VisibilityMode.ALWAYS:
			visible = true
			modulate.a = 1.0
		VisibilityMode.TOUCH_ONLY:
			visible = _is_pressed
			modulate.a = 1.0
		VisibilityMode.FADE_IN_OUT:
			visible = true
			var target_alpha := active_opacity if _is_pressed else inactive_opacity
			if not is_inside_tree() or fade_duration <= 0.0:
				modulate.a = target_alpha
			else:
				_fade_tween = create_tween()
				_fade_tween.tween_property(self, "modulate:a", target_alpha, fade_duration)


func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _default_base_center() -> Vector2:
	if flight_zone_enabled and mode == JoystickMode.FIXED:
		return Vector2(size.x * 0.5, effective_flight_outer_radius)
	return size * 0.5


func _reset_geometry() -> void:
	_base_center = _default_base_center()
	_handle_position = _base_center
	queue_redraw()


func _update_custom_minimum_size() -> void:
	var outer_radius := base_radius * flight_zone_outer_radius_ratio if flight_zone_enabled else base_radius
	var half_width := base_radius
	if flight_zone_enabled:
		half_width = maxf(base_radius, outer_radius * sin(_flight_zone_half_angle()))
	custom_minimum_size = Vector2(half_width * 2.0, outer_radius + base_radius)


func _release_all_actions() -> void:
	for action: StringName in [action_left, action_right, action_up, action_down]:
		if not action.is_empty() and InputMap.has_action(action):
			Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not Engine.is_editor_hint():
			_release_all_actions()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not _can_process_touch_input():
			_end_touch()
	elif what == NOTIFICATION_RESIZED:
		if not _is_pressed or mode == JoystickMode.FIXED:
			_reset_geometry()


func _can_process_touch_input() -> bool:
	return not Engine.is_editor_hint() and is_visible_in_tree()
