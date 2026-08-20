class_name NormalGameFlow
extends GameFlow


func _on_start() -> bool:
	return game_state.phase == GameState.GamePhase.STARTING \
		and game_state.result == GameState.GameResult.NONE


func on_gameplay_ready() -> bool:
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


func on_player_died(player_state: PlayerState, context: Variant = null) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not is_registered_player_state(player_state):
		return false
	if player_state.alive:
		# GameManager updates the public PlayerState fact before asking the flow
		# to evaluate the death policy.
		return false
	if game_state.phase not in [GameState.GamePhase.PLAYING, GameState.GamePhase.TRANSITION]:
		return false

	if game_state.runtime_mode == GameState.RuntimeMode.CREATIVE:
		# Creative recovery remains an explicit flow decision. The runtime
		# operation itself is executed by GameManager against the registered
		# Player runtime, so Player never owns an autonomous respawn rule.
		if game_manager.request_player_recovery(
				player_state.player_id,
				{
					"reason": &"creative_death",
					"death_context": context,
				},
			):
			return true

		# A failed recovery must not leave a game permanently PLAYING with no
		# living players. Multiplayer can still continue while another player
		# remains alive.
		if get_alive_player_count() > 0:
			return true
		return end_game(GameState.GameResult.DEFEAT)

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


func can_recover_player(player_state: PlayerState, _options: Dictionary = {}) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not is_registered_player_state(player_state) or player_state.alive:
		return false
	if game_state.phase not in [GameState.GamePhase.PLAYING, GameState.GamePhase.TRANSITION]:
		return false
	return game_state.runtime_mode == GameState.RuntimeMode.CREATIVE


func can_change_runtime_mode(player_state: PlayerState, target_mode: int) -> bool:
	if not _can_apply_flow_rules():
		return false
	if not GameState.RuntimeMode.values().has(target_mode):
		return false
	if not is_registered_player_state(player_state) or not player_state.alive:
		return false
	return game_state.phase == GameState.GamePhase.PLAYING
