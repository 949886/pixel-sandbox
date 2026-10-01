@tool
extends EditorPlugin

## Project-level World Layout navigation plus independent fixed SpecialChunk tools.
##
## Main remains a runtime bootstrap scene. This plugin resolves its configured
## WorldDefinition, exposes an always-visible authoring entry in the 2D toolbar,
## and opens the referenced WorldLayout scene without encoding gameplay paths.
enum ToolMode {
	SELECT,
	PAINT,
	ERASE,
	PICK,
}

enum FocusTarget {
	LAYOUT,
	BIOME,
	CHUNK,
	ANCHORS,
}

const TOOL_MENU_OPEN: String = "Open Current World Layout"

var _active_layer: ChunkLayer = null
var _chunk_toolbar: HBoxContainer = null
var _select_button: Button = null
var _paint_button: Button = null
var _erase_button: Button = null
var _pick_button: Button = null
var _palette: OptionButton = null
var _chunk_status: Label = null
var _mode: int = ToolMode.SELECT
var _last_drag_cell: Variant = null
var _hover_cell: Variant = null

var _layout_toolbar: HBoxContainer = null
var _editor_dock: EditorDock = null
var _dock_content: VBoxContainer = null
var _world_label: Label = null
var _layout_label: Label = null
var _context_label: Label = null
var _dock_status: Label = null
var _open_button: Button = null
var _biome_button: Button = null
var _chunk_button: Button = null
var _anchor_button: Button = null
var _validate_button: Button = null
var _show_biomes: CheckBox = null
var _show_chunks: CheckBox = null
var _show_anchors: CheckBox = null
var _pending_focus: int = FocusTarget.LAYOUT
var _pending_open_focus: bool = false


func _enter_tree() -> void:
	_build_chunk_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _chunk_toolbar)
	_chunk_toolbar.visible = false

	_build_layout_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _layout_toolbar)
	_layout_toolbar.visible = false

	_build_dock()
	add_dock(_editor_dock)
	add_tool_menu_item(TOOL_MENU_OPEN, _on_open_layout_pressed)

	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	if not scene_saved.is_connected(_on_scene_saved):
		scene_saved.connect(_on_scene_saved)
	var selection: EditorSelection = EditorInterface.get_selection()
	if not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)

	_refresh_editor_context()
	# Godot 4.7's EditorDock can be hidden by a previously saved editor layout.
	# Focus it once when the plugin loads so the authoring entry is discoverable.
	call_deferred(&"_make_world_layout_dock_visible")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if scene_saved.is_connected(_on_scene_saved):
		scene_saved.disconnect(_on_scene_saved)
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)

	remove_tool_menu_item(TOOL_MENU_OPEN)
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()
	if _chunk_toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _chunk_toolbar)
		_chunk_toolbar.queue_free()
	if _layout_toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _layout_toolbar)
		_layout_toolbar.queue_free()
	if _editor_dock != null:
		remove_dock(_editor_dock)
		_editor_dock.queue_free()

	_chunk_toolbar = null
	_layout_toolbar = null
	_editor_dock = null
	_dock_content = null
	_active_layer = null


func _make_world_layout_dock_visible() -> void:
	if _editor_dock != null and is_instance_valid(_editor_dock):
		_editor_dock.make_visible()


func _handles(object: Object) -> bool:
	return object is ChunkLayer


func _edit(object: Object) -> void:
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()
	_active_layer = object as ChunkLayer
	_refresh_palette()
	_update_chunk_toolbar_state()


func _make_visible(visible: bool) -> void:
	if _chunk_toolbar != null:
		_chunk_toolbar.visible = visible and _active_layer != null
	if not visible and _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _active_layer == null or not is_instance_valid(_active_layer):
		return false
	if _chunk_toolbar == null or not _chunk_toolbar.visible:
		return false

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
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
		var button: InputEventMouseButton = event as InputEventMouseButton
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

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return false
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


# -----------------------------------------------------------------------------
# Project-level World Layout navigation

func _build_dock() -> void:
	_editor_dock = EditorDock.new()
	_editor_dock.name = "WorldLayoutDock"
	_editor_dock.title = "World Layout"
	_editor_dock.layout_key = "pixel_sandbox_world_layout"
	_editor_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	_editor_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_editor_dock.force_show_icon = true
	_editor_dock.icon_name = &"GridMap"

	_dock_content = VBoxContainer.new()
	_dock_content.name = "World Layout"
	_dock_content.custom_minimum_size = Vector2(280.0, 0.0)
	_dock_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_dock.add_child(_dock_content)

	var title: Label = Label.new()
	title.text = "World Layout"
	title.add_theme_font_size_override("font_size", 18)
	_dock_content.add_child(title)

	var bootstrap_hint: Label = Label.new()
	bootstrap_hint.text = "Main is a runtime bootstrap scene. Open its configured layout to edit the world."
	bootstrap_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bootstrap_hint.modulate = Color(1.0, 1.0, 1.0, 0.72)
	_dock_content.add_child(bootstrap_hint)

	_world_label = Label.new()
	_world_label.text = "World: —"
	_dock_content.add_child(_world_label)
	_layout_label = Label.new()
	_layout_label.text = "Layout: —"
	_layout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock_content.add_child(_layout_label)
	_context_label = Label.new()
	_context_label.text = "Context: —"
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock_content.add_child(_context_label)

	var separator: HSeparator = HSeparator.new()
	_dock_content.add_child(separator)

	_open_button = Button.new()
	_open_button.text = "Open World Layout"
	_open_button.pressed.connect(_on_open_layout_pressed)
	_dock_content.add_child(_open_button)

	var mode_row: HBoxContainer = HBoxContainer.new()
	_biome_button = Button.new()
	_biome_button.text = "Biomes"
	_biome_button.pressed.connect(_on_biomes_pressed)
	mode_row.add_child(_biome_button)
	_chunk_button = Button.new()
	_chunk_button.text = "Fixed Chunks"
	_chunk_button.pressed.connect(_on_chunks_pressed)
	mode_row.add_child(_chunk_button)
	_anchor_button = Button.new()
	_anchor_button.text = "Anchors"
	_anchor_button.pressed.connect(_on_anchors_pressed)
	mode_row.add_child(_anchor_button)
	_dock_content.add_child(mode_row)

	var view_title: Label = Label.new()
	view_title.text = "Editor overlays"
	_dock_content.add_child(view_title)
	_show_biomes = CheckBox.new()
	_show_biomes.text = "Biome colors"
	_show_biomes.button_pressed = true
	_show_biomes.toggled.connect(_on_overlay_toggled)
	_dock_content.add_child(_show_biomes)
	_show_chunks = CheckBox.new()
	_show_chunks.text = "Fixed chunks + grid"
	_show_chunks.button_pressed = true
	_show_chunks.toggled.connect(_on_overlay_toggled)
	_dock_content.add_child(_show_chunks)
	_show_anchors = CheckBox.new()
	_show_anchors.text = "World anchors"
	_show_anchors.button_pressed = true
	_show_anchors.toggled.connect(_on_overlay_toggled)
	_dock_content.add_child(_show_anchors)

	_validate_button = Button.new()
	_validate_button.text = "Validate Layout"
	_validate_button.pressed.connect(_on_validate_pressed)
	_dock_content.add_child(_validate_button)

	_dock_status = Label.new()
	_dock_status.text = "Open Main, World, or a WorldLayout scene."
	_dock_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock_content.add_child(_dock_status)


func _build_layout_toolbar() -> void:
	_layout_toolbar = HBoxContainer.new()
	_layout_toolbar.name = "WorldLayoutNavigationTools"
	_layout_toolbar.add_theme_constant_override("separation", 4)

	var label: Label = Label.new()
	label.text = "World Layout:"
	_layout_toolbar.add_child(label)

	var open_button: Button = Button.new()
	open_button.text = "Open"
	open_button.tooltip_text = "Open the WorldLayout referenced by this scene's WorldDefinition"
	open_button.pressed.connect(_on_open_layout_pressed)
	_layout_toolbar.add_child(open_button)

	for spec: Array in [
		["Biomes", FocusTarget.BIOME],
		["Fixed Chunks", FocusTarget.CHUNK],
		["Anchors", FocusTarget.ANCHORS],
	]:
		var button: Button = Button.new()
		button.text = str(spec[0])
		var target: int = int(spec[1])
		button.pressed.connect(_on_layout_target_pressed.bind(target))
		_layout_toolbar.add_child(button)

	var validate: Button = Button.new()
	validate.text = "Validate"
	validate.pressed.connect(_on_validate_pressed)
	_layout_toolbar.add_child(validate)


func _on_layout_target_pressed(target: int) -> void:
	_open_layout(target)


func _on_scene_changed(_scene_root: Node) -> void:
	_refresh_editor_context()
	if _pending_open_focus:
		var target: int = _pending_focus
		_pending_focus = FocusTarget.LAYOUT
		_pending_open_focus = false
		call_deferred(&"_focus_current_layout", target)


func _on_scene_saved(_path: String) -> void:
	_refresh_editor_context()


func _on_selection_changed() -> void:
	_refresh_editor_context()


func _refresh_editor_context() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	var is_layout: bool = root is WorldLayout
	var context: Dictionary = _resolve_world_context(root)
	var definition: WorldDefinition = context.get(&"definition") as WorldDefinition
	var layout_path: String = str(context.get(&"layout_path", ""))
	var source: String = str(context.get(&"source", ""))
	var can_open: bool = is_layout or not layout_path.is_empty()

	# The toolbar is deliberately visible from Main/World as well as from the
	# layout scene, so a hidden side dock can never make the feature undiscoverable.
	if _layout_toolbar != null:
		_layout_toolbar.visible = can_open

	if _world_label != null:
		_world_label.text = "World: %s" % (str(definition.id) if definition != null else (str(root.name) if is_layout else "—"))
		_layout_label.text = "Layout: %s" % (layout_path if not layout_path.is_empty() else "—")
		_context_label.text = "Context: %s" % (source if not source.is_empty() else "No WorldGenConfig found in edited scene")
		_open_button.disabled = not can_open
		_biome_button.disabled = not can_open
		_chunk_button.disabled = not can_open
		_anchor_button.disabled = not can_open
		_validate_button.disabled = not can_open

	if _dock_status == null:
		return
	if is_layout:
		_apply_overlay_visibility(root as WorldLayout)
		_dock_status.text = "Layout is open. Biome, fixed chunk, and anchor overlays are live together."
	elif not layout_path.is_empty():
		_dock_status.text = "World resolved. Use Open World Layout or jump directly to an authoring layer."
	else:
		_dock_status.text = "No WorldDefinition could be resolved from this scene."


func _resolve_world_context(root: Node) -> Dictionary:
	if root == null:
		return {}
	if root is WorldLayout:
		return {
			&"layout_path": root.scene_file_path,
			&"source": "Current WorldLayout scene",
		}

	var config: WorldGenConfig = _find_world_gen_config(root)
	if config == null or config.world_definition == null or config.world_definition.layout_scene == null:
		return {}
	return {
		&"definition": config.world_definition,
		&"layout_path": config.world_definition.layout_scene.resource_path,
		&"source": "WorldGenConfig on %s" % str(root.name),
	}


func _find_world_gen_config(root: Node) -> WorldGenConfig:
	if root == null:
		return null
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for property_info: Dictionary in node.get_property_list():
			var property_name: StringName = StringName(property_info.get("name", ""))
			if property_name != &"world_gen_config" and property_name != &"world_gen_config_template":
				continue
			var value: Variant = node.get(property_name)
			if value is WorldGenConfig:
				return value as WorldGenConfig
		for child: Node in node.get_children():
			pending.append(child)
	return null


func _on_open_layout_pressed() -> void:
	_open_layout(FocusTarget.LAYOUT)


func _on_biomes_pressed() -> void:
	_open_layout(FocusTarget.BIOME)


func _on_chunks_pressed() -> void:
	_open_layout(FocusTarget.CHUNK)


func _on_anchors_pressed() -> void:
	_open_layout(FocusTarget.ANCHORS)


func _open_layout(target: int) -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root is WorldLayout:
		_focus_current_layout(target)
		return
	var context: Dictionary = _resolve_world_context(root)
	var layout_path: String = str(context.get(&"layout_path", ""))
	if layout_path.is_empty():
		if _dock_status != null:
			_dock_status.text = "Cannot open: current scene has no configured WorldDefinition."
		return
	_pending_focus = target
	_pending_open_focus = true
	EditorInterface.open_scene_from_path(layout_path)


func _focus_current_layout(target: int) -> void:
	var root: WorldLayout = EditorInterface.get_edited_scene_root() as WorldLayout
	if root == null:
		return
	EditorInterface.set_main_screen_editor("2D")
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	match target:
		FocusTarget.BIOME:
			var biomes: BiomeLayer = root.biome_layer()
			if biomes != null:
				selection.add_node(biomes)
				EditorInterface.edit_node(biomes)
		FocusTarget.CHUNK:
			var chunks: ChunkLayer = root.chunk_layer()
			if chunks != null:
				selection.add_node(chunks)
				EditorInterface.edit_node(chunks)
		FocusTarget.ANCHORS:
			var anchors: Array[WorldAnchor] = root.get_world_anchors()
			for anchor: WorldAnchor in anchors:
				selection.add_node(anchor)
			if not anchors.is_empty():
				EditorInterface.edit_node(anchors[0])
		_:
			selection.add_node(root)
			EditorInterface.edit_node(root)
	_refresh_editor_context()


func _on_overlay_toggled(_pressed: bool) -> void:
	var root: WorldLayout = EditorInterface.get_edited_scene_root() as WorldLayout
	if root != null:
		_apply_overlay_visibility(root)


func _apply_overlay_visibility(layout: WorldLayout) -> void:
	var biomes: BiomeLayer = layout.biome_layer()
	if biomes != null:
		biomes.visible = _show_biomes.button_pressed
	var chunks: ChunkLayer = layout.chunk_layer()
	if chunks != null:
		chunks.visible = _show_chunks.button_pressed
	for anchor: WorldAnchor in layout.get_world_anchors():
		anchor.visible = _show_anchors.button_pressed


func _on_validate_pressed() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	var config: WorldGenConfig = null
	var layout: WorldLayout = root as WorldLayout
	if layout == null:
		config = _find_world_gen_config(root)
		var context: Dictionary = _resolve_world_context(root)
		var layout_path: String = str(context.get(&"layout_path", ""))
		if layout_path.is_empty():
			_dock_status.text = "Validation failed: no World Layout resolved."
			return
		var packed: PackedScene = load(layout_path) as PackedScene
		if packed == null:
			_dock_status.text = "Validation failed: layout scene could not be loaded."
			return
		layout = packed.instantiate() as WorldLayout
		if layout == null:
			_dock_status.text = "Validation failed: layout scene root is not WorldLayout."
			return
	else:
		config = _find_world_gen_config_for_layout(layout)

	if config == null:
		_dock_status.text = "Layout is visible, but full validation needs a WorldGenConfig context. Keep Main or World open and press Validate."
		if layout != root:
			layout.free()
		return
	var snapshot: WorldLayoutSnapshot = layout.build_snapshot(config)
	if layout != root:
		layout.free()
	if snapshot == null:
		_dock_status.text = "Validation FAILED. See Output for the precise WorldLayout error."
	else:
		_dock_status.text = "Validation OK: %d world cells, %d fixed chunk origins, %d anchors." % [
			snapshot.biome_by_cell.size(),
			snapshot.fixed_chunk_id_by_origin.size(),
			snapshot.anchor_data_by_id.size(),
		]


func _find_world_gen_config_for_layout(layout: WorldLayout) -> WorldGenConfig:
	# A standalone layout intentionally does not own generation content. Reuse any
	# open scene that exposes a WorldGenConfig instead of encoding a resource path.
	for open_root: Node in EditorInterface.get_open_scene_roots():
		var config: WorldGenConfig = _find_world_gen_config(open_root)
		if config != null and config.world_definition != null and config.world_definition.layout_scene != null:
			if config.world_definition.layout_scene.resource_path == layout.scene_file_path:
				return config
	return null


# -----------------------------------------------------------------------------
# Independent fixed-chunk painting tools

func _build_chunk_toolbar() -> void:
	_chunk_toolbar = HBoxContainer.new()
	_chunk_toolbar.name = "ChunkLayerTools"
	_chunk_toolbar.add_theme_constant_override("separation", 4)

	_select_button = _make_tool_button("Select", "Q", ToolMode.SELECT)
	_paint_button = _make_tool_button("Paint", "W", ToolMode.PAINT)
	_erase_button = _make_tool_button("Erase", "E", ToolMode.ERASE)
	_pick_button = _make_tool_button("Pick", "R", ToolMode.PICK)
	_chunk_toolbar.add_child(_select_button)
	_chunk_toolbar.add_child(_paint_button)
	_chunk_toolbar.add_child(_erase_button)
	_chunk_toolbar.add_child(_pick_button)

	var separator: VSeparator = VSeparator.new()
	_chunk_toolbar.add_child(separator)
	_palette = OptionButton.new()
	_palette.custom_minimum_size = Vector2(190.0, 0.0)
	_palette.tooltip_text = "Fixed SpecialChunk palette"
	_palette.item_selected.connect(_on_palette_selected)
	_chunk_toolbar.add_child(_palette)

	_chunk_status = Label.new()
	_chunk_status.text = "Fixed chunks only"
	_chunk_status.tooltip_text = "Procedural chunks are not stored in ChunkLayer."
	_chunk_toolbar.add_child(_chunk_status)
	_set_mode(ToolMode.SELECT)


func _make_tool_button(text: String, shortcut: String, mode: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.tooltip_text = "%s fixed chunks (%s)" % [text, shortcut]
	button.pressed.connect(_on_tool_mode_pressed.bind(mode))
	return button


func _on_tool_mode_pressed(mode: int) -> void:
	_set_mode(mode)


func _set_mode(mode: int) -> void:
	_mode = mode
	if _select_button != null:
		_select_button.set_pressed_no_signal(mode == ToolMode.SELECT)
		_paint_button.set_pressed_no_signal(mode == ToolMode.PAINT)
		_erase_button.set_pressed_no_signal(mode == ToolMode.ERASE)
		_pick_button.set_pressed_no_signal(mode == ToolMode.PICK)
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.set_editor_preview(_hover_cell, _selected_chunk() if mode == ToolMode.PAINT else null)
	_update_chunk_status()


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
	_update_chunk_status()


func _update_chunk_toolbar_state() -> void:
	if _chunk_toolbar == null:
		return
	_chunk_toolbar.visible = _active_layer != null
	_refresh_palette()
	_update_chunk_status()


func _update_chunk_status(message: String = "") -> void:
	if _chunk_status == null:
		return
	if not message.is_empty():
		_chunk_status.text = message
		return
	match _mode:
		ToolMode.SELECT:
			_chunk_status.text = "Select mode"
		ToolMode.PAINT:
			var chunk_def: SpecialChunkDef = _selected_chunk()
			_chunk_status.text = "Paint: %s" % (str(chunk_def.id) if chunk_def != null else "<empty palette>")
		ToolMode.ERASE:
			_chunk_status.text = "Erase fixed chunk"
		ToolMode.PICK:
			_chunk_status.text = "Pick fixed chunk"


func _event_to_cell(event_position: Vector2) -> Vector2i:
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	var canvas_position: Vector2 = viewport.global_canvas_transform.affine_inverse() * event_position
	var layer_local: Vector2 = _active_layer.get_global_transform().affine_inverse() * canvas_position
	return _active_layer.world_to_cell(layer_local)


func _place_at(cell: Vector2i) -> void:
	var chunk_def: SpecialChunkDef = _selected_chunk()
	if chunk_def == null:
		_update_chunk_status("No fixed chunk selected")
		return
	if not _placement_is_inside_authored_world(cell, chunk_def):
		_update_chunk_status("Rejected: footprint enters VOID")
		return
	if not _placement_matches_biomes(cell, chunk_def):
		_update_chunk_status("Rejected: biome not allowed")
		return
	if not _active_layer.can_place_chunk(cell, chunk_def, true):
		_update_chunk_status("Rejected: fixed chunk overlap")
		return

	var before: Array[ChunkPaintPlacementDef] = _active_layer.duplicate_placements()
	var after: Array[ChunkPaintPlacementDef] = []
	for placement: ChunkPaintPlacementDef in before:
		if placement != null and placement.origin != cell:
			after.append(_copy_placement(placement))
	var added: ChunkPaintPlacementDef = ChunkPaintPlacementDef.new()
	added.chunk_def = chunk_def
	added.origin = cell
	after.append(added)
	if _placements_equal(before, after):
		return
	_commit_placement_change("Place Fixed Chunk", before, after)
	_update_chunk_status("Placed %s @ %s" % [str(chunk_def.id), str(cell)])


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
	_update_chunk_status("Erased fixed chunk @ %s" % str(hit.origin))


func _pick_at(cell: Vector2i) -> void:
	var hit: ChunkPaintPlacementDef = _active_layer.get_placement_at(cell)
	if hit == null or hit.chunk_def == null:
		_update_chunk_status("No fixed chunk at %s" % str(cell))
		return
	for index: int in range(_palette.get_item_count()):
		if _palette.get_item_metadata(index) == hit.chunk_def:
			_palette.select(index)
			_set_mode(ToolMode.PAINT)
			_update_chunk_status("Picked %s" % str(hit.chunk_def.id))
			return
	_update_chunk_status("Chunk is not in this layer palette")


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
	EditorInterface.mark_scene_as_unsaved()


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
	var copy: ChunkPaintPlacementDef = ChunkPaintPlacementDef.new()
	copy.chunk_def = source.chunk_def
	copy.origin = source.origin
	return copy


func _placements_equal(a: Array[ChunkPaintPlacementDef], b: Array[ChunkPaintPlacementDef]) -> bool:
	if a.size() != b.size():
		return false
	for index: int in range(a.size()):
		if a[index] == null or b[index] == null:
			if a[index] != b[index]:
				return false
			continue
		if a[index].origin != b[index].origin or a[index].chunk_def != b[index].chunk_def:
			return false
	return true
