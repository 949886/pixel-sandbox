class_name EncounterEntryDef
extends Resource

@export var enemy_id: StringName = &""
@export_range(1, 64, 1) var count_min: int = 1
@export_range(1, 64, 1) var count_max: int = 1
@export_range(0.0, 100.0, 0.05) var weight: float = 1.0
@export var required_anchor_tags: Array[StringName] = []


func is_valid(enemy_catalog: EnemyCatalog) -> bool:
	return enemy_id != &"" \
		and count_min > 0 \
		and count_max >= count_min \
		and weight > 0.0 \
		and enemy_catalog != null \
		and enemy_catalog.get_enemy(enemy_id) != null
