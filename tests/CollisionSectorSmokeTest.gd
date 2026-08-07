extends Node

var _failures: Array[String] = []


func _ready() -> void:
	var simulation := SandSimulation.new()
	_require(simulation.has_method("get_native_api_version"), "get_native_api_version missing")
	if not _failures.is_empty():
		_finish()
		return
	_require(int(simulation.call("get_native_api_version")) >= 5, "native API must be >= 5")
	_require(simulation.has_method("erase_circle"), "erase_circle missing")
	_require(simulation.has_method("get_collision_sector_snapshot"), "sector snapshot API missing")

	simulation.call("reset_grid", 128, 128, 16)
	simulation.call("set_collision_elements", PackedInt32Array([1]))
	simulation.call("configure_collision_sectors", 64)
	_acknowledge_all(simulation)
	_require(not bool(simulation.call("has_dirty_collision_sectors")), "initial sectors should acknowledge")

	simulation.call("draw_cell", 10, 10, 1)
	var dirty: PackedInt32Array = simulation.call("get_dirty_collision_sectors", 16)
	_require(_contains_sector(dirty, Vector2i(0, 0)), "single edit should dirty sector 0,0")
	var snapshot: PackedInt32Array = simulation.call("get_collision_sector_snapshot", 0, 0, 1)
	_require(snapshot.size() >= 5, "snapshot should contain revision and a rectangle")
	_require(_snapshot_contains_rect(snapshot, Rect2i(10, 10, 1, 1)), "snapshot should contain exact 1px collision")
	var stale_revision: int = snapshot[0]
	simulation.call("draw_cell", 10, 11, 1)
	_require(
		not bool(simulation.call("acknowledge_collision_sector", 0, 0, stale_revision)),
		"stale revision acknowledgement must fail"
	)
	var current_revision: int = int(simulation.call("get_collision_sector_revision", 0, 0))
	_require(
		bool(simulation.call("acknowledge_collision_sector", 0, 0, current_revision)),
		"current revision acknowledgement should succeed"
	)

	for y: int in range(60, 68):
		for x: int in range(60, 68):
			simulation.call("draw_cell", y, x, 1)
	_acknowledge_all(simulation)
	var erase_result: PackedInt32Array = simulation.call("erase_circle", 64.0, 64.0, 3.0, 0)
	_require(not erase_result.is_empty() and erase_result[0] > 0, "native erase_circle should change cells")
	dirty = simulation.call("get_dirty_collision_sectors", 16)
	for expected: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_require(_contains_sector(dirty, expected), "boundary erase should dirty sector %s" % expected)

	_finish()


func _acknowledge_all(simulation: SandSimulation) -> void:
	var width: int = int(simulation.call("get_collision_sector_width"))
	var height: int = int(simulation.call("get_collision_sector_height"))
	for sector_y: int in range(height):
		for sector_x: int in range(width):
			var revision: int = int(simulation.call("get_collision_sector_revision", sector_x, sector_y))
			simulation.call("acknowledge_collision_sector", sector_x, sector_y, revision)


func _contains_sector(data: PackedInt32Array, expected: Vector2i) -> bool:
	for entry: int in range(int(data.size() / 3)):
		var base: int = entry * 3
		if Vector2i(data[base], data[base + 1]) == expected:
			return true
	return false


func _snapshot_contains_rect(snapshot: PackedInt32Array, expected: Rect2i) -> bool:
	for entry: int in range(int((snapshot.size() - 1) / 4)):
		var base: int = 1 + entry * 4
		var rect := Rect2i(snapshot[base], snapshot[base + 1], snapshot[base + 2], snapshot[base + 3])
		if rect == expected:
			return true
	return false


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CollisionSectorSmokeTest: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CollisionSectorSmokeTest: " + failure)
	get_tree().quit(1)
