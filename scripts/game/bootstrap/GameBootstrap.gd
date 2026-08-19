class_name GameBootstrap
extends Node

@export var world_scene: PackedScene
@export var world_gen_config_template: WorldGenConfig

var _game_manager: GameManager = null
var _runtime_host: Node = null
var _world: Node = null
var _active_game_id: int = GameManager.INVALID_GAME_ID
var _world_ready: bool = false
var _required_player_ids: Array[int] = []
var _ready_player_ids: Dictionary = {}


func _ready() -> void:
	set_process(false)


func setup(manager: GameManager, runtime_host: Node) -> bool:
	if _game_manager != null or _runtime_host != null:
		return _game_manager == manager and _runtime_host == runtime_host
	if manager == null or not is_instance_valid(manager):
		return false
	if runtime_host == null or not is_instance_valid(runtime_host):
		return false
	if runtime_host == manager or runtime_host.is_ancestor_of(manager):
		return false
	_game_manager = manager
	_runtime_host = runtime_host
	return true


func start_game(config: GameConfig) -> int:
	if not _is_setup() or config == null or not config.is_valid():
		return GameManager.INVALID_GAME_ID
	if not config.has_valid_starting_loadout():
		return GameManager.INVALID_GAME_ID
	if _game_manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		return GameManager.INVALID_GAME_ID

	var world := _instantiate_configured_world(config)
	if world == null:
		return GameManager.INVALID_GAME_ID
	var players := _collect_players(world)
	if players.is_empty():
		world.free()
		push_error("GameBootstrap: World scene does not provide any Player runtime.")
		return GameManager.INVALID_GAME_ID
	var required_player_ids := _sorted_player_ids(players)
	for player_id: int in required_player_ids:
		var player_runtime := players.get(player_id, null) as Player
		if player_runtime != null:
			# Player _ready() still runs when the World enters the tree, but gameplay
			# input/movement stay disabled until real readiness is satisfied.
			player_runtime.process_mode = Node.PROCESS_MODE_DISABLED

	var flow := _create_flow(config.flow_id)
	if flow == null:
		world.free()
		push_error("GameBootstrap: Unsupported GameFlow id: %s" % str(config.flow_id))
		return GameManager.INVALID_GAME_ID

	var game_id: int = _game_manager.start_game(config)
	if game_id == GameManager.INVALID_GAME_ID:
		world.free()
		flow.free()
		return GameManager.INVALID_GAME_ID
	if not _game_manager.bind_runtime_root(_runtime_host):
		world.free()
		flow.free()
		return _fail_startup("Failed to bind GameRuntime as the current runtime root.")

	var state := GameState.new()
	state.name = "GameState"
	if not state.initialize(game_id, config.seed):
		state.free()
		world.free()
		flow.free()
		return _fail_startup("Failed to initialize GameState.")
	_runtime_host.add_child(state)
	if not _game_manager.bind_game_state(state):
		state.queue_free()
		world.free()
		flow.free()
		return _fail_startup("Failed to bind GameState.")

	if not _create_player_states(game_id, required_player_ids):
		world.free()
		flow.free()
		return _fail_startup("Failed to initialize PlayerState registry.")

	_runtime_host.add_child(flow)
	if not _game_manager.bind_game_flow(flow):
		flow.queue_free()
		world.free()
		return _fail_startup("Failed to bind GameFlow.")
	if not _game_manager.start_game_flow():
		world.free()
		return _fail_startup("Failed to start GameFlow.")

	if not _reset_readiness(required_player_ids):
		world.free()
		return _fail_startup("Failed to initialize gameplay readiness tracking.")

	_world = world
	_active_game_id = game_id
	for player_id: int in required_player_ids:
		var player_runtime := players.get(player_id, null) as Player
		if player_runtime == null:
			return _fail_startup("Player runtime %d became invalid." % player_id)
		if not _game_manager.bind_player_runtime(player_id, player_runtime):
			return _fail_startup("Failed to bind Player runtime %d." % player_id)
		if not player_runtime.bind_game_state(state):
			return _fail_startup("Failed to bind GameState to Player runtime %d." % player_id)
		if not player_runtime.player_died.is_connected(_on_player_runtime_died):
			player_runtime.player_died.connect(_on_player_runtime_died.bind(player_runtime))
		if not player_runtime.apply_starting_loadout(config.starting_loadout):
			return _fail_startup("Failed to apply StartingLoadoutDef to Player %d." % player_id)
		if not _game_manager.notify_player_joined(player_id):
			return _fail_startup("GameFlow rejected Player %d join event." % player_id)

	# All authoritative creation inputs are now resolved and applied. Only now may
	# WorldManager enter the SceneTree and start generation/streaming in _ready().
	_runtime_host.add_child(_world)
	set_process(true)
	return game_id


static func create_runtime_world_config(
		template: WorldGenConfig,
		seed: int,
	) -> WorldGenConfig:
	if template == null:
		return null
	var runtime_config := template.duplicate(false) as WorldGenConfig
	if runtime_config == null:
		return null
	runtime_config.world_seed = seed
	return runtime_config


func _process(_delta: float) -> void:
	if not _startup_is_current():
		set_process(false)
		return

	_poll_world_ready()
	_poll_player_readiness()
	if not _is_gameplay_ready():
		return
	if not _game_manager.notify_gameplay_ready():
		_fail_startup("GameFlow rejected gameplay readiness.")
		return
	if not _game_manager.mark_game_started(_active_game_id):
		_fail_startup("GameManager failed to activate the ready Game.")
		return

	for player_id: int in _required_player_ids:
		var player_runtime := _game_manager.get_player_runtime(player_id)
		if player_runtime != null:
			player_runtime.process_mode = Node.PROCESS_MODE_INHERIT
	set_process(false)


func _instantiate_configured_world(config: GameConfig) -> Node:
	if world_scene == null:
		push_error("GameBootstrap: World scene is not configured.")
		return null
	if world_gen_config_template == null:
		push_error("GameBootstrap: WorldGenConfig template is not configured.")
		return null
	var world := world_scene.instantiate()
	if world == null:
		push_error("GameBootstrap: Failed to instantiate World scene.")
		return null

	var runtime_config := create_runtime_world_config(world_gen_config_template, config.seed)
	if runtime_config == null:
		world.free()
		push_error("GameBootstrap: Failed to create per-game WorldGenConfig.")
		return null

	# This happens while World is still off-tree, before WorldManager._ready()
	# starts generation. The shared Resource remains a read-only template.
	world.set(&"world_gen_config", runtime_config)
	world.set(&"override_seed", false)
	world.set(&"world_seed", config.seed)
	return world


func _create_player_states(game_id: int, player_ids: Array[int]) -> bool:
	for player_id: int in player_ids:
		var player_state := PlayerState.new()
		player_state.name = "PlayerState%d" % player_id
		if not player_state.initialize(player_id):
			player_state.free()
			return false
		_runtime_host.add_child(player_state)
		if not _game_manager.register_player_state(player_state):
			player_state.queue_free()
			return false
	return true


func _create_flow(flow_id: StringName) -> GameFlow:
	match flow_id:
		&"normal":
			var flow := NormalGameFlow.new()
			flow.name = "NormalGameFlow"
			return flow
		_:
			return null


func _poll_world_ready() -> void:
	if _world_ready:
		return
	if _world == null or not is_instance_valid(_world):
		return
	if not _world.has_method(&"is_world_position_loaded"):
		return
	for player_id: int in _required_player_ids:
		var player_runtime := _game_manager.get_player_runtime(player_id) as Node2D
		if player_runtime == null:
			return
		if not bool(_world.call(&"is_world_position_loaded", player_runtime.global_position)):
			return
	_mark_world_ready()


func _poll_player_readiness() -> void:
	for player_id: int in _required_player_ids:
		if _ready_player_ids.has(player_id):
			continue
		var player_runtime := _game_manager.get_player_runtime(player_id) as Player
		if player_runtime == null or player_runtime.player_id != player_id:
			continue
		if not player_runtime.is_ready_for_gameplay():
			continue
		_mark_player_ready(player_id)


func _collect_players(world: Node) -> Dictionary:
	var players: Dictionary = {}
	var pending: Array[Node] = []
	pending.append(world)
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
			if not child is Player:
				continue
			var player := child as Player
			if player.player_id <= GameManager.INVALID_PLAYER_ID:
				continue
			if players.has(player.player_id):
				push_error("GameBootstrap: Duplicate Player player_id %d." % player.player_id)
				return {}
			players[player.player_id] = player
	return players


func _sorted_player_ids(players: Dictionary) -> Array[int]:
	var player_ids: Array[int] = []
	for player_id_value: Variant in players.keys():
		player_ids.append(int(player_id_value))
	player_ids.sort()
	return player_ids


func _reset_readiness(required_player_ids: Array[int]) -> bool:
	var unique_ids: Dictionary = {}
	var normalized_ids: Array[int] = []
	for player_id: int in required_player_ids:
		if player_id <= GameManager.INVALID_PLAYER_ID or unique_ids.has(player_id):
			return false
		unique_ids[player_id] = true
		normalized_ids.append(player_id)
	normalized_ids.sort()
	_world_ready = false
	_required_player_ids = normalized_ids
	_ready_player_ids.clear()
	return not _required_player_ids.is_empty()


func _mark_world_ready() -> void:
	_world_ready = true


func _mark_player_ready(player_id: int) -> bool:
	if not _required_player_ids.has(player_id):
		return false
	_ready_player_ids[player_id] = true
	return true


func _is_gameplay_ready() -> bool:
	if not _world_ready:
		return false
	for player_id: int in _required_player_ids:
		if not _ready_player_ids.has(player_id):
			return false
	return not _required_player_ids.is_empty()


func _startup_is_current() -> bool:
	return _is_setup() \
		and _active_game_id != GameManager.INVALID_GAME_ID \
		and _game_manager.current_game_id == _active_game_id \
		and _game_manager.lifecycle_state == GameManager.LifecycleState.STARTING


func _is_setup() -> bool:
	return _game_manager != null and is_instance_valid(_game_manager) \
		and _runtime_host != null and is_instance_valid(_runtime_host)


func _on_player_runtime_died(
		player_id: int,
		context: Variant,
		source_runtime: Player,
	) -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		return
	_game_manager.notify_player_died(player_id, context, source_runtime)


func _fail_startup(message: String) -> int:
	push_error("GameBootstrap: %s" % message)
	set_process(false)
	return GameManager.INVALID_GAME_ID
