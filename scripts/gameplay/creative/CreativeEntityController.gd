class_name CreativeEntityController
extends Node2D

signal tool_changed(tool: int)
signal entity_selected(definition: CreativeEntityDef)
signal entity_spawned(node: Node)
signal entity_deleted(node_name: String)

enum Tool {
	SPAWN,
	DELETE,
}

@export_range(0.05, 2.0, 0.05) var spawn_cooldown_seconds: float = 0.12

var selected_tool: int = Tool.SPAWN
var selected_entity: CreativeEntityDef
var _mode_manager: GameModeManager
var _interaction_enabled: bool = false
var _spawn_cooldown: float = 0.0
var _last_preview_world: Vector2 = Vector2.INF

func _ready() -> void:
	add_to_group(&"creative_entity_controller")
	var entities: Array[CreativeEntityDef] = CreativeEntityCatalog.all_entities()
	if not entities.is_empty():
		selected_entity = entities[0]
	call_deferred("_bind_dependencies")
	set_process(false)

func _exit_tree() -> void:
	if _mode_manager != null and is_instance_valid(_mode_manager):
		_mode_manager.unregister_input_capture(self)

func _bind_dependencies() -> void:
	_mode_manager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	if _mode_manager != null:
		_mode_manager.register_input_capture(self)
	queue_redraw()

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	set_process(enabled)
	visible = enabled
	queue_redraw()

func blocks_gameplay_action(action: StringName) -> bool:
	return action == &"wand_fire" and _interaction_enabled and _creative_entity_editing_enabled()

func set_tool(tool: int) -> void:
	selected_tool = clampi(tool, Tool.SPAWN, Tool.DELETE)
	tool_changed.emit(selected_tool)
	queue_redraw()

func set_selected_entity(definition: CreativeEntityDef) -> void:
	selected_entity = definition
	selected_tool = Tool.SPAWN
	entity_selected.emit(selected_entity)
	tool_changed.emit(selected_tool)
	queue_redraw()

func clear_spawned_entities() -> int:
	var removed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"creative_spawned"):
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		node.queue_free()
		removed += 1
	return removed

func _process(delta: float) -> void:
	_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
	if not _interaction_enabled or not _creative_entity_editing_enabled():
		return
	var mouse_world: Vector2 = get_global_mouse_position().floor()
	if mouse_world != _last_preview_world:
		_last_preview_world = mouse_world
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled or not _creative_entity_editing_enabled():
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var world_position: Vector2 = get_global_mouse_position().floor()
	if selected_tool == Tool.DELETE:
		_delete_at(world_position)
	elif _spawn_cooldown <= 0.0:
		_spawn_at(world_position)
	get_viewport().set_input_as_handled()

func _spawn_at(world_position: Vector2) -> void:
	if selected_entity == null:
		return
	var parent: Node = get_parent()
	if parent == null or parent.is_queued_for_deletion():
		return
	var instance: Node = selected_entity.spawn(parent, world_position)
	if instance != null:
		_spawn_cooldown = maxf(0.05, spawn_cooldown_seconds)
		entity_spawned.emit(instance)

func _delete_at(world_position: Vector2) -> void:
	var world_2d: World2D = get_world_2d()
	if world_2d == null:
		return
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0x7FFFFFFF
	var hits: Array[Dictionary] = world_2d.direct_space_state.intersect_point(query, 32)
	for hit: Dictionary in hits:
		var collider_value: Variant = hit.get("collider", null)
		if not collider_value is Node:
			continue
		var node: Node = collider_value as Node
		if not is_instance_valid(node) or not node.is_in_group(&"creative_deletable"):
			continue
		var deleted_name: String = node.name
		node.queue_free()
		entity_deleted.emit(deleted_name)
		return

func _creative_entity_editing_enabled() -> bool:
	if _mode_manager == null or not is_instance_valid(_mode_manager) or not _mode_manager.is_creative():
		return false
	var rules: GameRules = _mode_manager.active_rules()
	return rules != null and rules.allow_entity_spawning

func _draw() -> void:
	if not _interaction_enabled or not _creative_entity_editing_enabled():
		return
	var center: Vector2 = to_local(_last_preview_world)
	var color: Color = Color(0.38, 0.76, 1.0, 0.95) if selected_tool == Tool.SPAWN else Color(1.0, 0.32, 0.24, 0.95)
	draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), color, false, 1.0)
	draw_line(center - Vector2(3.0, 0.0), center + Vector2(3.0, 0.0), color, 1.0)
	draw_line(center - Vector2(0.0, 3.0), center + Vector2(0.0, 3.0), color, 1.0)
