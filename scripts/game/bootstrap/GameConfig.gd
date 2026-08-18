class_name GameConfig
extends RefCounted

const DEFAULT_FLOW_ID: StringName = &"normal"

var _seed: int = 0
var _flow_id: StringName = DEFAULT_FLOW_ID
var _starting_loadout: StartingLoadoutDef = null

var seed: int:
	get:
		return _seed
	set(_value):
		push_error("GameConfig.seed is resolved once and cannot be reassigned.")

var flow_id: StringName:
	get:
		return _flow_id
	set(_value):
		push_error("GameConfig.flow_id is resolved once and cannot be reassigned.")

var starting_loadout: StartingLoadoutDef:
	get:
		return _starting_loadout
	set(_value):
		push_error("GameConfig.starting_loadout is resolved once and cannot be reassigned.")


func _init(
		seed_value: int,
		flow_id_value: StringName = DEFAULT_FLOW_ID,
		loadout: StartingLoadoutDef = null,
	) -> void:
	_seed = seed_value
	_flow_id = flow_id_value
	_starting_loadout = loadout


static func create_default(
		flow_id_value: StringName = DEFAULT_FLOW_ID,
		loadout: StartingLoadoutDef = null,
	) -> GameConfig:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return GameConfig.new(int(rng.randi()), flow_id_value, loadout)


static func create_with_seed(
		seed_value: int,
		flow_id_value: StringName = DEFAULT_FLOW_ID,
		loadout: StartingLoadoutDef = null,
	) -> GameConfig:
	# Zero is a valid deterministic seed. Explicit seeds are never interpreted as
	# a request to randomize again downstream.
	return GameConfig.new(seed_value, flow_id_value, loadout)


func is_valid() -> bool:
	if _flow_id == &"":
		return false
	return _starting_loadout == null or _starting_loadout.is_valid()


func has_valid_starting_loadout() -> bool:
	return _starting_loadout != null and _starting_loadout.is_valid()
