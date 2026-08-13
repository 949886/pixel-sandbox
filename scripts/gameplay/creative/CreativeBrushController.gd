class_name CreativeBrushController
extends Node2D

signal material_picked(element_id: int)
signal brush_changed(tool: int, element_id: int, radius: float)

enum Tool {
	BRUSH,
	ERASE,
	PICKER,
}

@export_range(1.0, 64.0, 1.0) var brush_radius: float = 8.0
@export_range(1.0, 32.0, 0.5) var minimum_spacing: float = 1.0

var selected_tool: int = Tool.BRUSH
var selected_element_id: int = 1
var _world_service: WorldGameplayService
var _mode_manager: GameModeManager
var _drawing: bool = false
var _last_draw_world: Vector2 = Vector2.ZERO
var _last_preview_world: Vector2 = Vector2.INF
var _interaction_enabled: bool = true

func _ready() -> void:
	add_to_group(&"creative_brush")
	add_to_group(&"creative_input_capture")
	call_deferred("_bind_dependencies")

func _bind_dependencies() -> void:
	_world_service = get_parent().get_node_or_null("GameplayWorld") as WorldGameplayService
	_mode_manager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	if _mode_manager != null:
		_mode_manager.register_input_capture(self)
	if _world_service != null:
		var palette: MaterialPalette = _world_service.material_palette()
		if palette != null and palette.entry_for_element_id(selected_element_id) == null:
			for entry: MaterialEntry in palette.entries:
				if entry != null and entry.engine_element_id != 0:
					selected_element_id = entry.engine_element_id
					break
	queue_redraw()



func _exit_tree() -> void:
	if _mode_manager != null and is_instance_valid(_mode_manager):
		_mode_manager.unregister_input_capture(self)

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_drawing = false
	queue_redraw()

func blocks_gameplay_action(action: StringName) -> bool:
	return action == &"wand_fire" and _interaction_enabled and _creative_world_editing_enabled()

func set_tool(tool: int) -> void:
	selected_tool = clampi(tool, Tool.BRUSH, Tool.PICKER)
	brush_changed.emit(selected_tool, selected_element_id, brush_radius)
	queue_redraw()

func set_paint_element(element_id: int) -> void:
	selected_element_id = clampi(element_id, 0, 4096)
	selected_tool = Tool.BRUSH
	brush_changed.emit(selected_tool, selected_element_id, brush_radius)

func set_brush_radius(value: float) -> void:
	brush_radius = clampf(value, 1.0, 64.0)
	brush_changed.emit(selected_tool, selected_element_id, brush_radius)
	queue_redraw()

func _process(_delta: float) -> void:
	if not _interaction_enabled or not _creative_world_editing_enabled():
		if visible:
			visible = false
		return
	visible = true
	var mouse_world: Vector2 = get_global_mouse_position().floor()
	if mouse_world != _last_preview_world:
		_last_preview_world = mouse_world
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled or not _creative_world_editing_enabled() or _world_service == null:
		_drawing = false
		return
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				var world_position: Vector2 = get_global_mouse_position().floor()
				if selected_tool == Tool.PICKER:
					_pick_material(world_position)
				else:
					_drawing = true
					_last_draw_world = world_position
					_apply_brush(world_position)
				get_viewport().set_input_as_handled()
			else:
				_drawing = false
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_MIDDLE:
			_pick_material(get_global_mouse_position().floor())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drawing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drawing = false
			return
		var current_world: Vector2 = get_global_mouse_position().floor()
		_paint_segment(_last_draw_world, current_world)
		_last_draw_world = current_world
		get_viewport().set_input_as_handled()

func _paint_segment(start: Vector2, finish: Vector2) -> void:
	var distance: float = start.distance_to(finish)
	var spacing: float = maxf(minimum_spacing, brush_radius * 0.45)
	if distance <= spacing:
		_apply_brush(finish)
		return
	var steps: int = mini(64, ceili(distance / spacing))
	for index: int in range(1, steps + 1):
		var weight: float = float(index) / float(steps)
		_apply_brush(start.lerp(finish, weight).floor())

func _apply_brush(world_position: Vector2) -> void:
	if selected_tool == Tool.ERASE:
		_world_service.erase_material_circle(world_position, brush_radius)
	elif selected_tool == Tool.BRUSH:
		_world_service.paint_material_circle(world_position, brush_radius, selected_element_id, false)

func _pick_material(world_position: Vector2) -> void:
	var element_id: int = _world_service.get_element_id_at_world_position(world_position)
	selected_element_id = element_id
	selected_tool = Tool.BRUSH
	material_picked.emit(element_id)
	brush_changed.emit(selected_tool, selected_element_id, brush_radius)
	queue_redraw()

func _creative_world_editing_enabled() -> bool:
	if _mode_manager == null or not is_instance_valid(_mode_manager) or not _mode_manager.is_creative():
		return false
	var rules: GameRules = _mode_manager.active_rules()
	return rules != null and rules.allow_world_editing

func _draw() -> void:
	if not _interaction_enabled or not _creative_world_editing_enabled():
		return
	var center: Vector2 = to_local(_last_preview_world)
	var preview_color: Color = Color(1.0, 0.65098, 0.25098, 0.95) if selected_tool != Tool.ERASE else Color(1.0, 0.317647, 0.239216, 0.95)
	draw_arc(center, brush_radius, 0.0, TAU, 48, preview_color, 1.0, false)
	draw_line(center - Vector2(3.0, 0.0), center + Vector2(3.0, 0.0), preview_color, 1.0, false)
	draw_line(center - Vector2(0.0, 3.0), center + Vector2(0.0, 3.0), preview_color, 1.0, false)
