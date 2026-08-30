class_name GameState
extends Node

signal phase_changed(previous: GamePhase, current: GamePhase)
signal result_changed(previous: GameResult, current: GameResult)
signal runtime_mode_changed(previous: RuntimeMode, current: RuntimeMode)
signal creative_usage_changed(used_creative_mode: bool)
signal depth_changed(depth: int)
signal biome_changed(biome: StringName)
signal boss_defeated_changed(defeated: bool)

enum GamePhase {
	STARTING,
	PLAYING,
	TRANSITION,
	ENDED,
}

enum GameResult {
	NONE,
	VICTORY,
	DEFEAT,
	ABORTED,
}

enum RuntimeMode {
	NORMAL,
	CREATIVE,
}

const INVALID_GAME_ID: int = 0
const DEFAULT_BIOME: StringName = &""

var _initialized: bool = false
var _game_id: int = INVALID_GAME_ID
var _game_seed: int = 0
var _phase: GamePhase = GamePhase.STARTING
var _result: GameResult = GameResult.NONE
var _runtime_mode: RuntimeMode = RuntimeMode.NORMAL
var _used_creative_mode: bool = false
var _current_depth: int = 0
var _current_biome: StringName = DEFAULT_BIOME
var _elapsed_time: float = 0.0
var _boss_defeated: bool = false
var _statistics: GameStatistics = null

var game_id: int:
	get:
		return _game_id
	set(_value):
		push_error("GameState.game_id is initialized once and cannot be reassigned.")

var game_seed: int:
	get:
		return _game_seed
	set(_value):
		push_error("GameState.game_seed is initialized once and cannot be reassigned.")

var phase: GamePhase:
	get:
		return _phase
	set(value):
		set_phase(value)

var result: GameResult:
	get:
		return _result
	set(value):
		set_result(value)

var runtime_mode: RuntimeMode:
	get:
		return _runtime_mode
	set(value):
		set_runtime_mode(value)

var used_creative_mode: bool:
	get:
		return _used_creative_mode
	set(value):
		if value:
			mark_creative_used()

var current_depth: int:
	get:
		return _current_depth
	set(value):
		set_depth(value)

var current_biome: StringName:
	get:
		return _current_biome
	set(value):
		set_biome(value)

var elapsed_time: float:
	get:
		return _elapsed_time
	set(value):
		set_elapsed_time(value)

var boss_defeated: bool:
	get:
		return _boss_defeated
	set(value):
		set_boss_defeated(value)

var statistics: GameStatistics:
	get:
		return _statistics
	set(_value):
		push_error("GameState.statistics is owned by GameState and cannot be replaced.")


func initialize(game_id_value: int, game_seed_value: int = 0) -> bool:
	if _initialized:
		return false
	if game_id_value <= INVALID_GAME_ID:
		return false

	_game_id = game_id_value
	_game_seed = game_seed_value
	_statistics = GameStatistics.new()
	_statistics.name = "GameStatistics"
	add_child(_statistics)
	_initialized = true
	return true


func is_initialized() -> bool:
	return _initialized


func set_phase(next_phase: GamePhase) -> bool:
	if not _initialized:
		return false
	if not GamePhase.values().has(next_phase):
		return false
	if _phase == next_phase:
		return true

	var previous: GamePhase = _phase
	_phase = next_phase
	phase_changed.emit(previous, _phase)
	return true


func set_result(next_result: GameResult) -> bool:
	if not _initialized:
		return false
	if not GameResult.values().has(next_result):
		return false
	if _result == next_result:
		return true

	var previous: GameResult = _result
	_result = next_result
	result_changed.emit(previous, _result)
	return true


func set_runtime_mode(next_mode: RuntimeMode) -> bool:
	if not _initialized:
		return false
	if not RuntimeMode.values().has(next_mode):
		return false

	if next_mode == RuntimeMode.CREATIVE:
		mark_creative_used()

	if _runtime_mode == next_mode:
		return true

	var previous: RuntimeMode = _runtime_mode
	_runtime_mode = next_mode
	runtime_mode_changed.emit(previous, _runtime_mode)
	return true


func mark_creative_used() -> bool:
	if not _initialized:
		return false
	if _used_creative_mode:
		return true
	_used_creative_mode = true
	creative_usage_changed.emit(true)
	return true


func set_depth(depth: int) -> bool:
	if not _initialized or depth < 0:
		return false
	if _current_depth == depth:
		return true

	_current_depth = depth
	depth_changed.emit(_current_depth)
	return true


func set_biome(biome: StringName) -> bool:
	if not _initialized:
		return false
	if _current_biome == biome:
		return true

	_current_biome = biome
	biome_changed.emit(_current_biome)
	return true


func set_elapsed_time(seconds: float) -> bool:
	if not _initialized or seconds < 0.0:
		return false
	_elapsed_time = seconds
	return true


func advance_elapsed_time(delta: float) -> bool:
	if not _initialized or delta < 0.0:
		return false
	_elapsed_time += delta
	return true


func set_boss_defeated(defeated: bool) -> bool:
	if not _initialized:
		return false
	if _boss_defeated == defeated:
		return true
	_boss_defeated = defeated
	boss_defeated_changed.emit(_boss_defeated)
	return true


func to_dictionary() -> Dictionary:
	return {
		"game_id": _game_id,
		"game_seed": _game_seed,
		"phase": _phase,
		"result": _result,
		"runtime_mode": _runtime_mode,
		"used_creative_mode": _used_creative_mode,
		"current_depth": _current_depth,
		"current_biome": _current_biome,
		"elapsed_time": _elapsed_time,
		"boss_defeated": _boss_defeated,
		"statistics": _statistics.to_dictionary() if _statistics != null else {},
	}
