class_name SpawnSpecialRuntimeEffect
extends GameplayEffect

@export_enum("Black Hole", "Death Cross", "Dragon Breath", "Chainsaw", "Glue Field") var mode: int = SpecialSpellRuntime.Mode.BLACK_HOLE
@export var spawn_at_hit_position: bool = false
@export var duration: float = 2.0
@export var radius: float = 40.0
@export var damage_per_second: float = 10.0
@export var move_speed: float = 0.0
@export var pull_force: float = 0.0
@export var terrain_radius: float = 0.0
@export_range(-1, 4096, 1) var material_element_id: int = -1
@export_range(0.05, 1.0, 0.05) var slow_factor: float = 0.35
@export var status_duration: float = 0.5
@export var primary_color := Color(0.7, 0.3, 1.0, 1.0)
@export var secondary_color := Color(0.2, 0.8, 1.0, 1.0)

func execute(context: CastContext) -> void:
	if context == null:
		return
	var parent := context.projectile_parent
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var runtime := SpecialSpellRuntime.new()
	parent.add_child(runtime)
	runtime.global_position = (context.hit_position if spawn_at_hit_position else context.origin).round()
	runtime.setup(
		mode, context, duration, radius, damage_per_second, move_speed, pull_force,
		terrain_radius, material_element_id, primary_color, secondary_color,
		slow_factor, status_duration,
	)
