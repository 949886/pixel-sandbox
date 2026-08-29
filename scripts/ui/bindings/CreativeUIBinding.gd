extends CreativeUI

var _ui_context: GameUIContext = null


func bind_context(context: GameUIContext) -> bool:
	if context == null or not context.has_game():
		return false
	_ui_context = context
	if is_node_ready():
		_bind_dependencies()
	return true


func unbind_context() -> void:
	set_creative_active(false)
	if _brush != null and is_instance_valid(_brush) \
			and _brush.material_picked.is_connected(_on_material_picked):
		_brush.material_picked.disconnect(_on_material_picked)
	_wand_service.configure(null, null)
	_mode_manager = null
	_player = null
	_inventory = null
	_wand_controller = null
	_brush = null
	_world_service = null
	_entity_controller = null
	_ui_context = null


func _bind_dependencies() -> void:
	if _ui_context == null or not _ui_context.has_game():
		return
	if _player == _ui_context.player \
			and _mode_manager == _ui_context.game_mode_manager \
			and _world_service == _ui_context.gameplay_world \
			and _brush == _ui_context.creative_brush \
			and _entity_controller == _ui_context.creative_entities:
		return

	if _brush != null and is_instance_valid(_brush) \
			and _brush.material_picked.is_connected(_on_material_picked):
		_brush.material_picked.disconnect(_on_material_picked)

	_mode_manager = _ui_context.game_mode_manager
	_player = _ui_context.player
	_inventory = _player.get_node_or_null("PlayerInventory") as PlayerInventory
	_wand_controller = _player.get_node_or_null("WandController") as WandController
	_wand_service.configure(_inventory, _wand_controller)
	_world_service = _ui_context.gameplay_world
	_brush = _ui_context.creative_brush
	_entity_controller = _ui_context.creative_entities

	if _brush != null:
		if not _brush.material_picked.is_connected(_on_material_picked):
			_brush.material_picked.connect(_on_material_picked)
		_brush_size.value = _brush.brush_radius
	set_creative_active(_mode_manager != null and _mode_manager.is_creative())
	_refresh_material_grid()
	_refresh_entity_grid()
	_refresh_active_panel()
