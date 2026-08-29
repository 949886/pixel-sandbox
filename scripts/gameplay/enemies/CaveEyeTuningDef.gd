class_name CaveEyeTuningDef
extends Resource

@export_category("Movement")
@export var move_speed: float = 72.0
@export var acceleration: float = 240.0
@export var detection_range: float = 360.0
@export var preferred_distance: float = 145.0
@export var preferred_distance_dead_zone: float = 22.0
@export var retreat_speed_scale: float = 0.8
@export var hover_frequency: float = 2.1
@export var hover_vertical_speed: float = 20.0
@export var idle_horizontal_speed: float = 24.0
@export var idle_horizontal_frequency_scale: float = 0.55
@export var idle_vertical_speed: float = 12.0

@export_category("Attack")
@export var attack_range: float = 285.0
@export var shots_per_second: float = 0.85
@export var projectile_spawn_offset: float = 10.0
@export var projectile_def: ProjectileDef

@export_category("Rewards")
@export var loot_table: LootTableDef

@export_category("Presentation")
@export var body_radius: float = 9.0
@export var eye_radius: float = 6.0
@export var pupil_radius: float = 3.0
@export var highlight_radius: float = 1.0
@export var body_color: Color = Color(0.35, 0.08, 0.14, 1.0)
@export var eye_color: Color = Color(0.94, 0.72, 0.68, 1.0)
@export var pupil_color: Color = Color(0.12, 0.03, 0.05, 1.0)
@export var highlight_color: Color = Color.WHITE
@export var health_bar_background: Color = Color(0.12, 0.12, 0.12, 0.9)
@export var health_bar_foreground: Color = Color(0.9, 0.2, 0.25, 1.0)


func is_valid() -> bool:
	return move_speed > 0.0 \
		and acceleration > 0.0 \
		and detection_range > 0.0 \
		and preferred_distance >= 0.0 \
		and attack_range > 0.0 \
		and shots_per_second > 0.0 \
		and projectile_def != null \
		and loot_table != null \
		and loot_table.is_valid()
