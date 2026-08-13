class_name ProjectileEffect
extends GameplayEffect

@export var projectile_def: ProjectileDef
@export_range(1, 16, 1) var projectile_count: int = 1
@export var additional_spread_degrees: float = 0.0

func execute(context: CastContext) -> void:
	if context == null or projectile_def == null:
		return
	var parent := context.projectile_parent
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var rng := context.rng if context.rng != null else RandomNumberGenerator.new()
	if context.rng == null:
		rng.randomize()
	for _index: int in range(projectile_count):
		var spread := deg_to_rad(rng.randf_range(-additional_spread_degrees, additional_spread_degrees))
		var projectile := GameplayProjectile.new()
		parent.add_child(projectile)
		projectile.global_position = context.origin.floor()
		var shot_direction := context.direction.rotated(spread)
		if shot_direction.length_squared() <= 0.0001:
			shot_direction = Vector2.RIGHT
		projectile.setup_from_def(projectile_def, context, shot_direction)
