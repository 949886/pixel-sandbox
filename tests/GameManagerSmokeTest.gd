extends Node

class FakeFlow:
	extends Node

	var received_value: int = -1

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

	var orphan_state := Node.new()
	assert(not manager.register_player_state(GameManager.LOCAL_PLAYER_ID, orphan_state))
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

	var state_one := Node.new()
	state_one.name = "PlayerStateOne"
	runtime_one.add_child(state_one)
	assert(manager.register_player_state(GameManager.LOCAL_PLAYER_ID, state_one))
	assert(manager.get_player_state(GameManager.LOCAL_PLAYER_ID) == state_one)

	var player_one := Node.new()
	player_one.name = "PlayerOne"
	runtime_one.add_child(player_one)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player_one))
	assert(manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID) == player_one)

	var flow_one := FakeFlow.new()
	flow_one.name = "FlowOne"
	runtime_one.add_child(flow_one)
	assert(manager.bind_game_flow(flow_one))

	assert(not manager.can_process_player_request(GameManager.LOCAL_PLAYER_ID))
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

	var state_two := Node.new()
	state_two.name = "PlayerStateTwo"
	runtime_two.add_child(state_two)
	assert(manager.register_player_state(GameManager.LOCAL_PLAYER_ID, state_two))

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
