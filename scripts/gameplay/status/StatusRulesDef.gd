class_name StatusRulesDef
extends Resource

@export_group("Memory")
@export var wet_memory_seconds: float = 0.8
@export var oil_memory_seconds: float = 4.0
@export var base_burning_seconds: float = 3.0

@export_group("Environment")
@export var environment_ignite_seconds: float = 0.75
@export var wet_extinguish_rate_multiplier: float = 4.0
@export var wet_ignite_block_threshold: float = 0.15
@export var wet_burning_cap_seconds: float = 0.25
@export var oiled_burn_duration_multiplier: float = 1.75
@export var oiled_burn_damage_multiplier: float = 1.35

@export_group("Damage")
@export var burning_damage_per_second: float = 7.0
@export var fire_contact_damage_per_second: float = 5.0
@export var lava_contact_damage_per_second: float = 24.0
@export var toxic_contact_damage_per_second: float = 10.0
@export var damage_tick_interval: float = 0.25
