class_name RadialProjectileEffect
extends GameplayEffect

@export var projectile_def: ProjectileDef
@export_range(1, 24, 1) var count: int = 6
@export var start_angle_degrees: float = 0.0
@export var arc_degrees: float = 360.0

func execute(context: CastContext) -> void:
	if context == null or projectile_def == null or count <= 0:
		return
	var parent := context.projectile_parent
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	for index: int in range(count):
		var divisor := float(maxi(1, count))
		var angle := deg_to_rad(start_angle_degrees + (float(index) / divisor) * arc_degrees)
		var direction := Vector2.from_angle(angle)
		var child_context := CastContext.create(context.caster, context.source, context.projectile_parent, context.world_interface, context.hit_position, direction)
		child_context.rng = context.rng
		child_context.cast_state = context.cast_state
		var projectile := GameplayProjectile.new()
		parent.add_child(projectile)
		projectile.global_position = context.hit_position.floor()
		projectile.setup_from_def(projectile_def, child_context, direction)
