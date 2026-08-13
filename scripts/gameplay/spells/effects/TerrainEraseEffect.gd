class_name TerrainEraseEffect
extends GameplayEffect

@export var radius: float = 3.0

func execute(context: CastContext) -> void:
	if context == null or context.world_interface == null or not context.world_interface.has_method("erase_material_circle"):
		return
	var resolved_radius := maxf(0.0, radius + (context.cast_state.radius_add if context.cast_state != null else 0.0))
	if resolved_radius > 0.0:
		context.world_interface.call("erase_material_circle", context.hit_position, resolved_radius)
