extends Node


class FakePlayerRuntime:
	extends Node

	var spawn_position := Vector2(12.0, 34.0)
	var current_position := spawn_position
	var respawn_count: int = 0

	func get_spawn_position() -> Vector2:
		return spawn_position

	func respawn_at(position: Vector2, _options: Dictionary = {}) -> bool:
		current_position = position
		respawn_count += 1
		return true


var _restart_count: int = 0
var _restart_game_id: int = GameManager.INVALID_GAME_ID
var _restart_player_id: int = GameManager.INVALID_PLAYER_ID
var _restart_options: Dictionary = {}


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)
	manager.restart_requested.connect(_on_restart_requested)

	var first := _create_active_game(manager, 4201)
	var first_game_id: int = first["game_id"]
	var first_state: GameState = first["state"] as GameState
	var player_state: PlayerState = first["player_state"] as PlayerState
	var player_runtime: FakePlayerRuntime = first["player_runtime"] as FakePlayerRuntime

	assert(manager.current_game_id == first_game_id)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(player_state.alive)
	assert(not manager.request_restart(GameManager.LOCAL_PLAYER_ID))

	# The stable player_id is authoritative only together with the currently
	# registered runtime identity. A stale object cannot report death for it.
	var stale_runtime := FakePlayerRuntime.new()
	stale_runtime.name = "StalePlayerRuntime"
	add_child(stale_runtime)
	assert(not manager.notify_player_died(
		GameManager.LOCAL_PLAYER_ID,
		{"cause": &"stale_runtime"},
		stale_runtime,
	))
	assert(player_state.alive)
	stale_runtime.queue_free()

	# Creative recovery is explicit and stays inside the same Game.
	player_runtime.current_position = Vector2(90.0, 50.0)
	assert(manager.request_runtime_mode(
		GameManager.LOCAL_PLAYER_ID,
		GameState.RuntimeMode.CREATIVE,
	))
	assert(manager.notify_player_died(
		GameManager.LOCAL_PLAYER_ID,
		{"cause": &"creative_death"},
		player_runtime,
	))
	assert(manager.current_game_id == first_game_id)
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(player_state.alive)
	assert(player_runtime.respawn_count == 1)
	assert(player_runtime.current_position == player_runtime.spawn_position)
	assert(not manager.request_player_recovery(GameManager.LOCAL_PLAYER_ID))

	# The same death in Normal ends a one-player Game. Once ENDED, neither
	# recovery nor RuntimeMode requests are allowed to revive gameplay.
	assert(manager.request_runtime_mode(
		GameManager.LOCAL_PLAYER_ID,
		GameState.RuntimeMode.NORMAL,
	))
	assert(manager.notify_player_died(
		GameManager.LOCAL_PLAYER_ID,
		{"cause": &"normal_death"},
		player_runtime,
	))
	assert(not player_state.alive)
	assert(first_state.phase == GameState.GamePhase.ENDED)
	assert(first_state.result == GameState.GameResult.DEFEAT)
	assert(not manager.request_player_recovery(GameManager.LOCAL_PLAYER_ID))
	assert(not manager.request_runtime_mode(
		GameManager.LOCAL_PLAYER_ID,
		GameState.RuntimeMode.CREATIVE,
	))
	assert(player_runtime.respawn_count == 1)

	# Restart is a separate authority request from ordinary gameplay events. It
	# accepts only an ENDED Game, stops the old Game first, and lifecycle state
	# itself rejects duplicate restart requests. Runtime rebuild belongs to #4.
	assert(not manager.request_restart(999))
	assert(not manager.request_restart(GameManager.LOCAL_PLAYER_ID, {"seed": "bad"}))
	assert(manager.request_restart(GameManager.LOCAL_PLAYER_ID, {"seed": 4202}))
	assert(_restart_count == 1)
	assert(_restart_game_id == first_game_id)
	assert(_restart_player_id == GameManager.LOCAL_PLAYER_ID)
	assert(_restart_options.get("seed") == 4202)
	assert(manager.lifecycle_state == GameManager.LifecycleState.IDLE)
	assert(manager.current_game_id == GameManager.INVALID_GAME_ID)
	assert(not manager.request_restart(GameManager.LOCAL_PLAYER_ID, {"seed": 4203}))
	assert(_restart_count == 1)

	# A restart continuation creates a new Game identity and new public state.
	# The actual per-game runtime root reconstruction is intentionally #4 scope.
	var second_config := GameConfig.create_with_seed(4202)
	var second_game_id := manager.start_game(second_config)
	assert(second_game_id != GameManager.INVALID_GAME_ID)
	assert(second_game_id != first_game_id)
	var second_state := GameState.new()
	second_state.name = "SecondGameState"
	assert(second_state.initialize(second_game_id, second_config.seed))
	add_child(second_state)
	assert(manager.bind_game_state(second_state))
	assert(second_state.phase == GameState.GamePhase.STARTING)
	assert(second_state.result == GameState.GameResult.NONE)
	assert(second_state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not second_state.used_creative_mode)

	assert(manager.stop_game())
	assert(manager.lifecycle_state == GameManager.LifecycleState.IDLE)

	print("Game Death Restart Smoke Test: PASS")
	get_tree().quit()


func _create_active_game(manager: GameManager, seed: int) -> Dictionary:
	var config := GameConfig.create_with_seed(seed)
	var game_id := manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)

	var state := GameState.new()
	state.name = "GameState%d" % game_id
	assert(state.initialize(game_id, seed))
	add_child(state)
	assert(manager.bind_game_state(state))

	var player_state := PlayerState.new()
	player_state.name = "PlayerState%d" % GameManager.LOCAL_PLAYER_ID
	assert(player_state.initialize(GameManager.LOCAL_PLAYER_ID))
	add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player_runtime := FakePlayerRuntime.new()
	player_runtime.name = "PlayerRuntime%d" % GameManager.LOCAL_PLAYER_ID
	add_child(player_runtime)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player_runtime))

	var flow := NormalGameFlow.new()
	flow.name = "NormalGameFlow%d" % game_id
	add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(manager.start_game_flow())
	assert(manager.notify_player_joined(GameManager.LOCAL_PLAYER_ID))
	assert(manager.notify_gameplay_ready())
	assert(manager.mark_game_started(game_id))

	return {
		"game_id": game_id,
		"state": state,
		"player_state": player_state,
		"player_runtime": player_runtime,
		"flow": flow,
	}


func _on_restart_requested(
		previous_game_id: int,
		player_id: int,
		options: Dictionary,
	) -> void:
	_restart_count += 1
	_restart_game_id = previous_game_id
	_restart_player_id = player_id
	_restart_options = options.duplicate(true)
