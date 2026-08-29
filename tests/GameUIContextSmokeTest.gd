extends Node


func _ready() -> void:
	await _test_context_lifecycle()
	print("Game UI Context Smoke Test: PASS")
	get_tree().quit()


func _test_context_lifecycle() -> void:
	var manager: GameManager = GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var summary: GameSummary = GameSummary.new()
	summary.name = "GameSummary"
	add_child(summary)
	assert(summary.setup(manager))

	var context: GameUIContext = GameUIContext.new()
	assert(context.setup_persistent(manager, summary))
	assert(context.is_persistent_ready())
	assert(not context.has_game())

	var config: GameConfig = GameConfig.create_with_seed(8181)
	assert(config != null and config.is_valid())
	var game_id: int = manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)

	var runtime_root: Node = Node.new()
	runtime_root.name = "GameRuntime%d" % game_id
	add_child(runtime_root)
	assert(manager.bind_runtime_root(runtime_root))

	var state: GameState = GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, config.seed))
	runtime_root.add_child(state)
	assert(manager.bind_game_state(state))

	var player_state: PlayerState = PlayerState.new()
	player_state.name = "PlayerState1"
	assert(player_state.initialize(GameManager.LOCAL_PLAYER_ID))
	runtime_root.add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player: Node = Node.new()
	player.name = "Player"
	runtime_root.add_child(player)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player))

	var world_service: WorldGameplayService = WorldGameplayService.new()
	var mode_manager: GameModeManager = GameModeManager.new()
	var brush: CreativeBrushController = CreativeBrushController.new()
	var entities: CreativeEntityController = CreativeEntityController.new()

	assert(context.bind_game(
		game_id,
		state,
		player_state,
		player,
		world_service,
		mode_manager,
		brush,
		entities,
	))
	assert(context.has_game())
	assert(context.game_id == game_id)
	assert(context.game_state == state)
	assert(context.player_state == player_state)
	assert(context.player == player)
	assert(context.gameplay_world == world_service)
	assert(context.game_mode_manager == mode_manager)
	assert(context.creative_brush == brush)
	assert(context.creative_entities == entities)

	var state_ref: WeakRef = weakref(state)
	var player_ref: WeakRef = weakref(player)
	assert(context.clear_game(game_id))
	assert(not context.has_game())
	assert(context.game_id == GameManager.INVALID_GAME_ID)
	assert(context.game_manager == manager)
	assert(context.game_summary == summary)

	assert(manager.stop_game())
	await get_tree().process_frame
	assert(state_ref.get_ref() == null)
	assert(player_ref.get_ref() == null)

	world_service.free()
	mode_manager.free()
	brush.free()
	entities.free()
	summary.queue_free()
	manager.queue_free()
