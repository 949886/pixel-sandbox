extends Node

const WORLD_SCENE: PackedScene = preload("res://scenes/World.tscn")
const DEFAULT_STARTING_LOADOUT: StartingLoadoutDef = preload("res://resources/gameplay/loadouts/default_starting_loadout.tres")

@onready var _game_manager: GameManager = $GameManager


func _ready() -> void:
	_game_manager.restart_ready.connect(_on_restart_ready)
	_start_game(_create_default_config())


func _create_default_config() -> GameConfig:
	var config := GameConfig.new()
	config.seed = _allocate_random_seed()
	config.flow_id = &"normal"
	config.starting_loadout = DEFAULT_STARTING_LOADOUT
	config.player_id = GameManager.LOCAL_PLAYER_ID
	return config


func _start_game(config: GameConfig) -> void:
	if config == null:
		push_error("Main: GameConfig is required.")
		return
	if config.seed == 0:
		config.seed = _allocate_random_seed()
	if config.starting_loadout == null:
		config.starting_loadout = DEFAULT_STARTING_LOADOUT

	var game_id: int = _game_manager.start_game(config)
	if game_id == GameManager.INVALID_GAME_ID:
		push_error("Main: Failed to start game lifecycle.")
		return

	var runtime := Node2D.new()
	runtime.name = "GameRuntime%d" % game_id
	add_child(runtime)
	if not _game_manager.bind_runtime_root(runtime):
		push_error("Main: Failed to bind runtime root.")
		return

	var state := GameState.new()
	state.name = "GameState"
	if not state.initialize(game_id, config.seed):
		push_error("Main: Failed to initialize GameState.")
		return
	runtime.add_child(state)
	if not _game_manager.bind_game_state(state):
		push_error("Main: Failed to bind GameState.")
		return

	var player_state := PlayerState.new()
	player_state.name = "PlayerState%d" % config.player_id
	if not player_state.initialize(config.player_id):
		push_error("Main: Failed to initialize PlayerState.")
		return
	runtime.add_child(player_state)
	if not _game_manager.register_player_state(player_state):
		push_error("Main: Failed to register PlayerState.")
		return

	var flow: GameFlow = _create_flow(config.flow_id)
	if flow == null:
		push_error("Main: Unsupported GameConfig.flow_id: %s" % config.flow_id)
		return
	runtime.add_child(flow)
	if not _game_manager.bind_game_flow(flow) or not _game_manager.start_game_flow():
		push_error("Main: Failed to initialize GameFlow.")
		return

	var world := WORLD_SCENE.instantiate()
	world.name = "World"
	_configure_world_before_tree(world, config.seed)

	var player := world.get_node_or_null("Player") as RuntimePlayer
	if player == null or not player.configure_runtime_player_id(config.player_id):
		push_error("Main: Failed to configure Player runtime identity.")
		world.free()
		return
	player.authoritative_player_died.connect(_game_manager.notify_player_died)

	runtime.add_child(world)
	if not _game_manager.bind_player_runtime(config.player_id, player):
		push_error("Main: Failed to bind Player runtime.")
		return
	if not _apply_starting_loadout(player, config.starting_loadout):
		push_error("Main: Failed to apply StartingLoadoutDef.")
		return
	if not _game_manager.notify_player_joined(config.player_id):
		push_error("Main: GameFlow rejected the local player.")
		return

	_wait_for_initial_world_readiness(game_id, world)


func _create_flow(flow_id: StringName) -> GameFlow:
	match flow_id:
		&"normal":
			var flow := NormalGameFlow.new()
			flow.name = "NormalGameFlow"
			return flow
	return null


func _configure_world_before_tree(world: Node, seed: int) -> void:
	# WorldManager currently builds in _ready(). Inject every per-game value before
	# the node enters SceneTree so sibling _ready() ordering cannot affect the seed.
	var template: WorldGenConfig = world.get("world_gen_config") as WorldGenConfig
	if template != null:
		var runtime_config := template.duplicate(false) as WorldGenConfig
		runtime_config.world_seed = seed
		world.set("world_gen_config", runtime_config)
	world.set("override_seed", true)
	world.set("world_seed", seed)


func _apply_starting_loadout(player: RuntimePlayer, loadout: StartingLoadoutDef) -> bool:
	if player == null or loadout == null:
		return false
	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if inventory == null:
		return false

	for index: int in range(mini(loadout.starting_wands.size(), inventory.wand_slot_count)):
		var source: WandDef = loadout.starting_wands[index]
		if source == null:
			continue
		if not inventory.set_wand_runtime(index, _duplicate_wand(source)):
			return false
	if not loadout.starting_wands.is_empty() and inventory.wands[0] != null:
		inventory.equip_wand(0)

	for spell: SpellDef in loadout.starting_spells:
		if spell != null and not inventory.add_spell(spell):
			return false

	player.gold = maxi(0, loadout.starting_gold)
	player.gold_changed.emit(player.gold)
	return true


func _duplicate_wand(source: WandDef) -> WandDef:
	var clone := source.duplicate(false) as WandDef
	if clone == null:
		return source
	var spells: Array[Resource] = []
	spells.assign(source.spells)
	clone.spells = spells
	var precast: Array[Resource] = []
	precast.assign(source.precast_spells)
	clone.precast_spells = precast
	return clone


func _wait_for_initial_world_readiness(game_id: int, world: Node) -> void:
	while is_instance_valid(world) and _game_manager.current_game_id == game_id:
		if _game_manager.lifecycle_state != GameManager.LifecycleState.STARTING:
			return
		var generator_ready: bool = world.get("generator") != null
		var current_chunk: Vector2i = world.get("current_player_chunk")
		var spawn_canvas_ready: bool = false
		if generator_ready and world.has_method(&"_canvas_for_chunk"):
			spawn_canvas_ready = world.call(&"_canvas_for_chunk", current_chunk) != null
		if generator_ready and spawn_canvas_ready:
			if not _game_manager.notify_world_ready():
				push_error("Main: GameFlow rejected real World readiness.")
				return
			if not _game_manager.mark_game_started(game_id):
				push_error("Main: Failed to activate ready game.")
			return
		await get_tree().process_frame


func _on_restart_ready(config: GameConfig) -> void:
	if config.seed == 0:
		config.seed = _allocate_random_seed()
	_start_game(config)


func _allocate_random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed: int = rng.randi()
	return seed if seed != 0 else 1
