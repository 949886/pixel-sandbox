class_name GameSummary
extends Node

signal summary_captured(summary: GameSummary)
signal summary_cleared()

var _game_manager: GameManager = null
var _bound_state: GameState = null

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

var creative_used: bool:
	get:
		return _used_creative_mode
	set(_value):
		push_error("GameSummary is read-only.")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_summary")


func setup(manager: GameManager) -> bool:
	if _game_manager != null:
		return _game_manager == manager
	if manager == null or not is_instance_valid(manager):
		return false
	_game_manager = manager
	if not manager.game_starting.is_connected(_on_game_starting):
		manager.game_starting.connect(_on_game_starting)
	if not manager.game_started.is_connected(_on_game_started):
		manager.game_started.connect(_on_game_started)
	if not manager.game_stopping.is_connected(_on_game_stopping):
		manager.game_stopping.connect(_on_game_stopping)
	if manager.lifecycle_state == GameManager.LifecycleState.ACTIVE:
		_bind_state(manager.game_state)
	return true


func _exit_tree() -> void:
	_unbind_state()
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	if _game_manager.game_starting.is_connected(_on_game_starting):
		_game_manager.game_starting.disconnect(_on_game_starting)
	if _game_manager.game_started.is_connected(_on_game_started):
		_game_manager.game_started.disconnect(_on_game_started)
	if _game_manager.game_stopping.is_connected(_on_game_stopping):
		_game_manager.game_stopping.disconnect(_on_game_stopping)


func capture_from_state(state: GameState, current_gold: int = 0) -> bool:
	if state == null or not is_instance_valid(state) or not state.is_initialized():
		return false
	if state.phase != GameState.GamePhase.ENDED:
		return false
	if state.result == GameState.GameResult.NONE:
		return false
	if is_valid() and _game_id == state.game_id:
		return true

	_game_id = state.game_id
	_result = state.result
	_seed = state.game_seed
	_depth = state.current_depth
	_gold = maxi(0, current_gold)
	_elapsed_time = state.elapsed_time
	_enemies_killed = state.statistics.enemies_killed
	_wands_collected = state.statistics.wands_collected
	_spells_collected = state.statistics.spells_collected
	_used_creative_mode = state.used_creative_mode
	if not is_valid():
		_reset_snapshot()
		return false
	summary_captured.emit(self)
	return true


func clear() -> bool:
	var had_summary := _game_id != GameState.INVALID_GAME_ID
	_reset_snapshot()
	if had_summary:
		summary_cleared.emit()
	return had_summary


func is_valid() -> bool:
	return _game_id > GameState.INVALID_GAME_ID \
		and GameState.GameResult.values().has(_result) \
		and _result != GameState.GameResult.NONE \
		and _depth >= 0 \
		and _gold >= 0 \
		and _elapsed_time >= 0.0 \
		and _enemies_killed >= 0 \
		and _wands_collected >= 0 \
		and _spells_collected >= 0


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


func _on_game_starting(_game_id_value: int) -> void:
	_unbind_state()
	clear()


func _on_game_started(game_id_value: int) -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	if game_id_value != _game_manager.current_game_id:
		return
	_bind_state(_game_manager.game_state)
	if _bound_state != null and _bound_state.phase == GameState.GamePhase.ENDED:
		_capture_current_game()


func _on_game_stopping(_game_id_value: int) -> void:
	# Keep the captured scalar fields alive while the per-game runtime is destroyed.
	_unbind_state()


func _bind_state(state: GameState) -> void:
	if _bound_state == state:
		return
	_unbind_state()
	if state == null or not is_instance_valid(state):
		return
	_bound_state = state
	if not _bound_state.phase_changed.is_connected(_on_phase_changed):
		_bound_state.phase_changed.connect(_on_phase_changed)


func _unbind_state() -> void:
	if _bound_state != null and is_instance_valid(_bound_state):
		if _bound_state.phase_changed.is_connected(_on_phase_changed):
			_bound_state.phase_changed.disconnect(_on_phase_changed)
	_bound_state = null


func _on_phase_changed(_previous: GameState.GamePhase, current: GameState.GamePhase) -> void:
	if current == GameState.GamePhase.ENDED:
		_capture_current_game()


func _capture_current_game() -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	if _bound_state == null or not is_instance_valid(_bound_state):
		return
	if _bound_state.game_id != _game_manager.current_game_id:
		return
	if is_valid() and _game_id == _bound_state.game_id:
		return

	var current_gold: int = 0
	var player_runtime := _game_manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID)
	if player_runtime != null:
		current_gold = _read_int_property(player_runtime, &"gold", 0)
	if not capture_from_state(_bound_state, current_gold):
		push_error("GameSummary: Failed to capture final game summary.")


func _reset_snapshot() -> void:
	_game_id = GameState.INVALID_GAME_ID
	_result = GameState.GameResult.NONE
	_seed = 0
	_depth = 0
	_gold = 0
	_elapsed_time = 0.0
	_enemies_killed = 0
	_wands_collected = 0
	_spells_collected = 0
	_used_creative_mode = false


func _read_int_property(source: Object, property_name: StringName, fallback: int) -> int:
	if source == null:
		return fallback
	for property_info: Dictionary in source.get_property_list():
		if StringName(property_info.get("name", &"")) == property_name:
			var value: Variant = source.get(property_name)
			return int(value) if value is int else fallback
	return fallback
