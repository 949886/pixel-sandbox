class_name GameModeManager
extends Node

signal mode_changed(mode: int)
signal creative_rules_changed(rules: GameRules)

enum Mode {
	NORMAL = GameState.RuntimeMode.NORMAL,
	CREATIVE = GameState.RuntimeMode.CREATIVE,
}

@export var creative_rules: GameRules

var _input_captures: Array[WeakRef] = []
var _game_manager: GameManager = null
var _game_state: GameState = null

var current_mode: int:
	get:
		return _game_state.runtime_mode if _game_state != null else GameState.RuntimeMode.NORMAL
	set(value):
		set_mode(value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_mode_manager")
	_ensure_toggle_action()
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	_bind_game_state()
	_apply_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_creative"):
		toggle_mode()
		get_viewport().set_input_as_handled()


func toggle_mode() -> void:
	set_mode(Mode.NORMAL if is_creative() else Mode.CREATIVE)


func set_mode(mode: int) -> void:
	_bind_game_state()
	if _game_manager == null or _game_state == null:
		return
	var resolved: int = Mode.CREATIVE if mode == Mode.CREATIVE else Mode.NORMAL
	_game_manager.request_runtime_mode(GameManager.LOCAL_PLAYER_ID, resolved)


func is_creative() -> bool:
	_bind_game_state()
	return _game_state != null and _game_state.runtime_mode == GameState.RuntimeMode.CREATIVE


func register_input_capture(node: Node) -> void:
	if node == null:
		return
	_cleanup_input_captures()
	for reference: WeakRef in _input_captures:
		if reference.get_ref() == node:
			return
	_input_captures.append(weakref(node))


func unregister_input_capture(node: Node) -> void:
	for index: int in range(_input_captures.size() - 1, -1, -1):
		var target: Variant = _input_captures[index].get_ref()
		if target == null or target == node:
			_input_captures.remove_at(index)


func gameplay_action_blocked(action: StringName) -> bool:
	if not is_creative():
		return false
	for index: int in range(_input_captures.size() - 1, -1, -1):
		var target: Variant = _input_captures[index].get_ref()
		if not target is Node or not is_instance_valid(target):
			_input_captures.remove_at(index)
			continue
		var node: Node = target as Node
		if node.has_method("blocks_gameplay_action") and bool(node.call("blocks_gameplay_action", action)):
			return true
	return false


func _cleanup_input_captures() -> void:
	for index: int in range(_input_captures.size() - 1, -1, -1):
		if _input_captures[index].get_ref() == null:
			_input_captures.remove_at(index)


func active_rules() -> GameRules:
	if is_creative() and creative_rules != null:
		return creative_rules
	return null


func set_rule(property_name: StringName, enabled: bool) -> void:
	if creative_rules == null:
		return
	if property_name not in [&"invulnerable", &"infinite_mana", &"infinite_flight", &"creative_fly"]:
		return
	creative_rules.set(property_name, enabled)
	_apply_rules_to_player()
	creative_rules_changed.emit(creative_rules)


func _bind_game_state() -> void:
	if _game_manager == null or not is_instance_valid(_game_manager):
		_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	var next_state: GameState = _game_manager.game_state if _game_manager != null else null
	if next_state == _game_state:
		return
	if _game_state != null and is_instance_valid(_game_state):
		var previous_callback := Callable(self, "_on_runtime_mode_changed")
		if _game_state.runtime_mode_changed.is_connected(previous_callback):
			_game_state.runtime_mode_changed.disconnect(previous_callback)
	_game_state = next_state
	if _game_state != null:
		var callback := Callable(self, "_on_runtime_mode_changed")
		if not _game_state.runtime_mode_changed.is_connected(callback):
			_game_state.runtime_mode_changed.connect(callback)


func _on_runtime_mode_changed(_previous: GameState.RuntimeMode, current: GameState.RuntimeMode) -> void:
	_apply_mode()
	mode_changed.emit(current)


func _apply_mode() -> void:
	_apply_rules_to_player()
	if not is_creative():
		var world_service: Node = get_tree().get_first_node_in_group(&"world_gameplay_service")
		if world_service != null and is_instance_valid(world_service) and world_service.has_method("reset_creative_simulation_controls"):
			world_service.call("reset_creative_simulation_controls")
	for node: Node in get_tree().get_nodes_in_group(&"creative_ui"):
		if node != null and is_instance_valid(node) and node.has_method("set_creative_active"):
			node.call("set_creative_active", is_creative())


func _apply_rules_to_player() -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not is_instance_valid(player):
		return
	var rules: GameRules = active_rules()
	var creative: bool = rules != null
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.invulnerable = creative and rules.invulnerable
	var wand: WandController = player.get_node_or_null("WandController") as WandController
	if wand != null:
		wand.set_infinite_mana(creative and rules.infinite_mana)
	if player.has_method("set_infinite_flight_enabled"):
		player.call("set_infinite_flight_enabled", creative and rules.infinite_flight)
	if player.has_method("set_creative_fly_enabled"):
		player.call("set_creative_fly_enabled", creative and rules.creative_fly)


func _ensure_toggle_action() -> void:
	if InputMap.has_action(&"toggle_creative"):
		return
	InputMap.add_action(&"toggle_creative")
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F8
	InputMap.action_add_event(&"toggle_creative", event)
