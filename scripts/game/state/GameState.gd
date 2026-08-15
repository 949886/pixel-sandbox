class_name GameState
extends Node

signal phase_changed(previous: GamePhase, current: GamePhase)
signal result_changed(previous: GameResult, current: GameResult)
signal runtime_mode_changed(previous: RuntimeMode, current: RuntimeMode)
signal creative_usage_changed(used_creative_mode: bool)
signal depth_changed(depth: int)
signal biome_changed(biome: StringName)

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
const DEFAULT_BIOME: StringName = &"mine"

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
var _statistics: GameStatistics = GameStatistics.new()

var game_id: int:
	get:
		return _game_id
	set(_value):
		push_error("GameState.game_id is read-only after initialize().")

var game_seed: int:
	get:
		return _game_seed
	set(_value):
		push_error("GameState.game_seed is read-only after initialize().")

var phase: GamePhase:
	get:
		return _phase
	set(_value):
		push_error("GameState.phase is read-only; use set_phase().")

var result: GameResult:
	get:
		return _result
	set(_value):
		push_error("GameState.result is read-only; use set_result().")

var runtime_mode: RuntimeMode:
	get:
		return _runtime_mode
	set(_value):
		push_error("GameState.runtime_mode is read-only; use set_runtime_mode().")

var used_creative_mode: bool:
	get:
		return _used_creative_mode
	set(_value):
		push_error("GameState.used_creative_mode is managed by set_runtime_mode().")

var current_depth: int:
	get:
		return _current_depth
	set(_value):
		push_error("GameState.current_depth is read-only; use set_depth().")

var current_biome: StringName:
	get:
		return _current_biome
	set(_value):
		push_error("GameState.current_biome is read-only; use set_biome().")

var elapsed_time: float:
	get:
		return _elapsed_time
	set(_value):
		push_error("GameState.elapsed_time is read-only; use set_elapsed_time() or advance_elapsed_time().")

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

	if next_mode == RuntimeMode.CREATIVE and not _used_creative_mode:
		_used_creative_mode = true
		creative_usage_changed.emit(true)

	if _runtime_mode == next_mode:
		return true

	var previous: RuntimeMode = _runtime_mode
	_runtime_mode = next_mode
	runtime_mode_changed.emit(previous, _runtime_mode)
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
		"statistics": _statistics.to_dictionary(),
	}
