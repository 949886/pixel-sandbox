class_name EnemyCatalog
extends Resource

@export var enemies: Array[EnemyDef] = []

var _by_id: Dictionary = {}
var _cache_ready := false


func all_enemies() -> Array[EnemyDef]:
	_ensure_cache()
	var result: Array[EnemyDef] = []
	for definition: EnemyDef in enemies:
		if definition != null:
			result.append(definition)
	return result


func get_enemy(enemy_id: StringName) -> EnemyDef:
	_ensure_cache()
	return _by_id.get(enemy_id, null) as EnemyDef


func is_valid() -> bool:
	_ensure_cache()
	return not _by_id.is_empty() and _by_id.size() == _non_null_count()


func invalidate_cache() -> void:
	_cache_ready = false
	_by_id.clear()


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for definition: EnemyDef in enemies:
		if definition == null or not definition.is_valid():
			continue
		if _by_id.has(definition.enemy_id):
			push_error("EnemyCatalog contains duplicate enemy id '%s'." % str(definition.enemy_id))
			continue
		_by_id[definition.enemy_id] = definition
	_cache_ready = true


func _non_null_count() -> int:
	var count := 0
	for definition: EnemyDef in enemies:
		if definition != null:
			count += 1
	return count
