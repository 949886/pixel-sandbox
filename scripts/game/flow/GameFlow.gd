class_name GameFlow
extends Node

var game_manager: GameManager = null
var game_state: GameState = null

var _setup_complete: bool = false
var _started: bool = false


func setup(manager: GameManager, state: GameState) -> bool:
	if _setup_complete:
		return game_manager == manager and game_state == state
	if manager == null or not is_instance_valid(manager):
		return false
	if state == null or not is_instance_valid(state) or not state.is_initialized():
		return false
	if manager.game_state != state:
		return false

	game_manager = manager
	game_state = state
	_setup_complete = true
	return true


func is_setup() -> bool:
	return _setup_complete


func is_started() -> bool:
	return _started


func start() -> bool:
	if not _setup_complete or _started:
		return false
	if not _on_start():
		return false
	_started = true
	return true


func on_gameplay_ready() -> bool:
	return false


func on_player_joined(_player_state: PlayerState) -> bool:
	return false


func on_player_died(_player_state: PlayerState, _context: Variant = null) -> bool:
	return false


func on_boss_defeated(_boss_id: StringName) -> bool:
	return false


func on_exit_reached(_player_state: PlayerState) -> bool:
	return false


func can_recover_player(_player_state: PlayerState, _options: Dictionary = {}) -> bool:
	return false


func can_change_runtime_mode(_player_state: PlayerState, _target_mode: int) -> bool:
	return false


func can_transition_phase(_current: int, _next: int) -> bool:
	return false


func transition_phase(next_phase: int) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not GameState.GamePhase.values().has(next_phase):
		return false
	if next_phase == GameState.GamePhase.ENDED:
		# Game termination must always carry an explicit GameResult.
		return false
	if game_state.phase == next_phase:
		return true
	if not can_transition_phase(game_state.phase, next_phase):
		return false
	return game_state.set_phase(next_phase)


func end_game(result: int) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not GameState.GameResult.values().has(result):
		return false
	if result == GameState.GameResult.NONE:
		return false
	if game_state.phase == GameState.GamePhase.ENDED:
		return game_state.result == result
	if not can_transition_phase(game_state.phase, GameState.GamePhase.ENDED):
		return false

	var previous_result: int = game_state.result
	if not game_state.set_result(result):
		return false
	if game_state.set_phase(GameState.GamePhase.ENDED):
		return true

	# Keep state coherent if a future GameState implementation rejects the
	# phase write after the flow already validated it.
	game_state.set_result(previous_result)
	return false


func is_registered_player_state(player_state: PlayerState) -> bool:
	if not _setup_complete:
		return false
	if player_state == null or not is_instance_valid(player_state):
		return false
	if not player_state.is_initialized():
		return false
	return game_manager.get_player_state(player_state.player_id) == player_state


func get_alive_player_count() -> int:
	if not _setup_complete:
		return 0
	var alive_count: int = 0
	for player_state: PlayerState in game_manager.get_player_states():
		if player_state.alive:
			alive_count += 1
	return alive_count


func _on_start() -> bool:
	return true


func _can_apply_flow_rules() -> bool:
	if not _setup_complete or not _started:
		return false
	if game_manager == null or not is_instance_valid(game_manager):
		return false
	if game_state == null or not is_instance_valid(game_state):
		return false
	return game_manager.is_game_authority()
