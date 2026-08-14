class_name GameSessionHost
extends Node

signal session_started(session: Node, kind: int)
signal session_stopped(kind: int)

enum SessionKind {
	NONE,
	NORMAL,
	CREATIVE,
}

@export var normal_session_scene: PackedScene
@export var creative_session_scene: PackedScene
@export var start_in_creative: bool = false

var current_session: Node
var current_session_kind: int = SessionKind.NONE
var _switching: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_toggle_action()
	call_deferred("_start_initial_session")

func _unhandled_input(event: InputEvent) -> void:
	if _switching or not event.is_action_pressed(&"toggle_creative"):
		return
	if current_session_kind == SessionKind.CREATIVE:
		start_new_game()
	else:
		start_creative()
	get_viewport().set_input_as_handled()

func start_new_game() -> void:
	_request_session(normal_session_scene, SessionKind.NORMAL)

func restart_game() -> void:
	start_new_game()

func start_creative() -> void:
	_request_session(creative_session_scene, SessionKind.CREATIVE)

func destroy_current_session() -> void:
	_request_session(null, SessionKind.NONE)

func is_switching() -> bool:
	return _switching

func _start_initial_session() -> void:
	if current_session != null or _switching:
		return
	if start_in_creative:
		start_creative()
	else:
		start_new_game()

func _request_session(scene: PackedScene, kind: int) -> void:
	if _switching:
		return
	if scene == null and kind != SessionKind.NONE:
		push_error("GameSessionHost: requested session scene is missing")
		return
	_switching = true
	call_deferred("_replace_session", scene, kind)

func _replace_session(scene: PackedScene, kind: int) -> void:
	var previous_session: Node = current_session
	var previous_kind: int = current_session_kind
	current_session = null
	current_session_kind = SessionKind.NONE

	if previous_session != null and is_instance_valid(previous_session):
		previous_session.queue_free()
		await previous_session.tree_exited
		session_stopped.emit(previous_kind)

	if scene != null:
		var next_session: Node = scene.instantiate()
		if next_session == null:
			push_error("GameSessionHost: failed to instantiate requested session")
			_switching = false
			return
		add_child(next_session)
		current_session = next_session
		current_session_kind = kind
		session_started.emit(next_session, kind)

	_switching = false

func _ensure_toggle_action() -> void:
	if InputMap.has_action(&"toggle_creative"):
		return
	InputMap.add_action(&"toggle_creative")
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F8
	InputMap.action_add_event(&"toggle_creative", event)
