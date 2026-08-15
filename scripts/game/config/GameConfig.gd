class_name GameConfig
extends RefCounted

var seed: int = 0
var flow_id: StringName = &"normal"
var starting_loadout: StartingLoadoutDef = null


static func create(
		seed_value: int,
		loadout: StartingLoadoutDef,
		requested_flow_id: StringName = &"normal",
	) -> GameConfig:
	var config := GameConfig.new()
	config.seed = seed_value
	config.flow_id = requested_flow_id
	config.starting_loadout = loadout
	return config


static func create_default(
		loadout: StartingLoadoutDef,
		requested_flow_id: StringName = &"normal",
	) -> GameConfig:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return create(int(rng.randi()), loadout, requested_flow_id)


func is_valid() -> bool:
	if flow_id == &"":
		return false
	if starting_loadout == null or not starting_loadout.is_valid():
		return false
	return true
