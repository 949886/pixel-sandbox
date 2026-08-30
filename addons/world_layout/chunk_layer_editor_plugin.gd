@tool
extends EditorPlugin

## Editor-only paint tools for ChunkLayer.
##
## ChunkLayer itself is a Node2D with authored placement Resources; this plugin
## supplies TileMap-like grid interaction without making runtime chunks into tiles.
enum ToolMode {
	SELECT,
	PAINT,
	ERASE,
	PICK,
}

var _active_layer: ChunkLayer = null
var _toolbar: HBoxContainer
var _select_button: Button
var _paint_button: Button
var _erase_button: Button
var _pick_button: Button
var _palette: OptionButton
var _status: Label
var _mode: int = ToolMode.SELECT
var _last_drag_cell: Variant = null
var _hover_cell: Variant = null


func _enter_tree() -> void:
	_build_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.visible = false


func _exit_tree() -> void:
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()
	if _toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	_toolbar = null
	_active_layer = null


func _handles(object: Object) -> bool:
	return object is ChunkLayer


func _edit(object: Object) -> void:
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()
	_active_layer = object as ChunkLayer
	_refresh_palette()
	_update_toolbar_state()


func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible and _active_layer != null
	if not visible and _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _active_layer == null or not is_instance_valid(_active_layer) or not _toolbar.visible:
		return false

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell: Vector2i = _event_to_cell(motion.position)
		_hover_cell = cell
		_active_layer.set_editor_preview(cell, _selected_chunk() if _mode == ToolMode.PAINT else null)
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _last_drag_cell != cell:
				_last_drag_cell = cell
				if _mode == ToolMode.PAINT:
					_place_at(cell)
					return true
				if _mode == ToolMode.ERASE:
					_erase_at(cell)
					return true
		return false

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var cell: Vector2i = _event_to_cell(button.position)
		if not button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_last_drag_cell = null
				return _mode != ToolMode.SELECT
			return false

		if button.button_index == MOUSE_BUTTON_RIGHT and _mode != ToolMode.SELECT:
			_erase_at(cell)
			return true
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false

		_last_drag_cell = cell
		match _mode:
			ToolMode.PAINT:
				_place_at(cell)
				return true
			ToolMode.ERASE:
				_erase_at(cell)
				return true
			ToolMode.PICK:
				_pick_at(cell)
				return true
			_:
				return false

	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_Q:
				_set_mode(ToolMode.SELECT)
				return true
			KEY_W:
				_set_mode(ToolMode.PAINT)
				return true
			KEY_E:
				_set_mode(ToolMode.ERASE)
				return true
			KEY_R:
				_set_mode(ToolMode.PICK)
				return true
	return false


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "ChunkLayerTools"
	_toolbar.add_theme_constant_override("separation", 4)

	_select_button = _make_tool_button("Select", "Q", ToolMode.SELECT)
	_paint_button = _make_tool_button("Paint", "W", ToolMode.PAINT)
	_erase_button = _make_tool_button("Erase", "E", ToolMode.ERASE)
	_pick_button = _make_tool_button("Pick", "R", ToolMode.PICK)
	_toolbar.add_child(_select_button)
	_toolbar.add_child(_paint_button)
	_toolbar.add_child(_erase_button)
	_toolbar.add_child(_pick_button)

	var separator := VSeparator.new()
	_toolbar.add_child(separator)
	_palette = OptionButton.new()
	_palette.custom_minimum_size = Vector2(190.0, 0.0)
	_palette.tooltip_text = "Fixed SpecialChunk palette"
	_palette.item_selected.connect(_on_palette_selected)
	_toolbar.add_child(_palette)

	_status = Label.new()
	_status.text = "Fixed chunks only"
	_status.tooltip_text = "Procedural chunks are not stored in ChunkLayer."
	_toolbar.add_child(_status)
	_set_mode(ToolMode.SELECT)


func _make_tool_button(text: String, shortcut: String, mode: int) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.tooltip_text = "%s fixed chunks (%s)" % [text, shortcut]
	button.pressed.connect(func() -> void: _set_mode(mode))
	return button


func _set_mode(mode: int) -> void:
	_mode = mode
	if _select_button != null:
		_select_button.set_pressed_no_signal(mode == ToolMode.SELECT)
		_paint_button.set_pressed_no_signal(mode == ToolMode.PAINT)
		_erase_button.set_pressed_no_signal(mode == ToolMode.ERASE)
		_pick_button.set_pressed_no_signal(mode == ToolMode.PICK)
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.set_editor_preview(_hover_cell, _selected_chunk() if mode == ToolMode.PAINT else null)
	_update_status()


func _refresh_palette() -> void:
	if _palette == null:
		return
	_palette.clear()
	if _active_layer == null or not is_instance_valid(_active_layer):
		_palette.disabled = true
		return
	for chunk_def: SpecialChunkDef in _active_layer.palette_chunks:
		if chunk_def == null:
			continue
		var label: String = chunk_def.display_name.strip_edges()
		if label.is_empty():
			label = str(chunk_def.id)
		var index: int = _palette.get_item_count()
		_palette.add_item(label)
		_palette.set_item_metadata(index, chunk_def)
	_palette.disabled = _palette.get_item_count() == 0
	if _palette.get_item_count() > 0:
		_palette.select(0)


func _selected_chunk() -> SpecialChunkDef:
	if _palette == null or _palette.get_item_count() <= 0 or _palette.get_selected() < 0:
		return null
	return _palette.get_item_metadata(_palette.get_selected()) as SpecialChunkDef


func _on_palette_selected(_index: int) -> void:
	if _mode == ToolMode.SELECT:
		_set_mode(ToolMode.PAINT)
	elif _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.queue_redraw()
	_update_status()


func _update_toolbar_state() -> void:
	if _toolbar == null:
		return
	_toolbar.visible = _active_layer != null
	_refresh_palette()
	_update_status()


func _update_status(message: String = "") -> void:
	if _status == null:
		return
	if not message.is_empty():
		_status.text = message
		return
	match _mode:
		ToolMode.SELECT:
			_status.text = "Select mode"
		ToolMode.PAINT:
			var chunk_def: SpecialChunkDef = _selected_chunk()
			_status.text = "Paint: %s" % (str(chunk_def.id) if chunk_def != null else "<empty palette>")
		ToolMode.ERASE:
			_status.text = "Erase fixed chunk"
		ToolMode.PICK:
			_status.text = "Pick fixed chunk"


func _event_to_cell(event_position: Vector2) -> Vector2i:
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	var canvas_position: Vector2 = viewport.global_canvas_transform.affine_inverse() * event_position
	var layer_local: Vector2 = _active_layer.get_global_transform().affine_inverse() * canvas_position
	return _active_layer.world_to_cell(layer_local)


func _place_at(cell: Vector2i) -> void:
	var chunk_def: SpecialChunkDef = _selected_chunk()
	if chunk_def == null:
		_update_status("No fixed chunk selected")
		return
	if not _placement_is_inside_authored_world(cell, chunk_def):
		_update_status("Rejected: footprint enters VOID")
		return
	if not _placement_matches_biomes(cell, chunk_def):
		_update_status("Rejected: biome not allowed")
		return
	if not _active_layer.can_place_chunk(cell, chunk_def, true):
		_update_status("Rejected: fixed chunk overlap")
		return

	var before: Array[ChunkPaintPlacementDef] = _active_layer.duplicate_placements()
	var after: Array[ChunkPaintPlacementDef] = []
	for placement: ChunkPaintPlacementDef in before:
		if placement != null and placement.origin != cell:
			after.append(_copy_placement(placement))
	var added := ChunkPaintPlacementDef.new()
	added.chunk_def = chunk_def
	added.origin = cell
	after.append(added)
	if _placements_equal(before, after):
		return
	_commit_placement_change("Place Fixed Chunk", before, after)
	_update_status("Placed %s @ %s" % [str(chunk_def.id), str(cell)])


func _erase_at(cell: Vector2i) -> void:
	var hit: ChunkPaintPlacementDef = _active_layer.get_placement_at(cell)
	if hit == null:
		return
	var before: Array[ChunkPaintPlacementDef] = _active_layer.duplicate_placements()
	var after: Array[ChunkPaintPlacementDef] = []
	for placement: ChunkPaintPlacementDef in before:
		if placement != null and placement.origin != hit.origin:
			after.append(_copy_placement(placement))
	_commit_placement_change("Erase Fixed Chunk", before, after)
	_update_status("Erased fixed chunk @ %s" % str(hit.origin))


func _pick_at(cell: Vector2i) -> void:
	var hit: ChunkPaintPlacementDef = _active_layer.get_placement_at(cell)
	if hit == null or hit.chunk_def == null:
		_update_status("No fixed chunk at %s" % str(cell))
		return
	for index: int in range(_palette.get_item_count()):
		if _palette.get_item_metadata(index) == hit.chunk_def:
			_palette.select(index)
			_set_mode(ToolMode.PAINT)
			_update_status("Picked %s" % str(hit.chunk_def.id))
			return
	_update_status("Chunk is not in this layer palette")


func _commit_placement_change(
	action_name: String,
	before: Array[ChunkPaintPlacementDef],
	after: Array[ChunkPaintPlacementDef]
) -> void:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _active_layer)
	undo_redo.add_do_method(_active_layer, &"set_placements_data", after)
	undo_redo.add_undo_method(_active_layer, &"set_placements_data", before)
	undo_redo.commit_action()


func _placement_is_inside_authored_world(origin: Vector2i, chunk_def: SpecialChunkDef) -> bool:
	var biome_layer: BiomeLayer = _find_biome_layer()
	if biome_layer == null:
		return true
	for y: int in range(origin.y, origin.y + chunk_def.size_in_chunks.y):
		for x: int in range(origin.x, origin.x + chunk_def.size_in_chunks.x):
			if biome_layer.get_biome_config(Vector2i(x, y)) == null:
				return false
	return true


func _placement_matches_biomes(origin: Vector2i, chunk_def: SpecialChunkDef) -> bool:
	if chunk_def.allowed_biomes.is_empty():
		return true
	var biome_layer: BiomeLayer = _find_biome_layer()
	if biome_layer == null:
		return true
	for y: int in range(origin.y, origin.y + chunk_def.size_in_chunks.y):
		for x: int in range(origin.x, origin.x + chunk_def.size_in_chunks.x):
			var biome: BiomeConfig = biome_layer.get_biome_config(Vector2i(x, y))
			if biome == null or not chunk_def.allowed_biomes.has(biome.id):
				return false
	return true


func _find_biome_layer() -> BiomeLayer:
	if _active_layer == null or _active_layer.get_parent() == null:
		return null
	for sibling: Node in _active_layer.get_parent().get_children():
		if sibling is BiomeLayer:
			return sibling as BiomeLayer
	return null


func _copy_placement(source: ChunkPaintPlacementDef) -> ChunkPaintPlacementDef:
	if source == null:
		return null
	var copy := ChunkPaintPlacementDef.new()
	copy.chunk_def = source.chunk_def
	copy.origin = source.origin
	return copy


func _placements_equal(a: Array[ChunkPaintPlacementDef], b: Array[ChunkPaintPlacementDef]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] == null or b[i] == null:
			if a[i] != b[i]:
				return false
			continue
		if a[i].origin != b[i].origin or a[i].chunk_def != b[i].chunk_def:
			return false
	return true
