class_name WandGenerationProfile
extends Resource

## Authored bounds for future random wand generation. The generator should only
## interpret this profile; biome/rarity-specific values must not live in code.
@export var profile_id: StringName = &""
@export var display_name: String = ""
@export var allowed_biomes: Array[StringName] = []
@export var min_depth: int = 0
@export var max_depth: int = 999999
@export_range(0.0, 1000.0, 0.25) var power_budget_min: float = 0.0
@export_range(0.0, 1000.0, 0.25) var power_budget_max: float = 100.0
@export var mana_min: float = 50.0
@export var mana_max: float = 250.0
@export var mana_recharge_min: float = 10.0
@export var mana_recharge_max: float = 100.0
@export var cast_delay_min: float = 0.05
@export var cast_delay_max: float = 0.5
@export var recharge_time_min: float = 0.15
@export var recharge_time_max: float = 1.2
@export_range(1, 32, 1) var capacity_min: int = 2
@export_range(1, 32, 1) var capacity_max: int = 8
@export_range(0.0, 1.0, 0.01) var shuffle_probability: float = 0.45
@export var spread_min: float = -5.0
@export var spread_max: float = 12.0
@export_range(0, 99, 1) var maximum_spell_tier: int = 3
@export_range(0, 32, 1) var starting_spell_count_min: int = 1
@export_range(0, 32, 1) var starting_spell_count_max: int = 4
@export var required_spell_tags: Array[StringName] = []
@export var excluded_spell_tags: Array[StringName] = []


func is_valid() -> bool:
	return profile_id != &"" \
		and max_depth >= min_depth \
		and power_budget_max >= power_budget_min \
		and mana_max >= mana_min \
		and mana_recharge_max >= mana_recharge_min \
		and cast_delay_max >= cast_delay_min \
		and recharge_time_max >= recharge_time_min \
		and capacity_max >= capacity_min \
		and spread_max >= spread_min \
		and starting_spell_count_max >= starting_spell_count_min
