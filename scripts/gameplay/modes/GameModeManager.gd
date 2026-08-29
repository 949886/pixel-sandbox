class_name GameModeManager
extends Node

signal mode_changed(mode: int)
signal creative_rules_changed(rules: GameRules)

@export var request_player_id: int = GameManager.LOCAL_PLAYER_ID
@export var creative_rules_override: GameRules

var current_mode: int:
	get:
		return _current_runtime_mode()

var _game_manager: GameManager = null
var _game_state: GameState = null
var _runtime_creative_rules: GameRules = null
var _input_captures: Array[WeakRef] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_mode_manager")
	_ensure_toggle_action()
	var rules_template: GameRules = creative_rules_override
	if rules_template == null:
		var content := GameplayContentAccess.find_from(self)
		rules_template = content.creative_rules if content != null else null
	if rules_template != null:
		# GameplayContentDB owns the template. CreativeUI may change rule toggles
		# during this Game, so keep those mutations runtime-local.
		_runtime_creative_rules = rules_template.duplicate(false) as GameRules
	call_deferred(&"_bind_game_state")


func _exit_tree() -> void:
	if _game_state != null and is_instance_valid(_game_state):
		if _game_state.runtime_mode_changed.is_connected(_on_runtime_mode_changed):
			_game_state.runtime_mode_changed.disconnect(_on_runtime_mode_changed)
		if _game_state.phase_changed.is_connected(_on_game_phase_changed):
			_game_state.phase_changed.disconnect(_on_game_phase_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_creative"):
		toggle_mode()
		get_viewport().set_input_as_handled()


func toggle_mode() -> bool:
	var target_mode := GameState.RuntimeMode.NORMAL \
		if is_creative() else GameState.RuntimeMode.CREATIVE
	return set_mode(target_mode)


func set_mode(mode: int) -> bool:
	if not GameState.RuntimeMode.values().has(mode):
		return false
	if not _ensure_game_state_bound():
		return false
	return _game_manager.request_runtime_mode(request_player_id, mode)


func is_creative() -> bool:
	return _current_runtime_mode() == GameState.RuntimeMode.CREATIVE


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
	if not _creative_runtime_effects_active():
		return false
	for index: int in range(_input_captures.size() - 1, -1, -1):
		var target: Variant = _input_captures[index].get_ref()
		if not target is Node or not is_instance_valid(target):
			_input_captures.remove_at(index)
			continue
		var node: Node = target as Node
		if node.has_method(&"blocks_gameplay_action") \
				and bool(node.call(&"blocks_gameplay_action", action)):
			return true
	return false


func active_rules() -> GameRules:
	if _creative_runtime_effects_active():
		return _runtime_creative_rules
	return null


func set_rule(property_name: StringName, enabled: bool) -> void:
	if _runtime_creative_rules == null or not _creative_runtime_effects_active():
		return
	if property_name not in [&"invulnerable", &"infinite_mana", &"infinite_flight", &"creative_fly"]:
		return
	_runtime_creative_rules.set(property_name, enabled)
	_apply_rules_to_players()
	creative_rules_changed.emit(_runtime_creative_rules)


# Bind this runtime adapter to the current authoritative GameState.
#
# GameModeManager does not own RuntimeMode state. This method finds the current
# GameManager/GameState, disconnects from a previously bound GameState when the
# Game changes, subscribes to public state changes on the current state, and
# immediately applies that state to the gameplay runtime.
#
# Keeping the binding replaceable also makes the adapter safe for a future New
# Game / Restart flow where the old GameState is destroyed and a new one becomes
# authoritative without introducing a second mode state in GameModeManager.
func _bind_game_state() -> void:
	var next_manager := get_tree().get_first_node_in_group(&"game_manager") as GameManager
	var next_state: GameState = next_manager.game_state if next_manager != null else null

	if _game_state != null and is_instance_valid(_game_state) and _game_state != next_state:
		if _game_state.runtime_mode_changed.is_connected(_on_runtime_mode_changed):
			_game_state.runtime_mode_changed.disconnect(_on_runtime_mode_changed)
		if _game_state.phase_changed.is_connected(_on_game_phase_changed):
			_game_state.phase_changed.disconnect(_on_game_phase_changed)

	_game_manager = next_manager
	_game_state = next_state
	if _game_state != null and is_instance_valid(_game_state):
		if not _game_state.runtime_mode_changed.is_connected(_on_runtime_mode_changed):
			_game_state.runtime_mode_changed.connect(_on_runtime_mode_changed)
		if not _game_state.phase_changed.is_connected(_on_game_phase_changed):
			_game_state.phase_changed.connect(_on_game_phase_changed)
	_apply_mode()


# Requests may arrive after scene/lifecycle changes, so validate that the cached
# binding still points at GameManager.game_state and rebind before forwarding a
# RuntimeMode request when necessary.
func _ensure_game_state_bound() -> bool:
	if _game_manager == null or not is_instance_valid(_game_manager) \
			or _game_state == null or not is_instance_valid(_game_state) \
			or _game_manager.game_state != _game_state:
		_bind_game_state()
	return _game_manager != null and is_instance_valid(_game_manager) \
		and _game_state != null and is_instance_valid(_game_state) \
		and _game_manager.game_state == _game_state


func _current_runtime_mode() -> int:
	if _game_state == null or not is_instance_valid(_game_state):
		return GameState.RuntimeMode.NORMAL
	return _game_state.runtime_mode


func _creative_runtime_effects_active() -> bool:
	if not is_creative():
		return false
	if _game_state == null or not is_instance_valid(_game_state):
		return false
	# Keep RuntimeMode as the final public fact, but ENDED is a hard runtime
	# input/effect boundary. We do not mutate the canonical mode just to disable
	# Creative abilities and tools after the Game has ended.
	return _game_state.phase != GameState.GamePhase.ENDED


func _on_runtime_mode_changed(_previous: GameState.RuntimeMode, current: GameState.RuntimeMode) -> void:
	_apply_mode()
	mode_changed.emit(current)


func _on_game_phase_changed(
		_previous: GameState.GamePhase,
		_current: GameState.GamePhase,
	) -> void:
	_apply_mode()


func _apply_mode() -> void:
	var creative_active := _creative_runtime_effects_active()
	_apply_rules_to_players()
	if not creative_active:
		var world_service: Node = get_tree().get_first_node_in_group(&"world_gameplay_service")
		if world_service != null and is_instance_valid(world_service) \
				and world_service.has_method(&"reset_creative_simulation_controls"):
			world_service.call(&"reset_creative_simulation_controls")
	for node: Node in get_tree().get_nodes_in_group(&"creative_ui"):
		if node != null and is_instance_valid(node) and node.has_method(&"set_creative_active"):
			node.call(&"set_creative_active", creative_active)


func _apply_rules_to_players() -> void:
	var rules: GameRules = active_rules()
	if _game_manager != null and is_instance_valid(_game_manager):
		for player_state: PlayerState in _game_manager.get_player_states():
			_apply_rules_to_player_runtime(
				_game_manager.get_player_runtime(player_state.player_id),
				rules,
			)
		return

	# Compatibility fallback for standalone Creative scenes without GameManager.
	_apply_rules_to_player_runtime(get_tree().get_first_node_in_group(&"player"), rules)


func _apply_rules_to_player_runtime(player: Node, rules: GameRules) -> void:
	if player == null or not is_instance_valid(player):
		return
	var creative := rules != null
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.invulnerable = creative and rules.invulnerable
	var wand := player.get_node_or_null("WandController") as WandController
	if wand != null:
		wand.set_infinite_mana(creative and rules.infinite_mana)
	if player.has_method(&"set_infinite_flight_enabled"):
		player.call(&"set_infinite_flight_enabled", creative and rules.infinite_flight)
	if player.has_method(&"set_creative_fly_enabled"):
		player.call(&"set_creative_fly_enabled", creative and rules.creative_fly)


func _cleanup_input_captures() -> void:
	for index: int in range(_input_captures.size() - 1, -1, -1):
		if _input_captures[index].get_ref() == null:
			_input_captures.remove_at(index)


func _ensure_toggle_action() -> void:
	if InputMap.has_action(&"toggle_creative"):
		return
	InputMap.add_action(&"toggle_creative")
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	InputMap.action_add_event(&"toggle_creative", event)
