class_name GameBootstrapManager
extends GameManager

var current_config: GameConfig = null

var _bootstrap_runtime_root: Node = null
var _bootstrap_world_scene: PackedScene = null
var _world_runtime_ready: bool = false
var _initial_world_ready: bool = false
var _player_startup_readiness: Dictionary = {}


func _ready() -> void:
	super()
	game_started.connect(_on_bootstrap_game_started)
	game_stopped.connect(_on_bootstrap_game_stopped)


func configure_bootstrap(runtime_root: Node, world_scene: PackedScene) -> bool:
	if lifecycle_state != LifecycleState.IDLE:
		return false
	if runtime_root == null or not is_instance_valid(runtime_root) or world_scene == null:
		return false
	if runtime_root == self or runtime_root.is_ancestor_of(self):
		return false
	_bootstrap_runtime_root = runtime_root
	_bootstrap_world_scene = world_scene
	return true


func start_game(config: Variant = null) -> int:
	if lifecycle_state != LifecycleState.IDLE:
		return INVALID_GAME_ID
	if not config is GameConfig:
		return INVALID_GAME_ID

	var typed_config := config as GameConfig
	if typed_config == null or not typed_config.is_valid():
		return INVALID_GAME_ID

	_reset_startup_readiness()
	current_config = typed_config
	var game_id: int = super(typed_config)
	if game_id == INVALID_GAME_ID:
		current_config = null
		return INVALID_GAME_ID

	# Tests and future server/bootstrap coordinators may build framework nodes
	# manually. The formal Main scene configures these dependencies and therefore
	# takes the complete start_game(config) path below.
	if _bootstrap_runtime_root == null or _bootstrap_world_scene == null:
		return game_id
	if _bootstrap_configured_game(game_id, typed_config):
		return game_id

	push_error("GameBootstrapManager failed to construct game %d." % game_id)
	stop_game()
	return INVALID_GAME_ID


func register_player_state(player_state: PlayerState) -> bool:
	if not super(player_state):
		return false
	var player_id: int = player_state.player_id
	if not _player_startup_readiness.has(player_id):
		_player_startup_readiness[player_id] = _empty_player_readiness()
	return true


func unregister_player_state(player_id: int) -> bool:
	if not super(player_id):
		return false
	_player_startup_readiness.erase(player_id)
	return true


func set_world_runtime_ready(ready: bool = true) -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	_world_runtime_ready = ready
	return true


func set_initial_world_ready(ready: bool = true) -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	_initial_world_ready = ready
	return true


func set_player_runtime_ready(player_id: int, ready: bool = true) -> bool:
	if not _can_update_player_readiness(player_id):
		return false
	if ready and get_player_runtime(player_id) == null:
		return false
	return _set_player_readiness_flag(player_id, &"runtime_bound", ready)


func set_player_spawn_ready(
		player_id: int,
		spawn_position: Vector2,
		ready: bool = true,
	) -> bool:
	if not _can_update_player_readiness(player_id):
		return false
	if ready and not spawn_position.is_finite():
		return false
	if not _set_player_readiness_flag(player_id, &"spawn_valid", ready):
		return false
	var readiness: Dictionary = _player_startup_readiness[player_id]
	readiness["spawn_position"] = spawn_position if ready else Vector2.ZERO
	_player_startup_readiness[player_id] = readiness
	return true


func set_player_loadout_ready(player_id: int, ready: bool = true) -> bool:
	if not _can_update_player_readiness(player_id):
		return false
	if ready and get_player_runtime(player_id) == null:
		return false
	return _set_player_readiness_flag(player_id, &"loadout_applied", ready)


func is_startup_ready() -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	if current_config == null or not current_config.is_valid():
		return false
	if game_state == null or not is_instance_valid(game_state):
		return false
	if game_flow == null or not is_instance_valid(game_flow) or not game_flow.is_started():
		return false
	if not _world_runtime_ready or not _initial_world_ready:
		return false

	var player_states := get_player_states()
	if player_states.is_empty():
		return false
	for player_state: PlayerState in player_states:
		var readiness: Dictionary = _player_startup_readiness.get(player_state.player_id, {})
		if not bool(readiness.get("runtime_bound", false)):
			return false
		if not bool(readiness.get("spawn_valid", false)):
			return false
		if not bool(readiness.get("loadout_applied", false)):
			return false
	return true


func try_complete_startup() -> bool:
	if not is_startup_ready():
		return false
	if game_state.phase == GameState.GamePhase.STARTING:
		if not notify_world_ready():
			return false
	if game_state.phase != GameState.GamePhase.PLAYING:
		return false
	return mark_game_started(current_game_id)


func get_player_startup_readiness(player_id: int) -> Dictionary:
	if not _player_startup_readiness.has(player_id):
		return {}
	var readiness: Dictionary = _player_startup_readiness[player_id]
	return readiness.duplicate()


func _bootstrap_configured_game(game_id: int, config: GameConfig) -> bool:
	if game_id != current_game_id or lifecycle_state != LifecycleState.STARTING:
		return false
	if not _bootstrap_runtime_root.is_inside_tree():
		return false
	if not bind_runtime_root(_bootstrap_runtime_root):
		return false

	var state := GameState.new()
	state.name = "GameState"
	if not state.initialize(game_id, config.seed):
		state.free()
		return false
	_bootstrap_runtime_root.add_child(state)
	if not bind_game_state(state):
		state.queue_free()
		return false

	var flow := _create_flow(config.flow_id)
	if flow == null:
		return false
	_bootstrap_runtime_root.add_child(flow)
	if not bind_game_flow(flow):
		flow.queue_free()
		return false
	if not start_game_flow():
		return false

	var player_state := PlayerState.new()
	player_state.name = "PlayerState%d" % LOCAL_PLAYER_ID
	if not player_state.initialize(LOCAL_PLAYER_ID):
		player_state.free()
		return false
	_bootstrap_runtime_root.add_child(player_state)
	if not register_player_state(player_state):
		player_state.queue_free()
		return false

	var world := _bootstrap_world_scene.instantiate() as BootstrapWorldManager
	if world == null:
		return false
	world.name = "World"

	var player_runtime := world.get_node_or_null("Player") as Node2D
	if player_runtime == null:
		world.free()
		return false
	var spawn_position: Vector2 = player_runtime.position
	player_runtime.process_mode = Node.PROCESS_MODE_DISABLED

	if not world.configure(config.seed, world.world_gen_config, spawn_position):
		world.free()
		return false
	world.initial_spawn_ready.connect(_on_initial_spawn_ready.bind(game_id))
	_bootstrap_runtime_root.add_child(world)

	if not bind_player_runtime(player_state.player_id, player_runtime):
		return false
	if not set_player_runtime_ready(player_state.player_id):
		return false
	if not set_player_spawn_ready(player_state.player_id, spawn_position):
		return false
	if not StartingLoadoutApplicator.apply_to_player(player_runtime, config.starting_loadout):
		return false
	if not set_player_loadout_ready(player_state.player_id):
		return false
	if not notify_player_joined(player_state.player_id):
		return false

	if not world.start_world():
		return false
	if not set_world_runtime_ready():
		return false
	if world.is_initial_spawn_ready() and not set_initial_world_ready():
		return false

	# Threaded generation normally completes later through initial_spawn_ready.
	if is_startup_ready() and not try_complete_startup():
		return false
	return true


func _create_flow(flow_id: StringName) -> GameFlow:
	match flow_id:
		&"normal":
			var flow := NormalGameFlow.new()
			flow.name = "NormalGameFlow"
			return flow
		_:
			push_error("Unsupported GameFlow id: %s" % String(flow_id))
			return null


func _can_update_player_readiness(player_id: int) -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	if get_player_state(player_id) == null:
		return false
	return _player_startup_readiness.has(player_id)


func _set_player_readiness_flag(
		player_id: int,
		flag: StringName,
		value: bool,
	) -> bool:
	if not _player_startup_readiness.has(player_id):
		return false
	var readiness: Dictionary = _player_startup_readiness[player_id]
	readiness[String(flag)] = value
	_player_startup_readiness[player_id] = readiness
	return true


func _empty_player_readiness() -> Dictionary:
	return {
		"runtime_bound": false,
		"spawn_valid": false,
		"spawn_position": Vector2.ZERO,
		"loadout_applied": false,
	}


func _reset_startup_readiness() -> void:
	_world_runtime_ready = false
	_initial_world_ready = false
	_player_startup_readiness.clear()


func _on_initial_spawn_ready(_spawn_position: Vector2, game_id: int) -> void:
	if current_game_id != game_id or lifecycle_state != LifecycleState.STARTING:
		return
	if not set_initial_world_ready():
		return
	if is_startup_ready() and not try_complete_startup():
		push_error("Initial readiness was complete, but GameManager could not activate the game.")


func _on_bootstrap_game_started(game_id: int) -> void:
	if current_game_id != game_id:
		return
	for player_state: PlayerState in get_player_states():
		var player_runtime := get_player_runtime(player_state.player_id)
		if player_runtime != null:
			player_runtime.process_mode = Node.PROCESS_MODE_INHERIT


func _on_bootstrap_game_stopped(_game_id: int) -> void:
	current_config = null
	_reset_startup_readiness()
