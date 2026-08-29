extends Node

const GAME_FLOW_UI_SCENE := preload("res://scenes/ui/GameFlowUI.tscn")

class FakePlayerRuntime:
	extends Node
	var gold: int = 0

var _quit_accept: bool = false
var _quit_calls: int = 0


func _ready() -> void:
	await _test_flow_ui_and_summary_lifecycle()
	print("Game Flow UI Smoke Test: PASS")
	get_tree().quit()


func _test_flow_ui_and_summary_lifecycle() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var summary := GameSummary.new()
	summary.name = "GameSummary"
	add_child(summary)
	assert(summary.setup(manager))

	var ui := GAME_FLOW_UI_SCENE.instantiate() as GameFlowUI
	assert(ui != null)
	add_child(ui)
	assert(ui.setup(manager, summary, Callable(self, "_handle_quit")))

	var runtime_host := Node.new()
	runtime_host.name = "RuntimeHost"
	add_child(runtime_host)

	var first := _begin_game(manager, runtime_host, 4242)
	var first_game_id := int(first["game_id"])
	var first_state := first["state"] as GameState
	var first_player_state := first["player_state"] as PlayerState
	var first_player := first["player"] as FakePlayerRuntime
	var first_flow := first["flow"] as NormalGameFlow
	var first_root := first["root"] as Node
	assert(first_game_id != GameManager.INVALID_GAME_ID)
	assert(ui.is_start_overlay_visible())
	assert(not ui.is_transition_overlay_visible())
	assert(not ui.is_end_overlay_visible())
	assert(not summary.is_valid())

	_activate_game(manager, first_game_id)
	assert(ui.bound_game_id() == first_game_id)
	assert(not ui.is_start_overlay_visible())
	assert(not ui.is_end_overlay_visible())

	# A local Player can be dead while the global Game remains PLAYING. This must
	# never be presented as a global EndPanel.
	assert(first_player_state.set_alive(false))
	assert(first_state.phase == GameState.GamePhase.PLAYING)
	assert(not ui.is_end_overlay_visible())
	assert(first_player_state.set_alive(true))

	assert(first_flow.enter_transition())
	assert(ui.is_transition_overlay_visible())
	assert(first_flow.complete_transition())
	assert(not ui.is_transition_overlay_visible())

	first_player.gold = 345
	assert(first_state.set_depth(7))
	assert(first_state.set_elapsed_time(125.9))
	assert(first_state.statistics.set_enemies_killed(12))
	assert(first_state.statistics.set_wands_collected(4))
	assert(first_state.statistics.set_spells_collected(9))
	assert(first_state.mark_creative_used())
	assert(first_flow.end_game(GameState.GameResult.VICTORY))

	assert(summary.is_valid())
	assert(summary.game_id == first_game_id)
	assert(summary.result == GameState.GameResult.VICTORY)
	assert(summary.seed == 4242)
	assert(summary.depth == 7)
	assert(summary.gold == 345)
	assert(is_equal_approx(summary.elapsed_time, 125.9))
	assert(summary.enemies_killed == 12)
	assert(summary.wands_collected == 4)
	assert(summary.spells_collected == 9)
	assert(summary.creative_used)
	assert(ui.is_end_overlay_visible())
	assert(ui.displayed_result_title() == "VICTORY")

	var old_root_ref: WeakRef = weakref(first_root)
	var old_state_ref: WeakRef = weakref(first_state)
	var old_flow_ref: WeakRef = weakref(first_flow)
	var old_player_state_ref: WeakRef = weakref(first_player_state)
	var old_player_ref: WeakRef = weakref(first_player)

	# Restart only forwards to GameManager. GameSummary keeps its captured scalar
	# fields while the old per-game root and all runtime objects disappear.
	assert(ui.request_restart({"seed": 4242}))
	assert(ui.is_pending())
	await get_tree().process_frame
	await get_tree().process_frame
	assert(manager.lifecycle_state == GameManager.LifecycleState.IDLE)
	assert(summary.is_valid())
	assert(summary.game_id == first_game_id)
	assert(summary.gold == 345)
	assert(old_root_ref.get_ref() == null)
	assert(old_state_ref.get_ref() == null)
	assert(old_flow_ref.get_ref() == null)
	assert(old_player_state_ref.get_ref() == null)
	assert(old_player_ref.get_ref() == null)

	# Starting the next Game clears the same persistent GameSummary and then
	# rebinds the same persistent UI instance to the fresh GameState.
	var second := _begin_game(manager, runtime_host, 4242)
	var second_game_id := int(second["game_id"])
	var second_state := second["state"] as GameState
	var second_flow := second["flow"] as NormalGameFlow
	assert(second_game_id != first_game_id)
	assert(not summary.is_valid())
	assert(summary.game_id == GameState.INVALID_GAME_ID)
	assert(ui.is_start_overlay_visible())
	assert(ui.bound_game_id() == second_game_id)
	_activate_game(manager, second_game_id)
	assert(ui.bound_game_id() == second_game_id)
	assert(not ui.is_start_overlay_visible())
	assert(not ui.is_transition_overlay_visible())
	assert(not ui.is_end_overlay_visible())

	# Quit uses a Shell callback. Rejection restores operability; acceptance
	# becomes pending without directly changing GameState or reloading a scene.
	assert(second_flow.end_game(GameState.GameResult.DEFEAT))
	assert(ui.displayed_result_title() == "DEFEAT")
	_quit_accept = false
	assert(not ui.request_quit())
	assert(not ui.is_pending())
	assert(ui.status_text() == "Quit request rejected")
	assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)
	assert(second_state.phase == GameState.GamePhase.ENDED)
	_quit_accept = true
	assert(ui.request_quit())
	assert(ui.is_pending())
	assert(_quit_calls == 2)
	assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)
	assert(second_state.phase == GameState.GamePhase.ENDED)

	assert(manager.stop_game())
	await get_tree().process_frame
	await get_tree().process_frame
	assert(manager.lifecycle_state == GameManager.LifecycleState.IDLE)
	assert(runtime_host.get_child_count() == 0)

	runtime_host.queue_free()
	ui.queue_free()
	summary.queue_free()
	manager.queue_free()


func _begin_game(manager: GameManager, runtime_host: Node, seed: int) -> Dictionary:
	var config := GameConfig.create_with_seed(seed)
	assert(config != null and config.is_valid())
	var game_id := manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)

	var runtime_root := Node.new()
	runtime_root.name = "GameRuntime%d" % game_id
	runtime_host.add_child(runtime_root)
	assert(manager.bind_runtime_root(runtime_root))

	var state := GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, seed))
	runtime_root.add_child(state)
	assert(manager.bind_game_state(state))

	var player_state := PlayerState.new()
	player_state.name = "PlayerState1"
	assert(player_state.initialize(GameManager.LOCAL_PLAYER_ID))
	runtime_root.add_child(player_state)
	assert(manager.register_player_state(player_state))

	var player := FakePlayerRuntime.new()
	player.name = "Player"
	runtime_root.add_child(player)
	assert(manager.bind_player_runtime(GameManager.LOCAL_PLAYER_ID, player))

	var flow := NormalGameFlow.new()
	flow.name = "NormalGameFlow"
	runtime_root.add_child(flow)
	assert(manager.bind_game_flow(flow))
	assert(manager.start_game_flow())

	return {
		"game_id": game_id,
		"root": runtime_root,
		"state": state,
		"player_state": player_state,
		"player": player,
		"flow": flow,
	}


func _activate_game(manager: GameManager, game_id: int) -> void:
	assert(manager.notify_gameplay_ready())
	assert(manager.mark_game_started(game_id))


func _handle_quit(_player_id: int) -> bool:
	_quit_calls += 1
	return _quit_accept
