class_name CreativeEntityCatalog
extends Resource

@export var entities: Array[CreativeEntityDef] = []

var _by_id: Dictionary = {}
var _cache_ready: bool = false


func all_entities() -> Array[CreativeEntityDef]:
	_ensure_cache()
	var result: Array[CreativeEntityDef] = []
	for definition: CreativeEntityDef in entities:
		if definition != null:
			result.append(definition)
	return result


func get_entity(entity_id: StringName) -> CreativeEntityDef:
	_ensure_cache()
	return _by_id.get(entity_id, null) as CreativeEntityDef


func is_valid() -> bool:
	_ensure_cache()
	return not _by_id.is_empty() and _by_id.size() == _non_null_entity_count()


func invalidate_cache() -> void:
	_cache_ready = false
	_by_id.clear()


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for definition: CreativeEntityDef in entities:
		if definition == null:
			continue
		if definition.entity_id == &"" or definition.scene == null:
			push_error("CreativeEntityCatalog contains an invalid entity definition.")
			continue
		if _by_id.has(definition.entity_id):
			push_error("CreativeEntityCatalog contains duplicate entity id '%s'." % str(definition.entity_id))
			continue
		_by_id[definition.entity_id] = definition
	_cache_ready = true


func _non_null_entity_count() -> int:
	var count: int = 0
	for definition: CreativeEntityDef in entities:
		if definition != null:
			count += 1
	return count
