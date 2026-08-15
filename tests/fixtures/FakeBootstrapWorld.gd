extends BootstrapWorldManager


func start_world() -> bool:
	if not is_bootstrap_configured() or is_world_started() or not is_inside_tree():
		return false

	_world_started = true
	_initial_spawn_is_ready = true
	world_runtime_started.emit(world_seed)
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		return false
	initial_spawn_ready.emit(player.position)
	return true
