class_name WorldGameplayService
extends Node

## Stable gameplay-facing facade over the streaming pixel world. Gameplay code
## should not need to know about chunks, native grids, dirty sectors or collision
## revision internals.
var world_manager: Node

func _ready() -> void:
	world_manager = get_parent()

func is_world_position_loaded(world_position: Vector2) -> bool:
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("is_world_position_loaded"):
		return bool(world_manager.call("is_world_position_loaded", world_position))
	return false

func get_element_id_at_world_position(world_position: Vector2) -> int:
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("get_element_id_at_world_position"):
		return int(world_manager.call("get_element_id_at_world_position", world_position))
	return 0

func get_material_entry_at_world_position(world_position: Vector2) -> MaterialEntry:
	if world_manager == null or not is_instance_valid(world_manager):
		return null
	var element_id := get_element_id_at_world_position(world_position)
	var palette: MaterialPalette = world_manager.get("material_palette") as MaterialPalette
	if palette == null:
		return null
	return palette.entry_for_element_id(element_id)

func is_liquid_at_world_position(world_position: Vector2) -> bool:
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("is_liquid_at_world_position"):
		return bool(world_manager.call("is_liquid_at_world_position", world_position))
	return false

func erase_material_circle(world_center: Vector2, radius: float) -> int:
	if radius <= 0.0:
		return 0
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("erase_material_circle"):
		return int(world_manager.call("erase_material_circle", world_center, radius))
	return 0

func set_element_id_at_world_position(world_position: Vector2, element_id: int) -> bool:
	if element_id < 0:
		return false
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("set_element_id_at_world_position"):
		return bool(world_manager.call("set_element_id_at_world_position", world_position, element_id))
	return false

func paint_material_circle(world_center: Vector2, radius: float, element_id: int, only_replace_air: bool = true) -> int:
	if radius <= 0.0 or element_id < 0:
		return 0
	if world_manager != null and is_instance_valid(world_manager) and world_manager.has_method("paint_material_circle"):
		return int(world_manager.call("paint_material_circle", world_center, radius, element_id, only_replace_air))
	return 0
