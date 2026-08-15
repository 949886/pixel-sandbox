extends Node

class FakePlayer:
	extends Node

	var gold: int = 0

	func add_gold(amount: int) -> void:
		if amount > 0:
			gold += amount


class FakeFlow:
	extends GameFlow

	func _on_start() -> bool:
		return true

	func on_world_ready() -> bool:
		return transition_phase(GameState.GamePhase.PLAYING)

	func can_transition_phase(current: int, next: int) -> bool:
		return current == GameState.GamePhase.STARTING \
			and next == GameState.GamePhase.PLAYING

	func on_player_joined(player_state: PlayerState) -> bool:
		return is_registered_player_state(player_state)


func _ready() -> void:
	_test_game_config_and_world_config_isolation()
	_test_starting_loadout_application()
	_test_formal_scenes_are_fixture_free()
	await _test_configured_manager_bootstrap()
	await _test_readiness_aggregation()

	print("Game Bootstrap Smoke Test: PASS")
	get_tree().quit()


func _test_game_config_and_world_config_isolation() -> void:
	var default_loadout := load(
		"res://resources/gameplay/loadouts/normal_starting_loadout.tres"
	) as StartingLoadoutDef
	assert(default_loadout != null)
	assert(default_loadout.is_valid())

	var explicit_seed: int = 424242
	var config := GameConfig.create(explicit_seed, default_loadout)
	assert(config.is_valid())
	assert(config.seed == explicit_seed)
	assert(config.flow_id == &"normal")
	assert(config.starting_loadout == default_loadout)

	var template := load(
		"res://resources/world_gen/default_world_gen_config.tres"
	) as WorldGenConfig
	assert(template != null)
	var template_seed: int = template.world_seed
	var template_radius: int = template.load_radius

	var first_world := BootstrapWorldManager.new()
	assert(first_world.configure(explicit_seed, template, Vector2(256, 256)))
	assert(first_world.is_bootstrap_configured())
	assert(not first_world.is_world_started())
	var first_runtime_config := first_world.get_runtime_world_gen_config()
	assert(first_runtime_config != null)
	assert(first_runtime_config != template)
	assert(first_runtime_config.world_seed == explicit_seed)
	assert(first_world.world_seed == explicit_seed)
	assert(template.world_seed == template_seed)
	first_runtime_config.load_radius = template_radius + 3
	assert(template.load_radius == template_radius)
	assert(not first_world.configure(explicit_seed + 1, template, Vector2.ZERO))

	var second_world := BootstrapWorldManager.new()
	assert(second_world.configure(explicit_seed, template, Vector2(256, 256)))
	var second_runtime_config := second_world.get_runtime_world_gen_config()
	assert(second_runtime_config != null)
	assert(second_runtime_config != first_runtime_config)
	assert(second_runtime_config.world_seed == first_runtime_config.world_seed)
	assert(second_runtime_config.load_radius == template_radius)
	assert(template.world_seed == template_seed)

	first_world.free()
	second_world.free()


func _test_starting_loadout_application() -> void:
	var player := FakePlayer.new()
	player.name = "FakePlayer"
	add_child(player)

	var wand_controller := WandController.new()
	wand_controller.name = "WandController"
	player.add_child(wand_controller)

	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	inventory.wand_slot_count = 4
	inventory.spell_inventory_capacity = 24
	player.add_child(inventory)
	inventory.initialize(wand_controller)

	assert(wand_controller.wand_def == null)
	for wand: WandDef in inventory.wands:
		assert(wand == null)

	var starter_wand := load(
		"res://resources/gameplay/wands/starter_wand.tres"
	) as WandDef
	var loose_spell := load(
		"res://resources/gameplay/spells/luna/fireball.tres"
	) as SpellDef
	assert(starter_wand != null)
	assert(loose_spell != null)

	var loadout := StartingLoadoutDef.new()
	var starting_wands: Array[WandDef] = [starter_wand]
	var starting_spells: Array[SpellDef] = [loose_spell]
	loadout.starting_wands = starting_wands
	loadout.starting_spells = starting_spells
	loadout.starting_gold = 25
	assert(loadout.is_valid())

	assert(StartingLoadoutApplicator.apply_to_player(player, loadout))
	assert(player.gold == 25)
	assert(inventory.equipped_wand() != null)
	assert(inventory.equipped_wand() != starter_wand)
	assert(inventory.equipped_wand().wand_id == starter_wand.wand_id)
	assert(wand_controller.wand_def == inventory.equipped_wand())
	assert(inventory.inventory_spell(0) == loose_spell)
	assert(not StartingLoadoutApplicator.apply_to_player(player, loadout))

	player.queue_free()


func _test_formal_scenes_are_fixture_free() -> void:
	var world_scene := load("res://scenes/World.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate() as BootstrapWorldManager
	assert(world != null)

	assert(not world.has_node("StarterSpellPickup"))
	assert(world.has_node("Enemies"))
	assert(world.get_node("Enemies").get_child_count() == 0)

	var player := world.get_node_or_null("Player")
	assert(player != null)
	var wand_controller := player.get_node_or_null("WandController") as WandController
	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	assert(wand_controller != null)
	assert(inventory != null)
	assert(wand_controller.wand_def == null)
	assert(inventory.secondary_test_wand == null)

	world.free()


func _test_configured_manager_bootstrap() -> void:
	var manager := GameBootstrapManager.new()
	manager.name = "ConfiguredGameBootstrapManager"
	add_child(manager)

	var runtime := Node2D.new()
	runtime.name = "ConfiguredRuntime"
	add_child(runtime)

	var fake_world_scene := load(
		"res://tests/fixtures/FakeBootstrapWorld.tscn"
	) as PackedScene
	assert(fake_world_scene != null)
	assert(manager.configure_bootstrap(runtime, fake_world_scene))

	var starter_wand := load(
		"res://resources/gameplay/wands/starter_wand.tres"
	) as WandDef
	assert(starter_wand != null)

	var loadout := StartingLoadoutDef.new()
	var starting_wands: Array[WandDef] = [starter_wand]
	loadout.starting_wands = starting_wands
	loadout.starting_gold = 13

	var seed: int = 11223344
	var config := GameConfig.create(seed, loadout)
	var game_id: int = manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)
	assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)
	assert(manager.game_state != null)
	assert(manager.game_state.game_seed == seed)
	assert(manager.game_state.phase == GameState.GamePhase.PLAYING)
	assert(manager.game_flow is NormalGameFlow)

	assert(runtime.has_node("GameState"))
	assert(runtime.has_node("NormalGameFlow"))
	assert(runtime.has_node("PlayerState1"))
	assert(runtime.has_node("World"))

	var world := runtime.get_node("World") as BootstrapWorldManager
	assert(world != null)
	assert(world.world_seed == seed)
	assert(world.get_runtime_world_gen_config() != null)
	assert(world.get_runtime_world_gen_config().world_seed == seed)

	var player_runtime := manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID)
	assert(player_runtime != null)
	assert(int(player_runtime.get("gold")) == 13)
	var inventory := player_runtime.get_node("PlayerInventory") as PlayerInventory
	assert(inventory != null)
	assert(inventory.equipped_wand() != null)
	assert(inventory.equipped_wand().wand_id == starter_wand.wand_id)
	assert(player_runtime.process_mode == Node.PROCESS_MODE_INHERIT)

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped
	assert(manager.current_config == null)
	manager.queue_free()


func _test_readiness_aggregation() -> void:
	var manager := GameBootstrapManager.new()
	manager.name = "GameBootstrapManager"
	add_child(manager)

	var loadout := StartingLoadoutDef.new()
	var config := GameConfig.create(987654321, loadout)
	assert(config.is_valid())

	var game_id: int = manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)
	assert(manager.current_config == config)
	assert(manager.lifecycle_state == GameManager.LifecycleState.STARTING)

	var runtime := Node.new()
	runtime.name = "Runtime"
	add_child(runtime)
	assert(manager.bind_runtime_root(runtime))

	var state := GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, config.seed))
	runtime.add_child(state)
	assert(manager.bind_game_state(state))
	assert(state.game_seed == config.seed)

	var flow := FakeFlow.new()
	flow.name = "FakeFlow"
	runtime.add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(manager.start_game_flow())

	var player_id: int = 7
	var player_state := PlayerState.new()
	player_state.name = "PlayerState7"
	assert(player_state.initialize(player_id))
	runtime.add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player_runtime := Node.new()
	player_runtime.name = "PlayerRuntime7"
	runtime.add_child(player_runtime)
	assert(manager.bind_player_runtime(player_id, player_runtime))
	assert(manager.notify_player_joined(player_id))

	assert(manager.set_player_runtime_ready(player_id))
	assert(manager.set_player_spawn_ready(player_id, Vector2(256, 256)))
	assert(manager.set_player_loadout_ready(player_id))
	assert(manager.set_world_runtime_ready())

	assert(not manager.is_startup_ready())
	assert(not manager.try_complete_startup())
	assert(state.phase == GameState.GamePhase.STARTING)
	assert(manager.lifecycle_state == GameManager.LifecycleState.STARTING)

	assert(manager.set_initial_world_ready())
	assert(manager.is_startup_ready())
	assert(manager.try_complete_startup())
	assert(state.phase == GameState.GamePhase.PLAYING)
	assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)

	var readiness := manager.get_player_startup_readiness(player_id)
	assert(bool(readiness.get("runtime_bound", false)))
	assert(bool(readiness.get("spawn_valid", false)))
	assert(bool(readiness.get("loadout_applied", false)))
	assert(readiness.get("spawn_position", Vector2.ZERO) == Vector2(256, 256))

	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped
	assert(manager.current_config == null)
