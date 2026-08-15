extends Node

@onready var _game_manager: GameManager = $GameManager
@onready var _initial_runtime_root: Node = $GameRuntime


func _ready() -> void:
	# Transitional bootstrap for #34/#35. #35 will replace this with GameConfig,
	# authoritative seed injection and real readiness aggregation.
	var game_id: int = _game_manager.start_game()
	if game_id == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game runtime.")
		return
	if not _game_manager.bind_runtime_root(_initial_runtime_root):
		push_error("Failed to bind the initial game runtime root.")
		return
	if not _bind_initial_framework(game_id):
		return

	# World.tscn currently performs its own setup during _ready(). Defer the
	# compatibility readiness event until the existing scene startup finishes.
	# #35 will replace this with explicit World / Spawn readiness conditions.
	_mark_initial_game_started.call_deferred(game_id)


func _bind_initial_framework(game_id: int) -> bool:
	var state := GameState.new()
	state.name = "GameState"
	if not state.initialize(game_id, 0):
		state.free()
		push_error("Failed to initialize GameState.")
		return false
	_initial_runtime_root.add_child(state)
	if not _game_manager.bind_game_state(state):
		state.queue_free()
		push_error("Failed to bind GameState.")
		return false

	var player_state := PlayerState.new()
	player_state.name = "PlayerState%d" % GameManager.LOCAL_PLAYER_ID
	if not player_state.initialize(GameManager.LOCAL_PLAYER_ID):
		player_state.free()
		push_error("Failed to initialize local PlayerState.")
		return false
	_initial_runtime_root.add_child(player_state)
	if not _game_manager.register_player_state(player_state):
		player_state.queue_free()
		push_error("Failed to register local PlayerState.")
		return false

	var player_runtime: Node = _initial_runtime_root.get_node_or_null("World/Player")
	if player_runtime == null:
		push_error("Failed to resolve the initial Player runtime.")
		return false
	if not _game_manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player_runtime):
		push_error("Failed to bind the initial Player runtime.")
		return false

	var flow := NormalGameFlow.new()
	flow.name = "NormalGameFlow"
	_initial_runtime_root.add_child(flow)
	if not _game_manager.bind_game_flow(flow):
		flow.queue_free()
		push_error("Failed to bind NormalGameFlow.")
		return false
	if not _game_manager.start_game_flow():
		push_error("Failed to start NormalGameFlow.")
		return false
	if not _game_manager.notify_player_joined(GameManager.LOCAL_PLAYER_ID):
		push_error("Failed to notify NormalGameFlow about the local player.")
		return false

	return true


func _mark_initial_game_started(game_id: int) -> void:
	if _game_manager.current_game_id != game_id:
		return
	if not _game_manager.notify_world_ready():
		push_error("NormalGameFlow rejected initial world readiness.")
		return
	if not _game_manager.mark_game_started(game_id):
		push_error("Failed to activate the initial game.")
