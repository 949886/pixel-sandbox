extends Node


class FakePlayerRuntime:
	extends Node

	var spawn_position := Vector2.ZERO
	var current_position := Vector2.ZERO
	var respawn_count: int = 0

	func _init(initial_spawn: Vector2 = Vector2.ZERO) -> void:
		spawn_position = initial_spawn
		current_position = initial_spawn

	func get_spawn_position() -> Vector2:
		return spawn_position

	func respawn_at(position: Vector2, _options: Dictionary = {}) -> bool:
		current_position = position
		respawn_count += 1
		return true


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var first := _create_normal_game(manager, 1001, [1, 2])
	var first_game_id: int = first["game_id"]
	var first_state: GameState = first["state"] as GameState
	var first_flow: NormalGameFlow = first["flow"] as NormalGameFlow
	var first_players: Dictionary = first["players"]
	var first_runtimes: Dictionary = first["runtimes"]
	var player_a: PlayerState = first_players[1] as PlayerState
	var player_b: PlayerState = first_players[2] as PlayerState
	var player_a_runtime: FakePlayerRuntime = first_runtimes[1] as FakePlayerRuntime
	var player_b_runtime: FakePlayerRuntime = first_runtimes[2] as FakePlayerRuntime

	assert(first_state.phase == GameState.GamePhase.STARTING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(first_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not first_state.used_creative_mode)
	assert(not first_flow.can_change_runtime_mode(player_a, GameState.RuntimeMode.CREATIVE))
	assert(not manager.request_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(manager.notify_player_joined(1))
	assert(manager.notify_player_joined(2))
	assert(not manager.notify_player_joined(999))
	assert(not manager.mark_game_started(first_game_id))

	assert(manager.notify_gameplay_ready())
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(not manager.notify_gameplay_ready())
	assert(manager.mark_game_started(first_game_id))
	assert(manager.can_change_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(not manager.can_change_runtime_mode(1, 999))
	assert(not manager.request_runtime_mode(999, GameState.RuntimeMode.CREATIVE))
	assert(not manager.request_runtime_mode(1, 999))

	# RuntimeMode mutations go through GameManager and mark Creative usage sticky.
	assert(manager.request_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(first_state.runtime_mode == GameState.RuntimeMode.CREATIVE)
	assert(first_state.used_creative_mode)
	assert(manager.request_runtime_mode(1, GameState.RuntimeMode.NORMAL))
	assert(first_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(first_state.used_creative_mode)

	assert(first_flow.enter_transition())
	assert(first_state.phase == GameState.GamePhase.TRANSITION)
	assert(not manager.can_change_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(not manager.request_runtime_mode(1, GameState.RuntimeMode.CREATIVE))
	assert(first_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not first_flow.transition_phase(GameState.GamePhase.STARTING))
	assert(not first_flow.transition_phase(GameState.GamePhase.ENDED))
	assert(first_flow.complete_transition())
	assert(first_state.phase == GameState.GamePhase.PLAYING)

	# One Normal death is a per-player fact, not a global Game Over while another
	# registered Player is still alive.
	assert(manager.notify_player_died(1, {"cause": &"smoke"}, player_a_runtime))
	assert(not player_a.alive)
	assert(player_b.alive)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(not manager.notify_player_died(1, null, player_a_runtime))

	# Creative death recovery is an explicit Flow -> GameManager -> runtime path.
	# It restores the dead PlayerState after the runtime recovery succeeds and
	# does not replace the current Game or roll back other public facts.
	player_b_runtime.current_position = Vector2(80.0, 40.0)
	assert(manager.request_runtime_mode(2, GameState.RuntimeMode.CREATIVE))
	assert(manager.notify_player_died(2, {"cause": &"creative_smoke"}, player_b_runtime))
	assert(player_b.alive)
	assert(player_b_runtime.respawn_count == 1)
	assert(player_b_runtime.current_position == player_b_runtime.spawn_position)
	assert(not player_a.alive)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(first_state.result == GameState.GameResult.NONE)
	assert(first_state.used_creative_mode)

	# Return to Normal and verify that the last living Player death ends the Game
	# with an explicit defeat result.
	assert(manager.request_runtime_mode(2, GameState.RuntimeMode.NORMAL))
	assert(first_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(manager.notify_player_died(2, {"cause": &"normal_smoke"}, player_b_runtime))
	assert(not player_b.alive)
	assert(first_state.phase == GameState.GamePhase.ENDED)
	assert(first_state.result == GameState.GameResult.DEFEAT)
	assert(not manager.request_player_recovery(2))
	assert(not manager.can_change_runtime_mode(2, GameState.RuntimeMode.CREATIVE))
	assert(not manager.request_runtime_mode(2, GameState.RuntimeMode.CREATIVE))
	assert(first_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not manager.notify_boss_defeated(&"mine_boss"))

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	var second := _create_normal_game(manager, 2002, [7])
	var second_game_id: int = second["game_id"]
	var second_state: GameState = second["state"] as GameState
	var second_players: Dictionary = second["players"]
	var second_player: PlayerState = second_players[7] as PlayerState

	assert(second_game_id != first_game_id)
	assert(manager.notify_player_joined(second_player.player_id))
	assert(manager.notify_gameplay_ready())
	assert(manager.mark_game_started(second_game_id))
	assert(second_state.phase == GameState.GamePhase.PLAYING)
	assert(second_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not second_state.used_creative_mode)
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
	assert(not manager.request_runtime_mode(second_player.player_id, GameState.RuntimeMode.CREATIVE))

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
	var config := GameConfig.create_with_seed(seed)
	var game_id: int = manager.start_game(config)
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
	var runtimes: Dictionary = {}
	for player_id_value: Variant in player_ids:
		var player_id := int(player_id_value)
		var player_state := PlayerState.new()
		player_state.name = "PlayerState%d" % player_id
		assert(player_state.initialize(player_id, player_id + 100))
		runtime.add_child(player_state)
		assert(manager.register_player_state(player_state))
		players[player_id] = player_state

		var player_runtime := FakePlayerRuntime.new(Vector2(float(player_id * 10), 20.0))
		player_runtime.name = "PlayerRuntime%d" % player_id
		runtime.add_child(player_runtime)
		assert(manager.bind_player_runtime(player_id, player_runtime))
		runtimes[player_id] = player_runtime

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
		"runtimes": runtimes,
	}
