class_name EncounterCatalog
extends Resource

@export var encounters: Array[EncounterDef] = []

var _by_id: Dictionary = {}
var _cache_ready := false


func get_encounter(encounter_id: StringName) -> EncounterDef:
	_ensure_cache()
	return _by_id.get(encounter_id, null) as EncounterDef


func all_encounters() -> Array[EncounterDef]:
	_ensure_cache()
	var result: Array[EncounterDef] = []
	for definition: EncounterDef in encounters:
		if definition != null:
			result.append(definition)
	return result


func is_valid(enemy_catalog: EnemyCatalog) -> bool:
	_ensure_cache()
	if _by_id.size() != _non_null_count():
		return false
	for definition: EncounterDef in encounters:
		if definition != null and not definition.is_valid(enemy_catalog):
			return false
	return true


func invalidate_cache() -> void:
	_cache_ready = false
	_by_id.clear()


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for definition: EncounterDef in encounters:
		if definition == null or definition.encounter_id == &"":
			continue
		if _by_id.has(definition.encounter_id):
			push_error("EncounterCatalog contains duplicate encounter id '%s'." % str(definition.encounter_id))
			continue
		_by_id[definition.encounter_id] = definition
	_cache_ready = true


func _non_null_count() -> int:
	var count := 0
	for definition: EncounterDef in encounters:
		if definition != null:
			count += 1
	return count
