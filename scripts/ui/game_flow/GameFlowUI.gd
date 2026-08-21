class_name GameFlowUI
extends CanvasLayer

signal quit_intent(player_id: int)

@onready var _start_overlay: Control = %StartOverlay
@onready var _loading_label: Label = %LoadingLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _transition_overlay: Control = %TransitionOverlay
@onready var _end_overlay: Control = %EndOverlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_value: Label = %ResultValue
@onready var _summary_seed: Label = %SummarySeed
@onready var _summary_depth: Label = %SummaryDepth
@onready var _summary_gold: Label = %SummaryGold
@onready var _summary_time: Label = %SummaryTime
@onready var _summary_kills: Label = %SummaryKills
@onready var _summary_wands: Label = %SummaryWands
@onready var _summary_spells: Label = %SummarySpells
@onready var _summary_creative: Label = %SummaryCreative
@onready var _status_label: Label = %StatusLabel
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton

var _game_manager: GameManager = null
var _summary_store: GameSummaryStore = null
var _quit_handler: Callable = Callable()
var _game_state: GameState = null
var _player_state: PlayerState = null
var _pending_intent: bool = false
var _bound_game_id: int = GameManager.INVALID_GAME_ID


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_show_idle()


func setup(
		manager: GameManager,
		summary_store: GameSummaryStore,
		quit_handler: Callable = Callable(),
	) -> bool:
	if _game_manager != null or _summary_store != null:
		return _game_manager == manager and _summary_store == summary_store
	if manager == null or not is_instance_valid(manager):
		return false
	if summary_store == null or not is_instance_valid(summary_store):
		return false

	_game_manager = manager
	_summary_store = summary_store
	_quit_handler = quit_handler
	_connect_framework_signals()

	match manager.lifecycle_state:
		GameManager.LifecycleState.STARTING:
			_on_game_starting(manager.current_game_id)
		GameManager.LifecycleState.ACTIVE:
			_on_game_started(manager.current_game_id)
		GameManager.LifecycleState.STOPPING:
			_on_game_stopping(manager.current_game_id)
		_:
			_show_idle()
	return true


func _exit_tree() -> void:
	_unbind_game_state()
	_disconnect_framework_signals()


func request_restart(options: Dictionary = {}) -> bool:
	if _pending_intent or not _can_submit_end_intent():
		return false
	_set_pending(true, "Restarting…")
	if _game_manager.request_restart(GameManager.LOCAL_PLAYER_ID, options):
		return true
	_set_pending(false, "Restart request rejected")
	return false


func request_quit() -> bool:
	if _pending_intent or not _can_submit_end_intent():
		return false
	_set_pending(true, "Quitting…")
	quit_intent.emit(GameManager.LOCAL_PLAYER_ID)
	if _quit_handler.is_valid():
		var accepted: Variant = _quit_handler.call(GameManager.LOCAL_PLAYER_ID)
		if accepted is bool and bool(accepted):
			return true
		_set_pending(false, "Quit request rejected")
		return false
	# A listener-only shell may consume quit_intent without a direct return path.
	return true


func is_start_overlay_visible() -> bool:
	return _start_overlay.visible


func is_transition_overlay_visible() -> bool:
	return _transition_overlay.visible


func is_end_overlay_visible() -> bool:
	return _end_overlay.visible


func is_pending() -> bool:
	return _pending_intent


func bound_game_id() -> int:
	return _bound_game_id


func displayed_result_title() -> String:
	return _result_title.text


func status_text() -> String:
	return _status_label.text


func _connect_framework_signals() -> void:
	if not _game_manager.game_starting.is_connected(_on_game_starting):
		_game_manager.game_starting.connect(_on_game_starting)
	if not _game_manager.game_started.is_connected(_on_game_started):
		_game_manager.game_started.connect(_on_game_started)
	if not _game_manager.game_stopping.is_connected(_on_game_stopping):
		_game_manager.game_stopping.connect(_on_game_stopping)
	if not _game_manager.game_stopped.is_connected(_on_game_stopped):
		_game_manager.game_stopped.connect(_on_game_stopped)
	if not _summary_store.summary_captured.is_connected(_on_summary_captured):
		_summary_store.summary_captured.connect(_on_summary_captured)
	if not _summary_store.summary_cleared.is_connected(_on_summary_cleared):
		_summary_store.summary_cleared.connect(_on_summary_cleared)


func _disconnect_framework_signals() -> void:
	if _game_manager != null and is_instance_valid(_game_manager):
		if _game_manager.game_starting.is_connected(_on_game_starting):
			_game_manager.game_starting.disconnect(_on_game_starting)
		if _game_manager.game_started.is_connected(_on_game_started):
			_game_manager.game_started.disconnect(_on_game_started)
		if _game_manager.game_stopping.is_connected(_on_game_stopping):
			_game_manager.game_stopping.disconnect(_on_game_stopping)
		if _game_manager.game_stopped.is_connected(_on_game_stopped):
			_game_manager.game_stopped.disconnect(_on_game_stopped)
	if _summary_store != null and is_instance_valid(_summary_store):
		if _summary_store.summary_captured.is_connected(_on_summary_captured):
			_summary_store.summary_captured.disconnect(_on_summary_captured)
		if _summary_store.summary_cleared.is_connected(_on_summary_cleared):
			_summary_store.summary_cleared.disconnect(_on_summary_cleared)


func _on_game_starting(game_id: int) -> void:
	_unbind_game_state()
	_bound_game_id = game_id
	_pending_intent = true
	_restart_button.disabled = true
	_quit_button.disabled = true
	_status_label.text = ""
	_start_overlay.visible = true
	_transition_overlay.visible = false
	_end_overlay.visible = false
	_loading_label.text = "LOADING…"
	_seed_label.text = "Seed: %d" % _current_seed()


func _on_game_started(game_id: int) -> void:
	if _game_manager == null or game_id != _game_manager.current_game_id:
		return
	_bound_game_id = game_id
	_bind_game_state(_game_manager.game_state)
	_bind_player_state(_game_manager.get_player_state(GameManager.LOCAL_PLAYER_ID))
	_pending_intent = false
	_status_label.text = ""
	_render_phase()


func _on_game_stopping(game_id: int) -> void:
	if _bound_game_id != GameManager.INVALID_GAME_ID and game_id != _bound_game_id:
		return
	_unbind_game_state()
	_set_pending(true, "Restarting…" if _end_overlay.visible else "Stopping…")


func _on_game_stopped(_game_id: int) -> void:
	# Keep the captured EndPanel visible until the next game_starting signal.
	if _summary_store != null and _summary_store.current_summary != null:
		_render_summary(_summary_store.current_summary)


func _on_summary_captured(summary: GameSummary) -> void:
	if summary == null or summary.game_id != _bound_game_id:
		return
	_render_summary(summary)


func _on_summary_cleared() -> void:
	if _game_manager != null and _game_manager.lifecycle_state == GameManager.LifecycleState.STARTING:
		_end_overlay.visible = false


func _bind_game_state(state: GameState) -> void:
	if _game_state == state:
		return
	_unbind_game_state()
	if state == null or not is_instance_valid(state):
		return
	_game_state = state
	if not _game_state.phase_changed.is_connected(_on_phase_changed):
		_game_state.phase_changed.connect(_on_phase_changed)
	if not _game_state.result_changed.is_connected(_on_result_changed):
		_game_state.result_changed.connect(_on_result_changed)


func _bind_player_state(state: PlayerState) -> void:
	if _player_state == state:
		return
	if _player_state != null and is_instance_valid(_player_state):
		if _player_state.alive_changed.is_connected(_on_player_alive_changed):
			_player_state.alive_changed.disconnect(_on_player_alive_changed)
	_player_state = state
	if _player_state != null and is_instance_valid(_player_state):
		if not _player_state.alive_changed.is_connected(_on_player_alive_changed):
			_player_state.alive_changed.connect(_on_player_alive_changed)


func _unbind_game_state() -> void:
	if _game_state != null and is_instance_valid(_game_state):
		if _game_state.phase_changed.is_connected(_on_phase_changed):
			_game_state.phase_changed.disconnect(_on_phase_changed)
		if _game_state.result_changed.is_connected(_on_result_changed):
			_game_state.result_changed.disconnect(_on_result_changed)
	_game_state = null
	_bind_player_state(null)


func _on_phase_changed(_previous: GameState.GamePhase, _current: GameState.GamePhase) -> void:
	_render_phase()


func _on_result_changed(_previous: GameState.GameResult, _current: GameState.GameResult) -> void:
	if _game_state != null and _game_state.phase == GameState.GamePhase.ENDED:
		_render_phase()


func _on_player_alive_changed(_previous: bool, _current: bool) -> void:
	# A local player death is presentation data, not a global Game Over condition.
	# Global EndPanel visibility remains driven exclusively by GameState.phase.
	_render_phase()


func _render_phase() -> void:
	if _game_state == null or not is_instance_valid(_game_state):
		return
	match _game_state.phase:
		GameState.GamePhase.STARTING:
			_start_overlay.visible = true
			_transition_overlay.visible = false
			_end_overlay.visible = false
		GameState.GamePhase.PLAYING:
			_start_overlay.visible = false
			_transition_overlay.visible = false
			_end_overlay.visible = false
		GameState.GamePhase.TRANSITION:
			_start_overlay.visible = false
			_transition_overlay.visible = true
			_end_overlay.visible = false
		GameState.GamePhase.ENDED:
			_start_overlay.visible = false
			_transition_overlay.visible = false
			if _summary_store != null and _summary_store.current_summary != null:
				_render_summary(_summary_store.current_summary)
			else:
				_end_overlay.visible = true
				_result_title.text = _result_title_for(_game_state.result)
				_set_pending(false, "Preparing summary…")


func _render_summary(summary: GameSummary) -> void:
	if summary == null:
		return
	_start_overlay.visible = false
	_transition_overlay.visible = false
	_end_overlay.visible = true
	_result_title.text = _result_title_for(summary.result)
	_result_value.text = _result_name(summary.result)
	_summary_seed.text = str(summary.seed)
	_summary_depth.text = str(summary.depth)
	_summary_gold.text = str(summary.gold)
	_summary_time.text = _format_elapsed(summary.elapsed_time)
	_summary_kills.text = str(summary.enemies_killed)
	_summary_wands.text = str(summary.wands_collected)
	_summary_spells.text = str(summary.spells_collected)
	_summary_creative.text = "Yes" if summary.creative_used else "No"
	if not _pending_intent:
		_status_label.text = ""
	_restart_button.disabled = _pending_intent
	_quit_button.disabled = _pending_intent


func _show_idle() -> void:
	_bound_game_id = GameManager.INVALID_GAME_ID
	_pending_intent = false
	_start_overlay.visible = false
	_transition_overlay.visible = false
	_end_overlay.visible = false
	_status_label.text = ""
	_restart_button.disabled = true
	_quit_button.disabled = true


func _set_pending(pending: bool, status: String) -> void:
	_pending_intent = pending
	_status_label.text = status
	_restart_button.disabled = pending
	_quit_button.disabled = pending


func _can_submit_end_intent() -> bool:
	return _game_manager != null and is_instance_valid(_game_manager) \
		and _game_manager.lifecycle_state == GameManager.LifecycleState.ACTIVE \
		and _game_state != null and is_instance_valid(_game_state) \
		and _game_state.phase == GameState.GamePhase.ENDED \
		and _game_manager.has_player(GameManager.LOCAL_PLAYER_ID)


func _current_seed() -> int:
	if _game_manager == null or _game_manager.game_config == null:
		return 0
	return _game_manager.game_config.seed


func _result_title_for(result: int) -> String:
	match result:
		GameState.GameResult.VICTORY:
			return "VICTORY"
		GameState.GameResult.DEFEAT:
			return "DEFEAT"
		GameState.GameResult.ABORTED:
			return "RUN ENDED"
		_:
			return "GAME OVER"


func _result_name(result: int) -> String:
	match result:
		GameState.GameResult.VICTORY:
			return "Victory"
		GameState.GameResult.DEFEAT:
			return "Defeat"
		GameState.GameResult.ABORTED:
			return "Aborted"
		_:
			return "Unknown"


func _format_elapsed(seconds: float) -> String:
	var total_seconds := maxi(0, int(floor(seconds)))
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var secs := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


func _on_restart_pressed() -> void:
	request_restart()


func _on_quit_pressed() -> void:
	request_quit()
