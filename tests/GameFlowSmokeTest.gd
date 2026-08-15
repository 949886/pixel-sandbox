extends Node


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var first := _create_normal_game(manager, 1001, [1, 2])
	var first_game_id: int = first["game_id"]
	var first_state: GameState = first["state"] as GameState
	var first_flow: NormalGameFlow = first["flow"] as NormalGameFlow
	var first_players: Dictionary = first["players"]
	var player_a: PlayerState = first_players[1] as PlayerState
	var player_b: PlayerState = first_players[2] as PlayerState

	assert(first_state.phase == GameState.GamePhase.STARTING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(not first_flow.can_change_runtime_mode(player_a, GameState.RuntimeMode.CREATIVE))
	assert(manager.notify_player_joined(1))
	assert(manager.notify_player_joined(2))
	assert(not manager.notify_player_joined(999))
	assert(not manager.mark_game_started(first_game_id))

	assert(manager.notify_world_ready())
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(not manager.notify_world_ready())
	assert(manager.mark_game_started(first_game_id))
	assert(manager.can_change_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(not manager.can_change_runtime_mode(1, 999))

	assert(first_flow.enter_transition())
	assert(first_state.phase == GameState.GamePhase.TRANSITION)
	assert(not manager.can_change_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(not first_flow.transition_phase(GameState.GamePhase.STARTING))
	assert(not first_flow.transition_phase(GameState.GamePhase.ENDED))
	assert(first_flow.complete_transition())
	assert(first_state.phase == GameState.GamePhase.PLAYING)

	# One player death is a per-player fact, not a global Game Over.
	assert(manager.notify_player_died(1))
	assert(not player_a.alive)
	assert(player_b.alive)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(not manager.notify_player_died(1))

	# Creative suppresses Normal defeat policy. Recovery itself is implemented
	# later by #36/#2, so this test only verifies the flow decision boundary.
	assert(first_state.set_runtime_mode(GameState.RuntimeMode.CREATIVE))
	assert(manager.notify_player_died(2))
	assert(not player_b.alive)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(not manager.can_change_runtime_mode(2, GameState.RuntimeMode.NORMAL))

	# Return the public facts to a Normal scenario and verify that the last
	# living player death ends the Game with an explicit defeat result.
	assert(player_b.set_alive(true))
	assert(first_state.set_runtime_mode(GameState.RuntimeMode.NORMAL))
	assert(manager.notify_player_died(2))
	assert(first_state.phase == GameState.GamePhase.ENDED)
	assert(first_state.result == GameState.GameResult.DEFEAT)
	assert(not manager.can_change_runtime_mode(2, GameState.RuntimeMode.CREATIVE))
	assert(not manager.notify_boss_defeated(&"mine_boss"))

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	var second := _create_normal_game(manager, 2002, [7])
	var second_game_id: int = second["game_id"]
	var second_state: GameState = second["state"] as GameState
	var second_players: Dictionary = second["players"]
	var second_player: PlayerState = second_players[7] as PlayerState

	assert(manager.notify_player_joined(second_player.player_id))
	assert(manager.notify_world_ready())
	assert(manager.mark_game_started(second_game_id))
	assert(second_state.phase == GameState.GamePhase.PLAYING)
	assert(not second_state.boss_defeated)

	# The Normal victory path requires the boss fact before a living player can
	# complete the exit. Boss/Exit runtime mechanics are deliberately absent.
	assert(not manager.notify_exit_reached(second_player.player_id))
	assert(not manager.notify_boss_defeated(&""))
	assert(manager.notify_boss_defeated(&"mine_boss"))
	assert(second_state.boss_defeated)
	assert(manager.notify_exit_reached(second_player.player_id))
	assert(second_state.phase == GameState.GamePhase.ENDED)
	assert(second_state.result == GameState.GameResult.VICTORY)
	assert(not manager.notify_exit_reached(second_player.player_id))

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	print("GameFlow Smoke Test: PASS")
	get_tree().quit()


func _create_normal_game(
		manager: GameManager,
		seed: int,
		player_ids: Array,
	) -> Dictionary:
	var game_id: int = manager.start_game()
	assert(game_id != GameManager.INVALID_GAME_ID)

	var runtime := Node.new()
	runtime.name = "FlowRuntime%d" % game_id
	add_child(runtime)
	assert(manager.bind_runtime_root(runtime))

	var state := GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, seed))
	runtime.add_child(state)
	assert(manager.bind_game_state(state))

	var players: Dictionary = {}
	for player_id_value: Variant in player_ids:
		var player_id := int(player_id_value)
		var player_state := PlayerState.new()
		player_state.name = "PlayerState%d" % player_id
		assert(player_state.initialize(player_id, player_id + 100))
		runtime.add_child(player_state)
		assert(manager.register_player_state(player_state))
		players[player_id] = player_state

	var flow := NormalGameFlow.new()
	flow.name = "NormalGameFlow"
	runtime.add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(flow.game_manager == manager)
	assert(flow.game_state == state)
	assert(manager.start_game_flow())
	assert(flow.is_started())

	return {
		"game_id": game_id,
		"runtime": runtime,
		"state": state,
		"flow": flow,
		"players": players,
	}
