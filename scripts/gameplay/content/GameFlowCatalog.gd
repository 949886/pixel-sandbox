class_name GameFlowCatalog
extends Resource

@export var flows: Array[GameFlowDef] = []

var _by_id: Dictionary = {}
var _cache_ready: bool = false


func all_flows() -> Array[GameFlowDef]:
	_ensure_cache()
	var result: Array[GameFlowDef] = []
	for definition: GameFlowDef in flows:
		if definition != null:
			result.append(definition)
	return result


func get_flow(flow_id: StringName) -> GameFlowDef:
	_ensure_cache()
	return _by_id.get(flow_id, null) as GameFlowDef


func instantiate_flow(flow_id: StringName) -> GameFlow:
	var definition := get_flow(flow_id)
	return definition.instantiate_flow() if definition != null else null


func is_valid() -> bool:
	_ensure_cache()
	return not _by_id.is_empty() and _by_id.size() == _non_null_flow_count()


func invalidate_cache() -> void:
	_cache_ready = false
	_by_id.clear()


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for definition: GameFlowDef in flows:
		if definition == null:
			continue
		if not definition.is_valid():
			push_error("GameFlowCatalog contains an invalid flow definition.")
			continue
		if _by_id.has(definition.flow_id):
			push_error("GameFlowCatalog contains duplicate flow id '%s'." % str(definition.flow_id))
			continue
		_by_id[definition.flow_id] = definition
	_cache_ready = true


func _non_null_flow_count() -> int:
	var count: int = 0
	for definition: GameFlowDef in flows:
		if definition != null:
			count += 1
	return count
