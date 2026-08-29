class_name GameUIManager
extends Node

@export var game_flow_ui_scene: PackedScene
@export var gameplay_ui_scene: PackedScene
@export var creative_ui_scene: PackedScene

@onready var _summary_store: GameSummaryStore = $GameSummaryStore
@onready var _persistent_ui_host: Node = $PersistentUIHost

var _game_manager: GameManager = null
var _context: GameUIContext = null
var _game_flow_ui: GameFlowUI = null
var _gameplay_ui: GameplayUI = null
var _creative_ui: CreativeUI = null


func setup(manager: GameManager) -> bool:
	if _game_manager != null:
		return _game_manager == manager
	if manager == null or not is_instance_valid(manager):
		return false
	if game_flow_ui_scene == null or gameplay_ui_scene == null or creative_ui_scene == null:
		return false
	if _summary_store == null or not is_instance_valid(_summary_store):
		return false
	if _persistent_ui_host == null or not is_instance_valid(_persistent_ui_host):
		return false
	if not _summary_store.setup(manager):
		return false

	_game_manager = manager
	_context = GameUIContext.new()
	if not _context.setup_persistent(_game_manager, _summary_store):
		_context = null
		_game_manager = null
		return false
	if not _create_game_flow_ui():
		_context = null
		_game_manager = null
		return false

	if not _game_manager.game_started.is_connected(_on_game_started):
		_game_manager.game_started.connect(_on_game_started)
	if not _game_manager.game_stopping.is_connected(_on_game_stopping):
		_game_manager.game_stopping.connect(_on_game_stopping)

	if _game_manager.lifecycle_state == GameManager.LifecycleState.ACTIVE:
		_on_game_started(_game_manager.current_game_id)
	return true


func _exit_tree() -> void:
	if _game_manager != null and is_instance_valid(_game_manager):
		if _game_manager.game_started.is_connected(_on_game_started):
			_game_manager.game_started.disconnect(_on_game_started)
		if _game_manager.game_stopping.is_connected(_on_game_stopping):
			_game_manager.game_stopping.disconnect(_on_game_stopping)
	_destroy_runtime_ui()
	if _context != null:
		_context.clear_game()


func ui_context() -> GameUIContext:
	return _context


func game_flow_ui() -> GameFlowUI:
	return _game_flow_ui


func gameplay_ui() -> GameplayUI:
	return _gameplay_ui


func creative_ui() -> CreativeUI:
	return _creative_ui


func runtime_ui_count() -> int:
	var count: int = 0
	if _gameplay_ui != null and is_instance_valid(_gameplay_ui):
		count += 1
	if _creative_ui != null and is_instance_valid(_creative_ui):
		count += 1
	return count


func _create_game_flow_ui() -> bool:
	var instance: Node = _instantiate_ui(game_flow_ui_scene, _persistent_ui_host)
	_game_flow_ui = instance as GameFlowUI
	if _game_flow_ui == null:
		_free_ui_instance(instance)
		return false
	if not _game_flow_ui.setup(
			_game_manager,
			_summary_store,
			Callable(_game_manager, "request_shell_quit"),
		):
		_free_ui_instance(_game_flow_ui)
		_game_flow_ui = null
		return false
	return true


func _on_game_started(game_id: int) -> void:
	if _game_manager == null or game_id != _game_manager.current_game_id:
		return
	_destroy_runtime_ui()
	if _context != null:
		_context.clear_game()
	if not _compose_current_game_context(game_id):
		push_error("GameUIManager: Failed to compose GameUIContext for Game %d." % game_id)
		return
	if not _create_runtime_ui():
		push_error("GameUIManager: Failed to create runtime UI for Game %d." % game_id)
		_destroy_runtime_ui()
		_context.clear_game(game_id)


func _on_game_stopping(game_id: int) -> void:
	_destroy_runtime_ui()
	if _context != null:
		_context.clear_game(game_id)


func _compose_current_game_context(game_id: int) -> bool:
	if _context == null or _game_manager == null:
		return false
	var runtime_root: Node = _game_manager.runtime_root
	if runtime_root == null or not is_instance_valid(runtime_root):
		return false
	var world: Node = runtime_root.get_node_or_null("World")
	if world == null or not is_instance_valid(world):
		return false

	var state: GameState = _game_manager.game_state
	var local_player_state: PlayerState = _game_manager.get_player_state(GameManager.LOCAL_PLAYER_ID)
	var local_player: Node = _game_manager.get_player_runtime(GameManager.LOCAL_PLAYER_ID)
	var world_service: WorldGameplayService = world.get_node_or_null("GameplayWorld") as WorldGameplayService
	var mode_manager: GameModeManager = world.get_node_or_null("GameModeManager") as GameModeManager
	var brush: CreativeBrushController = world.get_node_or_null("CreativeBrush") as CreativeBrushController
	var entities: CreativeEntityController = world.get_node_or_null("CreativeEntities") as CreativeEntityController

	return _context.bind_game(
		game_id,
		state,
		local_player_state,
		local_player,
		world_service,
		mode_manager,
		brush,
		entities,
	)


func _create_runtime_ui() -> bool:
	if _context == null or not _context.has_game():
		return false
	var runtime_ui_parent: Node = _context.gameplay_world.get_parent()
	if runtime_ui_parent == null or not is_instance_valid(runtime_ui_parent):
		return false

	var gameplay_instance: Node = _instantiate_ui(gameplay_ui_scene, runtime_ui_parent)
	_gameplay_ui = gameplay_instance as GameplayUI
	if _gameplay_ui == null:
		_free_ui_instance(gameplay_instance)
		return false

	var creative_instance: Node = _instantiate_ui(creative_ui_scene, runtime_ui_parent)
	_creative_ui = creative_instance as CreativeUI
	if _creative_ui == null:
		_free_ui_instance(creative_instance)
		return false
	return true


func _destroy_runtime_ui() -> void:
	if _gameplay_ui != null and is_instance_valid(_gameplay_ui):
		_free_ui_instance(_gameplay_ui)
	_gameplay_ui = null

	if _creative_ui != null and is_instance_valid(_creative_ui):
		_free_ui_instance(_creative_ui)
	_creative_ui = null


func _instantiate_ui(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null or not is_instance_valid(parent):
		return null
	var instance: Node = scene.instantiate()
	if instance == null:
		return null
	parent.add_child(instance)
	return instance


func _free_ui_instance(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	var parent: Node = instance.get_parent()
	if parent != null and is_instance_valid(parent):
		parent.remove_child(instance)
	instance.queue_free()
