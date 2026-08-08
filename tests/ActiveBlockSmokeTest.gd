extends Node

var _failures: Array[String] = []

func _ready() -> void:
	var sim := SandSimulation.new()
	_require(sim.has_method("set_activity_modes"), "set_activity_modes missing")
	_require(sim.has_method("get_block_stats"), "get_block_stats missing")
	_require(sim.has_method("get_block_states"), "get_block_states missing")
	_require(int(sim.call("get_native_api_version")) >= 10, "native API must be >= 10")
	if not _failures.is_empty():
		_finish()
		return

	_configure(sim, 32, 16)
	for x: int in range(32):
		sim.call("draw_cell", 15, x, 15) # Wall, explicitly INERT for this test.
	for _tick: int in range(4):
		sim.call("step", 1)
	var stats: PackedInt32Array = sim.call("get_block_stats")
	_require(stats.size() >= 12, "block stats layout missing")
	_require(stats[1] == 2, "32x16 / 16 should create two blocks")
	_require(stats[2] == 0 and stats[4] == 2, "stable inert blocks should sleep")

	# Remove one boundary-adjacent wall pixel. 3x3 neighborhood wake should make
	# both still-occupied blocks run on the next logical tick.
	sim.call("draw_cell", 15, 15, 0)
	sim.call("step", 1)
	stats = sim.call("get_block_stats")
	_require(stats[7] == 2, "external edit should wake both neighboring blocks")

	# A deterministic no-op element classified MOVABLE may settle and sleep.
	_configure(sim, 16, 16)
	sim.call("draw_cell", 8, 8, 25) # Glass process is empty.
	for _tick: int in range(4):
		sim.call("step", 1)
	var states: PackedByteArray = sim.call("get_block_states")
	_require(states.size() == 1 and states[0] == 2, "isolated stable movable block should sleep")

	_finish()

func _configure(simulation: SandSimulation, width: int, height: int) -> void:
	simulation.call("reset_grid", width, height, 16)
	var modes := PackedInt32Array()
	modes.resize(4097)
	modes.fill(4) # Safe default: AUTONOMOUS.
	modes[0] = 1 # INERT
	modes[15] = 1 # Wall -> INERT for deterministic test
	modes[25] = 2 # Glass -> MOVABLE for deterministic settle test
	simulation.call("set_activity_modes", modes)
	simulation.call("set_block_sleep_after_quiet_ticks", 4)

func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("ActiveBlockSmokeTest: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("ActiveBlockSmokeTest: " + failure)
	get_tree().quit(1)
