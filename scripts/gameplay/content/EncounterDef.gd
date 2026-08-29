class_name EncounterDef
extends Resource

@export var encounter_id: StringName = &""
@export var display_name: String = ""
@export var allowed_biomes: Array[StringName] = []
@export var required_structure_tags: Array[StringName] = []
@export var forbidden_structure_tags: Array[StringName] = []
@export var min_depth: int = 0
@export var max_depth: int = 999999
@export_range(0.0, 1000.0, 0.05) var weight: float = 1.0
@export_range(0.0, 1000.0, 0.25) var threat_budget_min: float = 0.0
@export_range(0.0, 1000.0, 0.25) var threat_budget_max: float = 999.0
@export var entries: Array[EncounterEntryDef] = []
@export var reward_profile_id: StringName = &""


func is_valid(enemy_catalog: EnemyCatalog) -> bool:
	if encounter_id == &"" or max_depth < min_depth or weight <= 0.0 or entries.is_empty():
		return false
	if threat_budget_max < threat_budget_min:
		return false
	for entry: EncounterEntryDef in entries:
		if entry == null or not entry.is_valid(enemy_catalog):
			return false
	return true
