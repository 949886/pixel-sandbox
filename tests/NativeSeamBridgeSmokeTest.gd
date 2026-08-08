extends Node

var _failures: Array[String] = []

func _ready() -> void:
	var top := SandSimulation.new()
	var bottom := SandSimulation.new()
	_require(top.has_method("exchange_border_with"), "exchange_border_with missing")
	_require(top.has_method("get_border_flow_activity_mask"), "get_border_flow_activity_mask missing")
	_require(int(top.call("get_native_api_version")) >= 9, "native API must be >= 9")
	if not _failures.is_empty():
		_finish()
		return

	_configure(top)
	_configure(bottom)
	top.call("draw_cell", 7, 3, 3) # water
	var result: PackedInt32Array = top.call("exchange_border_with", bottom, 2, 0)
	_require(result.size() >= 5 and result[0] > 0, "water should cross bottom seam")
	_require(_count_type(top, 3) + _count_type(bottom, 3) == 1, "water mass must be conserved")
	_require(_row_contains(bottom, 0, 3), "water should enter neighbor top row")

	_configure(top)
	_configure(bottom)
	bottom.call("draw_cell", 0, 4, 6) # smoke
	result = top.call("exchange_border_with", bottom, 2, 1)
	_require(result[0] > 0 and _row_contains(top, 7, 6), "smoke should rise across top/bottom seam")

	var left := SandSimulation.new()
	var right := SandSimulation.new()
	_configure(left)
	_configure(right)
	left.call("draw_cell", 5, 7, 6)
	result = left.call("exchange_border_with", right, 1, 2)
	_require(result[0] > 0 and _column_contains(right, 0, 6), "smoke should cross horizontal seam")

	_configure(left)
	_configure(right)
	left.call("draw_cell", 4, 7, 3)
	result = left.call("exchange_border_with", right, 1, 3)
	_require(result[0] > 0 and _column_contains(right, 0, 3), "water should cross horizontal seam")

	_finish()

func _configure(simulation: SandSimulation) -> void:
	simulation.call("reset_grid", 8, 8, 4)
	var flow_states := PackedInt32Array()
	flow_states.resize(4097)
	flow_states.fill(-1)
	flow_states[1] = 0 # built-in sand explicit powder override
	simulation.call("set_flow_states", flow_states)

func _count_type(simulation: SandSimulation, element_id: int) -> int:
	var count: int = 0
	for y: int in range(8):
		for x: int in range(8):
			if int(simulation.call("get_cell", y, x)) == element_id:
				count += 1
	return count

func _row_contains(simulation: SandSimulation, row: int, element_id: int) -> bool:
	for x: int in range(8):
		if int(simulation.call("get_cell", row, x)) == element_id:
			return true
	return false

func _column_contains(simulation: SandSimulation, column: int, element_id: int) -> bool:
	for y: int in range(8):
		if int(simulation.call("get_cell", y, column)) == element_id:
			return true
	return false

func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("NativeSeamBridgeSmokeTest: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("NativeSeamBridgeSmokeTest: " + failure)
	get_tree().quit(1)
