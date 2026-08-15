class_name GameSummary
extends RefCounted

var _game_id: int = GameState.INVALID_GAME_ID
var _result: int = GameState.GameResult.NONE
var _seed: int = 0
var _depth: int = 0
var _gold: int = 0
var _elapsed_time: float = 0.0
var _enemies_killed: int = 0
var _wands_collected: int = 0
var _spells_collected: int = 0
var _used_creative_mode: bool = false

var game_id: int:
	get:
		return _game_id
	set(_value):
		push_error("GameSummary is read-only.")

var result: int:
	get:
		return _result
	set(_value):
		push_error("GameSummary is read-only.")

var seed: int:
	get:
		return _seed
	set(_value):
		push_error("GameSummary is read-only.")

var depth: int:
	get:
		return _depth
	set(_value):
		push_error("GameSummary is read-only.")

var gold: int:
	get:
		return _gold
	set(_value):
		push_error("GameSummary is read-only.")

var elapsed_time: float:
	get:
		return _elapsed_time
	set(_value):
		push_error("GameSummary is read-only.")

var enemies_killed: int:
	get:
		return _enemies_killed
	set(_value):
		push_error("GameSummary is read-only.")

var wands_collected: int:
	get:
		return _wands_collected
	set(_value):
		push_error("GameSummary is read-only.")

var spells_collected: int:
	get:
		return _spells_collected
	set(_value):
		push_error("GameSummary is read-only.")

var used_creative_mode: bool:
	get:
		return _used_creative_mode
	set(_value):
		push_error("GameSummary is read-only.")


static func from_game_state(state: GameState, current_gold: int = 0) -> GameSummary:
	if state == null or not is_instance_valid(state) or not state.is_initialized():
		return null

	var summary := GameSummary.new()
	summary._game_id = state.game_id
	summary._result = state.result
	summary._seed = state.game_seed
	summary._depth = state.current_depth
	summary._gold = current_gold if current_gold > 0 else 0
	summary._elapsed_time = state.elapsed_time
	summary._enemies_killed = state.statistics.enemies_killed
	summary._wands_collected = state.statistics.wands_collected
	summary._spells_collected = state.statistics.spells_collected
	summary._used_creative_mode = state.used_creative_mode
	return summary


func to_dictionary() -> Dictionary:
	return {
		"game_id": _game_id,
		"result": _result,
		"seed": _seed,
		"depth": _depth,
		"gold": _gold,
		"elapsed_time": _elapsed_time,
		"enemies_killed": _enemies_killed,
		"wands_collected": _wands_collected,
		"spells_collected": _spells_collected,
		"used_creative_mode": _used_creative_mode,
	}
