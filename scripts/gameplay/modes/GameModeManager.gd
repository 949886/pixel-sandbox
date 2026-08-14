class_name GameModeManager
extends Node

signal mode_changed(mode: int)
signal creative_rules_changed(rules: GameRules)

enum Mode {
	NORMAL,
	CREATIVE,
}

@export var start_in_creative: bool = false
@export var allow_input_mode_toggle: bool = true
@export var creative_rules: GameRules

var current_mode: int = Mode.NORMAL
var _input_captures: Array[WeakRef] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_mode_manager")
	_ensure_toggle_action()
	current_mode = Mode.CREATIVE if start_in_creative else Mode.NORMAL
	call_deferred("_apply_mode")

func _unhandled_input(event: InputEvent) -> void:
	if not allow_input_mode_toggle:
		return
	if event.is_action_pressed(&"toggle_creative"):
		toggle_mode()
		get_viewport().set_input_as_handled()

func toggle_mode() -> void:
	set_mode(Mode.NORMAL if current_mode == Mode.CREATIVE else Mode.CREATIVE)

func set_mode(mode: int) -> void:
	var resolved: int = Mode.CREATIVE if mode == Mode.CREATIVE else Mode.NORMAL
	if current_mode == resolved:
		_apply_mode()
		return
	current_mode = resolved
	_apply_mode()
	mode_changed.emit(current_mode)

func is_creative() -> bool:
	return current_mode == Mode.CREATIVE

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
