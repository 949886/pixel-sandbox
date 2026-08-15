class_name GameManager
extends Node

signal game_starting(game_id: int)
signal game_started(game_id: int)
signal game_stopping(game_id: int)
signal game_stopped(game_id: int)

enum LifecycleState {
	IDLE,
	STARTING,
	ACTIVE,
	STOPPING,
}

const INVALID_GAME_ID: int = 0
const INVALID_PLAYER_ID: int = 0
const LOCAL_PLAYER_ID: int = 1

var lifecycle_state: int = LifecycleState.IDLE
var current_game_id: int = INVALID_GAME_ID

var game_config: GameConfig = null
var game_state: GameState = null
var game_flow: GameFlow = null
var runtime_root: Node = null

var _next_game_id: int = 1
var _player_states: Dictionary = {}
var _player_runtimes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_manager")


func has_active_game() -> bool:
	return lifecycle_state != LifecycleState.IDLE


func is_game_authority() -> bool:
	# V5 is single-player. Future networking can move this decision to the
	# authoritative server without changing the public request path.
	return true


func start_game(config: GameConfig) -> int:
	if lifecycle_state != LifecycleState.IDLE:
		return INVALID_GAME_ID
	if config == null or not config.is_valid():
		return INVALID_GAME_ID

	_clear_framework_references()
	game_config = config
	current_game_id = _allocate_game_id()
	lifecycle_state = LifecycleState.STARTING
	game_starting.emit(current_game_id)
	return current_game_id


func mark_game_started(game_id: int) -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	if game_id != current_game_id:
		return false
	if game_state == null or not is_instance_valid(game_state):
		return false
	if game_flow == null or not is_instance_valid(game_flow) or not game_flow.is_started():
		return false
	if game_state.phase != GameState.GamePhase.PLAYING:
		return false

	lifecycle_state = LifecycleState.ACTIVE
	game_started.emit(game_id)
	return true


func stop_game() -> bool:
	if lifecycle_state == LifecycleState.IDLE:
		return false
	if lifecycle_state == LifecycleState.STOPPING:
		return false

	var stopping_game_id: int = current_game_id
	lifecycle_state = LifecycleState.STOPPING
	game_stopping.emit(stopping_game_id)

	var root_to_teardown: Node = runtime_root
	runtime_root = null

	if root_to_teardown == null or not is_instance_valid(root_to_teardown):
		_finish_stop(stopping_game_id)
		return true

	if root_to_teardown == self or root_to_teardown.is_ancestor_of(self):
		push_error("GameManager refused to destroy a runtime root that owns the manager itself.")
		_finish_stop(stopping_game_id)
		return true

	if root_to_teardown.is_inside_tree():
		root_to_teardown.tree_exited.connect(
			_on_runtime_tree_exited.bind(stopping_game_id),
			Object.CONNECT_ONE_SHOT,
		)
		root_to_teardown.queue_free()
	else:
		root_to_teardown.free()
		_finish_stop(stopping_game_id)

	return true


func bind_game_state(state: GameState) -> bool:
	if not _can_bind_framework_node(state):
		return false
	if game_config == null or not game_config.is_valid():
		return false
	if not state.is_initialized():
		return false
	if state.game_id != current_game_id:
		return false
	if state.game_seed != game_config.seed:
		return false
	if game_state != null and game_state != state:
		return false
	game_state = state
	return true


func bind_game_flow(flow: GameFlow) -> bool:
	if not _can_bind_framework_node(flow):
		return false
	if game_state == null or not is_instance_valid(game_state):
		return false
	if game_flow != null:
		return game_flow == flow and flow.is_setup()
	if not flow.setup(self, game_state):
		return false
	game_flow = flow
	return true


func start_game_flow() -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	if not is_game_authority():
		return false
	if game_flow == null or not is_instance_valid(game_flow):
		return false
	return game_flow.start()


func notify_gameplay_ready() -> bool:
	if lifecycle_state != LifecycleState.STARTING:
		return false
	if not is_game_authority():
		return false
	if game_flow == null or not is_instance_valid(game_flow) or not game_flow.is_started():
		return false
	return game_flow.on_gameplay_ready()


func bind_runtime_root(root: Node) -> bool:
	if not _can_bind_framework_node(root):
		return false
	if root == self or root.is_ancestor_of(self):
		return false
	if runtime_root != null and runtime_root != root:
		return false
	runtime_root = root
	return true


func register_player_state(player_state: PlayerState) -> bool:
	if not _can_bind_framework_node(player_state):
		return false
	if not player_state.is_initialized():
		return false
	var player_id: int = player_state.player_id
	if player_id <= INVALID_PLAYER_ID:
		return false
	if _player_states.has(player_id):
		return _player_states[player_id] == player_state

	_player_states[player_id] = player_state
	return true


func unregister_player_state(player_id: int) -> bool:
	if not _player_states.has(player_id):
		return false
	_player_runtimes.erase(player_id)
	_player_states.erase(player_id)
	return true


func bind_player_runtime(player_id: int, player: Node) -> bool:
	if not _can_bind_framework_node(player):
		return false
	if get_player_state(player_id) == null:
		return false
	if _player_runtimes.has(player_id):
		return _player_runtimes[player_id] == player

	_player_runtimes[player_id] = player
	return true


func unbind_player_runtime(player_id: int) -> bool:
	return _player_runtimes.erase(player_id)


func get_player_state(player_id: int) -> PlayerState:
	if not _player_states.has(player_id):
		return null
	var value: Variant = _player_states[player_id]
	if value is PlayerState and is_instance_valid(value):
		return value as PlayerState
	_player_states.erase(player_id)
	_player_runtimes.erase(player_id)
	return null


func get_player_states() -> Array[PlayerState]:
	var states: Array[PlayerState] = []
	for key: Variant in _player_states.keys():
		var state := get_player_state(int(key))
		if state != null:
			states.append(state)
	return states


func get_player_runtime(player_id: int) -> Node:
	return _get_valid_registered_node(_player_runtimes, player_id)


func has_player(player_id: int) -> bool:
	return get_player_state(player_id) != null


func can_process_player_request(player_id: int) -> bool:
	if not _can_dispatch_active_game_event():
		return false
	return has_player(player_id)


func notify_player_joined(player_id: int) -> bool:
	if lifecycle_state not in [LifecycleState.STARTING, LifecycleState.ACTIVE]:
		return false
	if not is_game_authority():
		return false
	if game_state == null or game_state.phase == GameState.GamePhase.ENDED:
		return false
	if game_flow == null or not is_instance_valid(game_flow) or not game_flow.is_started():
		return false
	var player_state := get_player_state(player_id)
	if player_state == null:
		return false
	return game_flow.on_player_joined(player_state)


func notify_player_died(player_id: int, context: Variant = null) -> bool:
	if not can_process_player_request(player_id):
		return false
	var player_state := get_player_state(player_id)
	if player_state == null or not player_state.alive:
		return false
	if not player_state.set_alive(false):
		return false
	return game_flow.on_player_died(player_state, context)


func notify_boss_defeated(boss_id: StringName) -> bool:
	if not _can_dispatch_active_game_event():
		return false
	return game_flow.on_boss_defeated(boss_id)


func notify_exit_reached(player_id: int) -> bool:
	if not can_process_player_request(player_id):
		return false
	var player_state := get_player_state(player_id)
	if player_state == null:
		return false
	return game_flow.on_exit_reached(player_state)


func can_change_runtime_mode(player_id: int, target_mode: int) -> bool:
	if not can_process_player_request(player_id):
		return false
	var player_state := get_player_state(player_id)
	if player_state == null:
		return false
	return game_flow.can_change_runtime_mode(player_state, target_mode)


func dispatch_flow_event(
		event_method: StringName,
		arguments: Array = [],
		player_id: int = INVALID_PLAYER_ID,
	) -> bool:
	if not _can_dispatch_active_game_event():
		return false
	if player_id != INVALID_PLAYER_ID and not has_player(player_id):
		return false
	if not game_flow.has_method(event_method):
		return false

	game_flow.callv(event_method, arguments)
	return true


func _can_bind_framework_node(node: Node) -> bool:
	if lifecycle_state == LifecycleState.IDLE or lifecycle_state == LifecycleState.STOPPING:
		return false
	return node != null and is_instance_valid(node)


func _can_dispatch_active_game_event() -> bool:
	if lifecycle_state != LifecycleState.ACTIVE:
		return false
	if not is_game_authority():
		return false
	if game_state == null or not is_instance_valid(game_state):
		return false
	if game_state.phase == GameState.GamePhase.ENDED:
		return false
	if game_flow == null or not is_instance_valid(game_flow) or not game_flow.is_started():
		return false
	return true


func _get_valid_registered_node(registry: Dictionary, player_id: int) -> Node:
	if not registry.has(player_id):
		return null
	var value: Variant = registry[player_id]
	if value is Node and is_instance_valid(value):
		return value as Node
	registry.erase(player_id)
	return null


func _allocate_game_id() -> int:
	var allocated: int = _next_game_id
	_next_game_id += 1
	return allocated


func _on_runtime_tree_exited(game_id: int) -> void:
	_finish_stop(game_id)


func _finish_stop(game_id: int) -> void:
	if lifecycle_state != LifecycleState.STOPPING:
		return
	if game_id != current_game_id:
		return

	_clear_framework_references()
	current_game_id = INVALID_GAME_ID
	lifecycle_state = LifecycleState.IDLE
	game_stopped.emit(game_id)


func _clear_framework_references() -> void:
	game_config = null
	game_state = null
	game_flow = null
	runtime_root = null
	_player_states.clear()
	_player_runtimes.clear()
