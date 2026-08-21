class_name GameSummaryStore
extends Node

signal summary_captured(summary: GameSummary)
signal summary_cleared()

var _game_manager: GameManager = null
var _bound_state: GameState = null
var _current_summary: GameSummary = null

var current_summary: GameSummary:
	get:
		return _current_summary
	set(_value):
		push_error("GameSummaryStore.current_summary is read-only.")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_summary_store")


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


func _on_game_starting(_game_id: int) -> void:
	_unbind_state()
	if _current_summary != null:
		_current_summary = null
		summary_cleared.emit()


func _on_game_started(game_id: int) -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	if game_id != _game_manager.current_game_id:
		return
	_bind_state(_game_manager.game_state)
	if _bound_state != null and _bound_state.phase == GameState.GamePhase.ENDED:
		_capture_summary()


func _on_game_stopping(_game_id: int) -> void:
	# Keep the immutable summary alive while the per-game runtime is destroyed.
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
		_capture_summary()


func _capture_summary() -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	if _bound_state == null or not is_instance_valid(_bound_state):
		return
	if _bound_state.game_id != _game_manager.current_game_id:
		return
	if _current_summary != null and _current_summary.game_id == _bound_state.game_id:
		return

	var player_data: Dictionary = {}
	var player_runtime := _game_manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID)
	if player_runtime != null:
		player_data["gold"] = _read_int_property(player_runtime, &"gold", 0)

	var summary := GameSummary.create_from_state(_bound_state, player_data)
	if summary == null or not summary.is_valid():
		push_error("GameSummaryStore: Failed to capture final GameSummary.")
		return
	_current_summary = summary
	summary_captured.emit(_current_summary)


func _read_int_property(source: Object, property_name: StringName, fallback: int) -> int:
	if source == null:
		return fallback
	for property_info: Dictionary in source.get_property_list():
		if StringName(property_info.get("name", &"")) == property_name:
			var value: Variant = source.get(property_name)
			return int(value) if value is int else fallback
	return fallback
