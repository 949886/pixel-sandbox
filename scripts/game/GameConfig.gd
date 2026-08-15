class_name GameConfig
extends RefCounted

## Immutable-by-convention creation input for one game runtime.
## Runtime state belongs to GameState / PlayerState, never to this object.

var seed: int = 0
var flow_id: StringName = &"normal"
var starting_loadout: StartingLoadoutDef = null
var player_id: int = 1


func is_valid() -> bool:
	return seed != 0 and flow_id != &"" and player_id > 0


func duplicate_config() -> GameConfig:
	var copy := GameConfig.new()
	copy.seed = seed
	copy.flow_id = flow_id
	copy.starting_loadout = starting_loadout
	copy.player_id = player_id
	return copy
