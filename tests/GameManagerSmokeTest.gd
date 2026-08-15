extends Node

class FakeFlow:
	extends GameFlow

	var received_value: int = -1

	func _on_start() -> bool:
		return true

	func on_world_ready() -> bool:
		return transition_phase(GameState.GamePhase.PLAYING)

	func can_transition_phase(current: int, next: int) -> bool:
		return current == GameState.GamePhase.STARTING \
			and next == GameState.GamePhase.PLAYING

	func on_player_joined(player_state: PlayerState) -> bool:
		return is_registered_player_state(player_state)

	func on_test_event(value: int) -> void:
		received_value = value


var _lifecycle_events: Array[String] = []


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	manager.game_starting.connect(_on_game_starting)
	manager.game_started.connect(_on_game_started)
	manager.game_stopping.connect(_on_game_stopping)
	manager.game_stopped.connect(_on_game_stopped)

	assert(not manager.has_active_game())
	assert(manager.current_game_id == GameManager.INVALID_GAME_ID)
	assert(not manager.can_process_player_request(GameManager.LOCAL_PLAYER_ID))

	var orphan_state := PlayerState.new()
	assert(not manager.register_player_state(orphan_state))
	orphan_state.free()

	var first_game_id: int = manager.start_game()
	assert(first_game_id != GameManager.INVALID_GAME_ID)
	assert(manager.lifecycle_state == GameManager.LifecycleState.STARTING)
	assert(manager.start_game() == GameManager.INVALID_GAME_ID)

	var runtime_one := Node.new()
	runtime_one.name = "RuntimeOne"
	add_child(runtime_one)
	assert(manager.bind_runtime_root(runtime_one))
	assert(not manager.bind_runtime_root(manager))

	var flow_without_state := FakeFlow.new()
	runtime_one.add_child(flow_without_state)
	assert(not manager.bind_game_flow(flow_without_state))
	flow_without_state.queue_free()

	var game_state_one := GameState.new()
	game_state_one.name = "GameStateOne"
	assert(game_state_one.initialize(first_game_id, 123))
	runtime_one.add_child(game_state_one)
	assert(manager.bind_game_state(game_state_one))
	assert(manager.game_state == game_state_one)

	var wrong_game_state := GameState.new()
	assert(wrong_game_state.initialize(first_game_id + 100, 456))
	runtime_one.add_child(wrong_game_state)
	assert(not manager.bind_game_state(wrong_game_state))

	var player_state_one := PlayerState.new()
	player_state_one.name = "PlayerStateOne"
	assert(player_state_one.initialize(GameManager.LOCAL_PLAYER_ID))
	runtime_one.add_child(player_state_one)
	assert(manager.register_player_state(player_state_one))
	assert(manager.get_player_state(GameManager.LOCAL_PLAYER_ID) == player_state_one)
	assert(manager.get_player_states().size() == 1)

	var player_one := Node.new()
	player_one.name = "PlayerOne"
	runtime_one.add_child(player_one)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player_one))
	assert(manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID) == player_one)

	var flow_one := FakeFlow.new()
	flow_one.name = "FlowOne"
	runtime_one.add_child(flow_one)
	assert(manager.bind_game_flow(flow_one))
	assert(flow_one.is_setup())
	assert(manager.start_game_flow())
	assert(not manager.start_game_flow())
	assert(manager.notify_player_joined(GameManager.LOCAL_PLAYER_ID))

	assert(not manager.can_process_player_request(GameManager.LOCAL_PLAYER_ID))
	assert(not manager.mark_game_started(first_game_id))
	assert(manager.notify_world_ready())
	assert(game_state_one.phase == GameState.GamePhase.PLAYING)
	assert(manager.mark_game_started(first_game_id))
	assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)
	assert(manager.can_process_player_request(GameManager.LOCAL_PLAYER_ID))
	assert(not manager.can_process_player_request(999))
	assert(manager.dispatch_flow_event(&"on_test_event", [42], GameManager.LOCAL_PLAYER_ID))
	assert(flow_one.received_value == 42)
	assert(not manager.dispatch_flow_event(&"missing_event", [], GameManager.LOCAL_PLAYER_ID))
	assert(not manager.dispatch_flow_event(&"on_test_event", [7], 999))

	assert(manager.stop_game())
	assert(not manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	assert(not manager.has_active_game())
	assert(manager.current_game_id == GameManager.INVALID_GAME_ID)
	assert(manager.game_state == null)
	assert(manager.game_flow == null)
	assert(manager.runtime_root == null)
	assert(manager.get_player_state(GameManager.LOCAL_PLAYER_ID) == null)
	assert(manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID) == null)
	assert(not is_instance_valid(runtime_one))

	var second_game_id: int = manager.start_game()
	assert(second_game_id > first_game_id)

	var runtime_two := Node.new()
	runtime_two.name = "RuntimeTwo"
	add_child(runtime_two)
	assert(manager.bind_runtime_root(runtime_two))

	var game_state_two := GameState.new()
	game_state_two.name = "GameStateTwo"
	assert(game_state_two.initialize(second_game_id, 789))
	runtime_two.add_child(game_state_two)
	assert(manager.bind_game_state(game_state_two))

	var player_state_two := PlayerState.new()
	player_state_two.name = "PlayerStateTwo"
	assert(player_state_two.initialize(GameManager.LOCAL_PLAYER_ID))
	runtime_two.add_child(player_state_two)
	assert(manager.register_player_state(player_state_two))

	var flow_two := FakeFlow.new()
	flow_two.name = "FlowTwo"
	runtime_two.add_child(flow_two)
	assert(manager.bind_game_flow(flow_two))
	assert(manager.start_game_flow())
	assert(manager.notify_world_ready())
	assert(manager.mark_game_started(second_game_id))
	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	assert(_lifecycle_events == [
		"starting:%d" % first_game_id,
		"started:%d" % first_game_id,
		"stopping:%d" % first_game_id,
		"stopped:%d" % first_game_id,
		"starting:%d" % second_game_id,
		"started:%d" % second_game_id,
		"stopping:%d" % second_game_id,
		"stopped:%d" % second_game_id,
	])

	print("GameManager Smoke Test: PASS")
	get_tree().quit()


func _on_game_starting(game_id: int) -> void:
	_lifecycle_events.append("starting:%d" % game_id)


func _on_game_started(game_id: int) -> void:
	_lifecycle_events.append("started:%d" % game_id)


func _on_game_stopping(game_id: int) -> void:
	_lifecycle_events.append("stopping:%d" % game_id)


func _on_game_stopped(game_id: int) -> void:
	_lifecycle_events.append("stopped:%d" % game_id)
