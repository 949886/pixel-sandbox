extends Node


class FakePlayerRuntime extends Node:
	var spawn_position := Vector2(12.0, 34.0)
	var respawn_count: int = 0

	func get_spawn_position() -> Vector2:
		return spawn_position

	func respawn_at(_position: Vector2) -> bool:
		respawn_count += 1
		return true


func _ready() -> void:
	var manager := GameManager.new()
	add_child(manager)

	var config := GameConfig.new()
	config.seed = 424242
	config.flow_id = &"normal"
	config.player_id = GameManager.LOCAL_PLAYER_ID

	var game_id: int = manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)
	assert(manager.current_config != config)
	assert(manager.current_config.seed == 424242)

	var runtime := Node.new()
	add_child(runtime)
	assert(manager.bind_runtime_root(runtime))

	var state := GameState.new()
	assert(state.initialize(game_id, config.seed))
	runtime.add_child(state)
	assert(manager.bind_game_state(state))
	assert(state.game_seed == config.seed)

	var player_state := PlayerState.new()
	assert(player_state.initialize(config.player_id))
	runtime.add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player := FakePlayerRuntime.new()
	runtime.add_child(player)
	assert(manager.bind_player_runtime(config.player_id, player))

	var flow := NormalGameFlow.new()
	runtime.add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(manager.start_game_flow())
	assert(manager.notify_player_joined(config.player_id))
	assert(manager.notify_world_ready())
	assert(manager.mark_game_started(game_id))

	# RuntimeMode can only be mutated through the authoritative request path.
	assert(manager.request_runtime_mode(config.player_id, GameState.RuntimeMode.CREATIVE))
	assert(state.runtime_mode == GameState.RuntimeMode.CREATIVE)
	assert(state.used_creative_mode)

	# Creative death is explicitly recovered by Flow -> GameManager -> runtime.
	assert(manager.notify_player_died(config.player_id, &"creative_test"))
	assert(player.respawn_count == 1)
	assert(player_state.alive)
	assert(state.phase == GameState.GamePhase.PLAYING)
	assert(state.result == GameState.GameResult.NONE)

	assert(manager.request_runtime_mode(config.player_id, GameState.RuntimeMode.NORMAL))
	assert(state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(state.used_creative_mode)

	# Normal last-player death ends the game and blocks Creative recovery.
	assert(manager.notify_player_died(config.player_id, &"normal_test"))
	assert(not player_state.alive)
	assert(state.phase == GameState.GamePhase.ENDED)
	assert(state.result == GameState.GameResult.DEFEAT)
	assert(not manager.request_runtime_mode(config.player_id, GameState.RuntimeMode.CREATIVE))
	assert(not manager.recover_player(config.player_id))

	# Restart tears down this runtime and returns creation input for a new Game.
	var next_config: GameConfig = null
	manager.restart_ready.connect(func(value: GameConfig) -> void:
		next_config = value
	, Object.CONNECT_ONE_SHOT)
	assert(manager.request_restart(config.player_id))
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped
	await get_tree().process_frame
	assert(next_config != null)
	assert(next_config.seed == 0)
	assert(next_config.player_id == config.player_id)

	next_config.seed = 777777
	var restarted_game_id: int = manager.start_game(next_config)
	assert(restarted_game_id != GameManager.INVALID_GAME_ID)
	assert(restarted_game_id != game_id)
	assert(manager.current_config.seed == 777777)

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	print("Game Runtime Phase 2 Smoke Test: PASS")
	get_tree().quit()
