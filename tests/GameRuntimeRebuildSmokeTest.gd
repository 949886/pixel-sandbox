extends Node

const TEST_WORLD_SCENE: PackedScene = preload("res://tests/fixtures/RuntimeRebuildTestWorld.tscn")
const DEFAULT_LOADOUT: StartingLoadoutDef = preload(
	"res://resources/gameplay/loadouts/default_starting_loadout.tres"
)
const GAMEPLAY_CONTENT: GameplayContentDB = preload("res://resources/gameplay/gameplay_content.tres")
const RESTART_COUNT: int = 5


func _ready() -> void:
	await _run_runtime_rebuild_stress()
	print("Game Runtime Rebuild Smoke Test: PASS")
	get_tree().quit()


func _run_runtime_rebuild_stress() -> void:
	RuntimeRebuildTestWorld.reset_probe()

	var manager := GameManager.new()
	manager.name = "GameManager"
	add_child(manager)

	var bootstrap := GameBootstrap.new()
	bootstrap.name = "GameBootstrap"
	bootstrap.world_scene = TEST_WORLD_SCENE
	bootstrap.world_gen_config_template = WorldGenConfig.new()
	bootstrap.gameplay_content = GAMEPLAY_CONTENT
	add_child(bootstrap)

	var runtime_host := Node2D.new()
	runtime_host.name = "GameRuntimeHost"
	add_child(runtime_host)
	assert(bootstrap.setup(manager, runtime_host))

	var first_config := GameConfig.create_with_seed(
		7001,
		GAMEPLAY_CONTENT.default_flow_id,
		DEFAULT_LOADOUT,
	)
	var first_game_id := bootstrap.start_game(first_config)
	assert(first_game_id != GameManager.INVALID_GAME_ID)
	var started_game_id: int = await manager.game_started
	assert(started_game_id == first_game_id)

	var previous_game_id := first_game_id
	for restart_index: int in range(RESTART_COUNT):
		assert(manager.lifecycle_state == GameManager.LifecycleState.ACTIVE)
		assert(manager.current_game_id == previous_game_id)
		assert(runtime_host.get_child_count() == 1)

		var old_root := manager.runtime_root
		var old_state := manager.game_state
		var old_flow := manager.game_flow
		var old_player_state := manager.get_player_state(GameManager.LOCAL_PLAYER_ID)
		var old_player := manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID) as Player
		var old_world := old_root.get_node_or_null("RuntimeRebuildWorld")
		assert(old_root != null)
		assert(old_state != null)
		assert(old_flow != null)
		assert(old_player_state != null)
		assert(old_player != null)
		assert(old_world != null)
		assert(int(old_root.get_meta(&"game_id", GameManager.INVALID_GAME_ID)) == previous_game_id)

		var old_root_ref := weakref(old_root)
		var old_state_ref := weakref(old_state)
		var old_flow_ref := weakref(old_flow)
		var old_player_state_ref := weakref(old_player_state)
		var old_player_ref := weakref(old_player)
		var old_world_ref := weakref(old_world)

		# Mutate representative per-game state. None of it may survive the
		# destroy-and-rebuild boundary.
		old_world.set("mutable_marker", 100 + restart_index)
		old_player.add_gold(50 + restart_index)
		if restart_index % 2 == 0:
			assert(manager.request_runtime_mode(
				GameManager.LOCAL_PLAYER_ID,
				GameState.RuntimeMode.CREATIVE,
			))
			assert(manager.game_state.used_creative_mode)
			assert(manager.request_runtime_mode(
				GameManager.LOCAL_PLAYER_ID,
				GameState.RuntimeMode.NORMAL,
			))

		assert(manager.notify_player_died(
			GameManager.LOCAL_PLAYER_ID,
			{"cause": &"runtime_rebuild_smoke"},
			old_player,
		))
		assert(manager.game_state.phase == GameState.GamePhase.ENDED)
		assert(manager.game_state.result == GameState.GameResult.DEFEAT)

		# The first restart deliberately reuses the same seed. Fresh object
		# identity must not depend on seed identity.
		var next_seed := 7001 if restart_index == 0 else 7001 + restart_index
		assert(manager.request_restart(
			GameManager.LOCAL_PLAYER_ID,
			{"seed": next_seed},
		))
		assert(manager.lifecycle_state == GameManager.LifecycleState.STOPPING)
		assert(runtime_host.get_child_count() == 1)

		var next_game_id: int = await manager.game_started
		assert(next_game_id != previous_game_id)
		assert(manager.current_game_id == next_game_id)
		assert(manager.game_config.seed == next_seed)
		assert(runtime_host.get_child_count() == 1)

		# By the time the replacement Game becomes ACTIVE, the old runtime tree
		# and every framework/runtime object owned by it must be gone.
		assert(old_root_ref.get_ref() == null)
		assert(old_state_ref.get_ref() == null)
		assert(old_flow_ref.get_ref() == null)
		assert(old_player_state_ref.get_ref() == null)
		assert(old_player_ref.get_ref() == null)
		assert(old_world_ref.get_ref() == null)

		var new_root := manager.runtime_root
		var new_state := manager.game_state
		var new_player_state := manager.get_player_state(GameManager.LOCAL_PLAYER_ID)
		var new_player := manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID) as Player
		var new_world := new_root.get_node_or_null("RuntimeRebuildWorld")
		assert(new_root != null and new_root != old_root)
		assert(new_state != null and new_state != old_state)
		assert(manager.game_flow != null and manager.game_flow != old_flow)
		assert(new_player_state != null and new_player_state != old_player_state)
		assert(new_player != null and new_player != old_player)
		assert(new_world != null and new_world != old_world)
		assert(int(new_root.get_meta(&"game_id", GameManager.INVALID_GAME_ID)) == next_game_id)
		assert(new_state.phase == GameState.GamePhase.PLAYING)
		assert(new_state.result == GameState.GameResult.NONE)
		assert(new_state.runtime_mode == GameState.RuntimeMode.NORMAL)
		assert(not new_state.used_creative_mode)
		assert(new_player_state.alive)
		assert(int(new_player.get("gold")) == DEFAULT_LOADOUT.gold)
		assert(int(new_world.get("mutable_marker")) == 0)

		# A stale async callback tagged with the previous game_id must not be
		# allowed to mark the current Player dead.
		bootstrap._on_player_runtime_died(
			GameManager.LOCAL_PLAYER_ID,
			{"cause": &"stale_callback"},
			new_player,
			previous_game_id,
		)
		assert(new_player_state.alive)

		previous_game_id = next_game_id

	# Explicit stop uses the same per-game root boundary without requesting a
	# replacement. The persistent host and framework owners remain.
	var final_game_id := manager.current_game_id
	assert(manager.stop_game())
	await manager.game_stopped
	assert(manager.lifecycle_state == GameManager.LifecycleState.IDLE)
	assert(manager.current_game_id == GameManager.INVALID_GAME_ID)
	assert(runtime_host.get_child_count() == 0)
	assert(is_instance_valid(manager))
	assert(is_instance_valid(bootstrap))
	assert(is_instance_valid(runtime_host))

	# Every created test World reached _exit_tree before the test completed.
	var ready_count := 0
	var exit_count := 0
	for event: Variant in RuntimeRebuildTestWorld.event_log:
		var text := str(event)
		if text.begins_with("ready:"):
			ready_count += 1
		elif text.begins_with("exit:"):
			exit_count += 1
	assert(ready_count == RESTART_COUNT + 1)
	assert(exit_count == ready_count)
	assert(final_game_id == previous_game_id)
