class_name SpawnMaterialEffect
extends GameplayEffect

@export_range(-1, 4096, 1) var element_id: int = -1
@export var radius: float = 2.5
@export var only_replace_air: bool = true

func execute(context: CastContext) -> void:
	if element_id < 0 or context == null or context.world_interface == null:
		return
	var resolved_radius := maxf(0.0, radius + (context.cast_state.radius_add if context.cast_state != null else 0.0))
	if resolved_radius <= 0.0:
		return
	if context.world_interface.has_method("paint_material_circle"):
		context.world_interface.call("paint_material_circle", context.hit_position, resolved_radius, element_id, only_replace_air)
