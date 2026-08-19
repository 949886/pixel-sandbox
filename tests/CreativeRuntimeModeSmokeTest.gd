extends Node


class FakePlayer:
	extends Node

	var infinite_flight_enabled: bool = false
	var creative_fly_enabled: bool = false
	var persistent_value: int = 0

	func set_infinite_flight_enabled(enabled: bool) -> void:
		infinite_flight_enabled = enabled

	func set_creative_fly_enabled(enabled: bool) -> void:
		creative_fly_enabled = enabled


class FakeCreativeUI:
	extends Node

	var creative_active: bool = false

	func set_creative_active(enabled: bool) -> void:
		creative_active = enabled


class FakeWorldService:
	extends Node

	var reset_count: int = 0

	func reset_creative_simulation_controls() -> void:
		reset_count += 1


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var config := GameConfig.create_with_seed(3600)
	var game_id := manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)

	var runtime := Node.new()
	runtime.name = "Runtime"
	add_child(runtime)
	assert(manager.bind_runtime_root(runtime))

	var state := GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, config.seed))
	runtime.add_child(state)
	assert(manager.bind_game_state(state))

	var player_state := PlayerState.new()
	player_state.name = "PlayerState1"
	assert(player_state.initialize(GameManager.LOCAL_PLAYER_ID))
	runtime.add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player := FakePlayer.new()
	player.name = "Player"
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	player.add_child(health)
	var wand := WandController.new()
	wand.name = "WandController"
	player.add_child(wand)
	runtime.add_child(player)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player))

	var flow := NormalGameFlow.new()
	flow.name = "NormalGameFlow"
	runtime.add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(manager.start_game_flow())
	assert(manager.notify_player_joined(GameManager.LOCAL_PLAYER_ID))
	assert(manager.notify_gameplay_ready())
	assert(manager.mark_game_started(game_id))

	var creative_ui := FakeCreativeUI.new()
	creative_ui.name = "CreativeUI"
	runtime.add_child(creative_ui)
	creative_ui.add_to_group(&"creative_ui")

	var world_service := FakeWorldService.new()
	world_service.name = "WorldGameplayService"
	runtime.add_child(world_service)
	world_service.add_to_group(&"world_gameplay_service")

	var rules_template := GameRules.new()
	rules_template.invulnerable = true
	rules_template.infinite_mana = true
	rules_template.infinite_flight = true
	rules_template.creative_fly = true
	rules_template.allow_world_editing = true
	rules_template.allow_entity_spawning = true

	var mode_manager := GameModeManager.new()
	mode_manager.name = "GameModeManager"
	mode_manager.request_player_id = GameManager.LOCAL_PLAYER_ID
	mode_manager.creative_rules = rules_template
	runtime.add_child(mode_manager)
	mode_manager._bind_game_state()

	assert(mode_manager.current_mode == GameState.RuntimeMode.NORMAL)
	assert(not mode_manager.is_creative())
	assert(not health.invulnerable)
	assert(not wand.infinite_mana)
	assert(not player.infinite_flight_enabled)
	assert(not player.creative_fly_enabled)
	assert(not creative_ui.creative_active)
	var normal_reset_count := world_service.reset_count

	# F8 is represented by the shared toggle_creative action. The adapter may
	# capture input, but the mode mutation still goes through GameManager.
	player.persistent_value = 77
	var toggle_event := InputEventAction.new()
	toggle_event.action = &"toggle_creative"
	toggle_event.pressed = true
	mode_manager._unhandled_input(toggle_event)
	assert(state.runtime_mode == GameState.RuntimeMode.CREATIVE)
	assert(state.used_creative_mode)
	assert(mode_manager.current_mode == state.runtime_mode)
	assert(health.invulnerable)
	assert(wand.infinite_mana)
	assert(player.infinite_flight_enabled)
	assert(player.creative_fly_enabled)
	assert(creative_ui.creative_active)
	assert(player.persistent_value == 77)

	# Rule edits are per-Game runtime state and must not mutate the shared template.
	mode_manager.set_rule(&"invulnerable", false)
	assert(not health.invulnerable)
	assert(rules_template.invulnerable)
	mode_manager.set_rule(&"invulnerable", true)
	assert(health.invulnerable)

	assert(mode_manager.set_mode(GameState.RuntimeMode.NORMAL))
	assert(state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(state.used_creative_mode)
	assert(not health.invulnerable)
	assert(not wand.infinite_mana)
	assert(not player.infinite_flight_enabled)
	assert(not player.creative_fly_enabled)
	assert(not creative_ui.creative_active)
	assert(world_service.reset_count > normal_reset_count)
	assert(player.persistent_value == 77)

	# GameFlow remains the permission owner even when requests originate from the
	# compatibility adapter.
	assert(flow.enter_transition())
	assert(not mode_manager.set_mode(GameState.RuntimeMode.CREATIVE))
	assert(state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(flow.complete_transition())

	# Any successful authority request is reflected immediately by the adapter.
	assert(manager.request_runtime_mode(GameManager.LOCAL_PLAYER_ID, GameState.RuntimeMode.CREATIVE))
	assert(mode_manager.is_creative())
	assert(health.invulnerable)
	assert(creative_ui.creative_active)
	assert(manager.request_runtime_mode(GameManager.LOCAL_PLAYER_ID, GameState.RuntimeMode.NORMAL))
	assert(not mode_manager.is_creative())
	assert(not health.invulnerable)
	assert(not creative_ui.creative_active)

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	print("Creative RuntimeMode Smoke Test: PASS")
	get_tree().quit()
