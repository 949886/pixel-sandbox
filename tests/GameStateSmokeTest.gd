extends Node

var _phase_events: Array[String] = []
var _result_events: Array[String] = []
var _mode_events: Array[String] = []
var _creative_usage_events: Array[bool] = []
var _player_alive_events: Array[String] = []


func _ready() -> void:
	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var config := GameConfig.create_with_seed(24680)
	var game_id: int = manager.start_game(config)
	assert(game_id != GameManager.INVALID_GAME_ID)

	var runtime := Node.new()
	runtime.name = "StateRuntime"
	add_child(runtime)
	assert(manager.bind_runtime_root(runtime))

	var state := GameState.new()
	state.name = "GameState"
	assert(state.initialize(game_id, 24680))
	assert(not state.initialize(game_id, 11111))
	runtime.add_child(state)
	assert(manager.bind_game_state(state))

	assert(state.game_id == game_id)
	assert(state.game_seed == 24680)
	assert(state.phase == GameState.GamePhase.STARTING)
	assert(state.result == GameState.GameResult.NONE)
	assert(state.runtime_mode == GameState.RuntimeMode.NORMAL)
	assert(not state.used_creative_mode)
	assert(state.current_depth == 0)
	assert(state.current_biome == GameState.DEFAULT_BIOME)
	assert(is_equal_approx(state.elapsed_time, 0.0))

	state.phase_changed.connect(_on_phase_changed)
	state.result_changed.connect(_on_result_changed)
	state.runtime_mode_changed.connect(_on_runtime_mode_changed)
	state.creative_usage_changed.connect(_on_creative_usage_changed)

	assert(state.set_phase(GameState.GamePhase.PLAYING))
	assert(not state.set_phase(999))

	# GameState validates values, not game-flow policy. Result and phase can be
	# changed independently; GameFlow owns legal transition rules.
	assert(state.set_result(GameState.GameResult.VICTORY))
	assert(state.phase == GameState.GamePhase.PLAYING)

	assert(state.set_runtime_mode(GameState.RuntimeMode.CREATIVE))
	assert(state.used_creative_mode)
	assert(state.set_runtime_mode(GameState.RuntimeMode.NORMAL))
	assert(state.used_creative_mode)

	assert(state.set_depth(4))
	assert(not state.set_depth(-1))
	assert(state.set_biome(&"mine_deep"))
	assert(state.set_elapsed_time(12.5))
	assert(state.advance_elapsed_time(2.5))
	assert(not state.advance_elapsed_time(-1.0))
	assert(is_equal_approx(state.elapsed_time, 15.0))

	assert(state.statistics.record_enemy_killed(3))
	assert(state.statistics.record_wand_collected(2))
	assert(state.statistics.record_spell_collected(5))
	assert(not state.statistics.record_enemy_killed(0))

	var player_a := PlayerState.new()
	player_a.name = "PlayerStateA"
	assert(player_a.initialize(1, 11))
	runtime.add_child(player_a)
	assert(manager.register_player_state(player_a))
	player_a.alive_changed.connect(_on_player_alive_changed.bind(player_a.player_id))

	var player_b := PlayerState.new()
	player_b.name = "PlayerStateB"
	assert(player_b.initialize(2, 22))
	runtime.add_child(player_b)
	assert(manager.register_player_state(player_b))
	player_b.alive_changed.connect(_on_player_alive_changed.bind(player_b.player_id))

	assert(manager.get_player_states().size() == 2)
	assert(manager.get_player_state(1) == player_a)
	assert(manager.get_player_state(2) == player_b)
	assert(player_a.set_alive(false))
	assert(not player_a.alive)
	assert(player_b.alive)
	assert(state.phase == GameState.GamePhase.PLAYING)

	# Even if both public PlayerStates are dead, GameState does not end itself.
	# GameFlow decides that policy.
	assert(player_b.set_alive(false))
	assert(state.phase == GameState.GamePhase.PLAYING)
	assert(player_b.set_alive(true))
	assert(player_b.set_peer_id(33))
	assert(player_b.peer_id == 33)

	var state_snapshot: Dictionary = state.to_dictionary()
	assert(state_snapshot["game_id"] == game_id)
	assert(state_snapshot["game_seed"] == 24680)
	var statistics_snapshot: Dictionary = state_snapshot["statistics"]
	assert(statistics_snapshot["enemies_killed"] == 3)

	assert(state.set_phase(GameState.GamePhase.ENDED))
	var summary := GameSummary.new()
	summary.name = "GameSummary"
	add_child(summary)
	assert(summary.capture_from_state(state, 77))
	assert(summary.game_id == game_id)
	assert(summary.result == GameState.GameResult.VICTORY)
	assert(summary.seed == 24680)
	assert(summary.depth == 4)
	assert(summary.gold == 77)
	assert(is_equal_approx(summary.elapsed_time, 15.0))
	assert(summary.enemies_killed == 3)
	assert(summary.wands_collected == 2)
	assert(summary.spells_collected == 5)
	assert(summary.used_creative_mode)

	var summary_dictionary: Dictionary = summary.to_dictionary()
	assert(summary_dictionary["seed"] == 24680)
	assert(summary_dictionary["gold"] == 77)

	var runtime_ref: WeakRef = weakref(runtime)
	var state_ref: WeakRef = weakref(state)
	var player_a_ref: WeakRef = weakref(player_a)
	var player_b_ref: WeakRef = weakref(player_b)

	# This test intentionally has no GameFlow. Stopping from STARTING is valid and
	# keeps public-state lifecycle tests independent from flow activation.
	assert(manager.stop_game())
	if manager.lifecycle_state != GameManager.LifecycleState.IDLE:
		await manager.game_stopped

	assert(runtime_ref.get_ref() == null)
	assert(state_ref.get_ref() == null)
	assert(player_a_ref.get_ref() == null)
	assert(player_b_ref.get_ref() == null)

	# GameSummary stores only scalar snapshot data and therefore survives
	# destruction of the source GameState, PlayerState and runtime nodes.
	assert(summary.game_id == game_id)
	assert(summary.seed == 24680)
	assert(summary.gold == 77)
	assert(summary.enemies_killed == 3)

	assert(_phase_events == [
		"%d->%d" % [GameState.GamePhase.STARTING, GameState.GamePhase.PLAYING],
		"%d->%d" % [GameState.GamePhase.PLAYING, GameState.GamePhase.ENDED],
	])
	assert(_result_events == [
		"%d->%d" % [GameState.GameResult.NONE, GameState.GameResult.VICTORY],
	])
	assert(_mode_events == [
		"%d->%d" % [GameState.RuntimeMode.NORMAL, GameState.RuntimeMode.CREATIVE],
		"%d->%d" % [GameState.RuntimeMode.CREATIVE, GameState.RuntimeMode.NORMAL],
	])
	assert(_creative_usage_events == [true])
	assert(_player_alive_events == ["1:true->false", "2:true->false", "2:false->true"])

	summary.queue_free()
	print("Game State Smoke Test: PASS")
	get_tree().quit()


func _on_phase_changed(previous: GameState.GamePhase, current: GameState.GamePhase) -> void:
	_phase_events.append("%d->%d" % [previous, current])


func _on_result_changed(previous: GameState.GameResult, current: GameState.GameResult) -> void:
	_result_events.append("%d->%d" % [previous, current])


func _on_runtime_mode_changed(previous: GameState.RuntimeMode, current: GameState.RuntimeMode) -> void:
	_mode_events.append("%d->%d" % [previous, current])


func _on_creative_usage_changed(used_creative_mode: bool) -> void:
	_creative_usage_events.append(used_creative_mode)


func _on_player_alive_changed(previous: bool, current: bool, player_id: int) -> void:
	_player_alive_events.append("%d:%s->%s" % [player_id, str(previous).to_lower(), str(current).to_lower()])
