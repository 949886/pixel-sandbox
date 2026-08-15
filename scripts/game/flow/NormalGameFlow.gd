class_name NormalGameFlow
extends GameFlow


func _on_start() -> bool:
	return game_state.phase == GameState.GamePhase.STARTING \
		and game_state.result == GameState.GameResult.NONE


func on_world_ready() -> bool:
	if not _can_apply_flow_rules():
		return false
	if game_state.phase != GameState.GamePhase.STARTING:
		return false
	return transition_phase(GameState.GamePhase.PLAYING)


func on_player_joined(player_state: PlayerState) -> bool:
	if not _can_apply_flow_rules():
		return false
	if game_state.phase == GameState.GamePhase.ENDED:
		return false
	return is_registered_player_state(player_state)


func on_player_died(player_state: PlayerState, _context: Variant = null) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not is_registered_player_state(player_state):
		return false
	if player_state.alive:
		return false
	if game_state.phase not in [GameState.GamePhase.PLAYING, GameState.GamePhase.TRANSITION]:
		return false

	# Creative recovery is an explicit flow rule. Player exposes only the neutral
	# respawn primitive; GameManager owns the authoritative runtime operation.
	if game_state.runtime_mode == GameState.RuntimeMode.CREATIVE:
		return game_manager.recover_player(player_state.player_id)

	if get_alive_player_count() > 0:
		return true
	return end_game(GameState.GameResult.DEFEAT)


func on_boss_defeated(boss_id: StringName) -> bool:
	if not _can_apply_flow_rules():
		return false
	if boss_id == &"":
		return false
	if game_state.phase not in [GameState.GamePhase.PLAYING, GameState.GamePhase.TRANSITION]:
		return false
	return game_state.set_boss_defeated(true)


func on_exit_reached(player_state: PlayerState) -> bool:
	if not _can_apply_flow_rules():
		return false
	if game_state.phase != GameState.GamePhase.PLAYING:
		return false
	if not is_registered_player_state(player_state) or not player_state.alive:
		return false
	if not game_state.boss_defeated:
		return false
	return end_game(GameState.GameResult.VICTORY)


func enter_transition() -> bool:
	return transition_phase(GameState.GamePhase.TRANSITION)


func complete_transition() -> bool:
	return transition_phase(GameState.GamePhase.PLAYING)


func can_transition_phase(current: int, next: int) -> bool:
	if not GameState.GamePhase.values().has(current):
		return false
	if not GameState.GamePhase.values().has(next):
		return false

	match current:
		GameState.GamePhase.STARTING:
			return next == GameState.GamePhase.PLAYING
		GameState.GamePhase.PLAYING:
			return next in [GameState.GamePhase.TRANSITION, GameState.GamePhase.ENDED]
		GameState.GamePhase.TRANSITION:
			return next in [GameState.GamePhase.PLAYING, GameState.GamePhase.ENDED]
		GameState.GamePhase.ENDED:
			return false
	return false


func can_change_runtime_mode(player_state: PlayerState, target_mode: int) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not GameState.RuntimeMode.values().has(target_mode):
		return false
	if not is_registered_player_state(player_state) or not player_state.alive:
		return false
	return game_state.phase == GameState.GamePhase.PLAYING
