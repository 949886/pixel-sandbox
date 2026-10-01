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
const GRID_VIEW_MARGIN_CELLS: int = 2

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
var _selected_placement_origin: Variant = null
var _selected_chunk_def: SpecialChunkDef = null

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
var _selected_chunk_info: Label = null
var _inspect_selected_chunk_button: Button = null
var _pending_focus: int = FocusTarget.LAYOUT
var _pending_open_focus: bool = false


func _enter_tree() -> void:
	# Fixed Chunk previews are project-level authoring overlays, not gizmos owned
	# by the currently selected node. Force canvas overlay forwarding so authored
	# footprints remain visible whenever a WorldLayout scene is open. The orange
	# Chunk grid is intentionally gated by the actual ChunkLayer selection.
	set_force_draw_over_forwarding_enabled()

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
		_active_layer.clear_editor_selection()
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
		_active_layer.clear_editor_selection()
	_active_layer = object as ChunkLayer
	_clear_selected_chunk()
	_refresh_palette()
	_update_chunk_toolbar_state()
	update_overlays()


func _make_visible(visible: bool) -> void:
	if _chunk_toolbar != null:
		_chunk_toolbar.visible = visible and _active_layer != null
	if not visible and _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_preview()
	update_overlays()


func _forward_canvas_force_draw_over_viewport(viewport_control: Control) -> void:
	var layer: ChunkLayer = _grid_layer_for_current_layout()
	if layer == null or not is_instance_valid(layer) or not layer.visible:
		return

	var editor_viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	if editor_viewport == null:
		return
	var local_to_screen: Transform2D = editor_viewport.global_canvas_transform * layer.get_global_transform()
	if is_zero_approx(local_to_screen.determinant()):
		return
	var screen_to_local: Transform2D = local_to_screen.affine_inverse()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, viewport_control.size)
	var local_view_rect: Rect2 = _screen_rect_to_local_bounds(viewport_rect, screen_to_local)

	# Base fills and art previews are drawn first. Every authored footprint receives
	# a complete color backing even when editor_preview contains transparent air.
	# This prevents terrain-only PNG previews from looking like partial Chunk cells.
	if layer.draw_fixed_chunks:
		_draw_fixed_chunk_bases(viewport_control, layer, local_to_screen, local_view_rect, viewport_rect)

	# Grid lines are an editing aid, not part of the persistent world preview.
	# Keep authored Fixed Chunks visible at all times, but draw the orange grid
	# only while this exact ChunkLayer is selected in the Scene dock.
	if layer.draw_grid and _is_chunk_layer_selected(layer):
		_draw_chunk_grid(viewport_control, layer, local_to_screen, local_view_rect)

	# Outlines, labels, selection and hover are last so they stay readable.
	if layer.draw_fixed_chunks:
		_draw_fixed_chunk_foreground(viewport_control, layer, local_to_screen, local_view_rect, viewport_rect)
	_draw_chunk_hover(viewport_control, layer, local_to_screen, viewport_rect)


func _screen_rect_to_local_bounds(screen_rect: Rect2, screen_to_local: Transform2D) -> Rect2:
	var corners: PackedVector2Array = PackedVector2Array([
		screen_to_local * screen_rect.position,
		screen_to_local * Vector2(screen_rect.end.x, screen_rect.position.y),
		screen_to_local * screen_rect.end,
		screen_to_local * Vector2(screen_rect.position.x, screen_rect.end.y),
	])
	var min_local: Vector2 = corners[0]
	var max_local: Vector2 = corners[0]
	for corner: Vector2 in corners:
		min_local.x = minf(min_local.x, corner.x)
		min_local.y = minf(min_local.y, corner.y)
		max_local.x = maxf(max_local.x, corner.x)
		max_local.y = maxf(max_local.y, corner.y)
	return Rect2(min_local, max_local - min_local)


func _local_rect_to_screen_bounds(local_rect: Rect2, local_to_screen: Transform2D) -> Rect2:
	var corners: PackedVector2Array = PackedVector2Array([
		local_to_screen * local_rect.position,
		local_to_screen * Vector2(local_rect.end.x, local_rect.position.y),
		local_to_screen * local_rect.end,
		local_to_screen * Vector2(local_rect.position.x, local_rect.end.y),
	])
	var min_screen: Vector2 = corners[0]
	var max_screen: Vector2 = corners[0]
	for corner: Vector2 in corners:
		min_screen.x = minf(min_screen.x, corner.x)
		min_screen.y = minf(min_screen.y, corner.y)
		max_screen.x = maxf(max_screen.x, corner.x)
		max_screen.y = maxf(max_screen.y, corner.y)
	return Rect2(min_screen, max_screen - min_screen)


func _draw_fixed_chunk_bases(
	viewport_control: Control,
	layer: ChunkLayer,
	local_to_screen: Transform2D,
	local_view_rect: Rect2,
	viewport_rect: Rect2
) -> void:
	for placement: ChunkPaintPlacementDef in layer.placements:
		if not layer.editor_placement_is_valid(placement):
			continue
		var chunk_def: SpecialChunkDef = placement.chunk_def
		var local_rect: Rect2 = layer.cell_rect(placement.origin, chunk_def.size_in_chunks)
		if not local_rect.grow(float(layer.chunk_size())).intersects(local_view_rect):
			continue
		var screen_rect: Rect2 = _local_rect_to_screen_bounds(local_rect, local_to_screen)
		if not screen_rect.grow(8.0).intersects(viewport_rect):
			continue

		var fill: Color = chunk_def.editor_color
		fill.a = layer.fixed_chunk_alpha
		viewport_control.draw_rect(screen_rect, fill, true)

		# Art previews often contain a large transparent air area. The full-footprint
		# fill above remains visible beneath that transparency. At sub-pixel sizes the
		# preview is skipped so a stable authored-cell color is shown instead.
		if chunk_def.editor_preview != null and screen_rect.size.x >= 2.0 and screen_rect.size.y >= 2.0:
			var preview_modulate: Color = Color(1.0, 1.0, 1.0, maxf(layer.fixed_chunk_alpha, 0.82))
			viewport_control.draw_texture_rect(chunk_def.editor_preview, screen_rect, false, preview_modulate)


func _draw_chunk_grid(
	viewport_control: Control,
	layer: ChunkLayer,
	local_to_screen: Transform2D,
	local_view_rect: Rect2
) -> void:
	var grid_rect: Rect2i = layer.editor_grid_rect()
	if grid_rect.size.x <= 0 or grid_rect.size.y <= 0:
		return

	var cell_size: float = float(layer.chunk_size())
	var visible_start: Vector2i = Vector2i(
		floori(local_view_rect.position.x / cell_size) - GRID_VIEW_MARGIN_CELLS,
		floori(local_view_rect.position.y / cell_size) - GRID_VIEW_MARGIN_CELLS
	)
	var visible_end: Vector2i = Vector2i(
		ceili(local_view_rect.end.x / cell_size) + GRID_VIEW_MARGIN_CELLS,
		ceili(local_view_rect.end.y / cell_size) + GRID_VIEW_MARGIN_CELLS
	)
	var start_x: int = maxi(grid_rect.position.x, visible_start.x)
	var end_x: int = mini(grid_rect.end.x, visible_end.x)
	var start_y: int = maxi(grid_rect.position.y, visible_start.y)
	var end_y: int = mini(grid_rect.end.y, visible_end.y)
	if start_x > end_x or start_y > end_y:
		return

	var grid_left: float = float(grid_rect.position.x) * cell_size
	var grid_right: float = float(grid_rect.end.x) * cell_size
	var grid_top: float = float(grid_rect.position.y) * cell_size
	var grid_bottom: float = float(grid_rect.end.y) * cell_size
	var margin_world: float = float(GRID_VIEW_MARGIN_CELLS) * cell_size
	var visible_left: float = maxf(grid_left, local_view_rect.position.x - margin_world)
	var visible_right: float = minf(grid_right, local_view_rect.end.x + margin_world)
	var visible_top: float = maxf(grid_top, local_view_rect.position.y - margin_world)
	var visible_bottom: float = minf(grid_bottom, local_view_rect.end.y + margin_world)
	var line_width: float = maxf(1.0, layer.grid_line_width)
	for x: int in range(start_x, end_x + 1):
		var local_x: float = float(x) * cell_size
		viewport_control.draw_line(
			local_to_screen * Vector2(local_x, visible_top),
			local_to_screen * Vector2(local_x, visible_bottom),
			layer.grid_color,
			line_width,
			true
		)
	for y: int in range(start_y, end_y + 1):
		var local_y: float = float(y) * cell_size
		viewport_control.draw_line(
			local_to_screen * Vector2(visible_left, local_y),
			local_to_screen * Vector2(visible_right, local_y),
			layer.grid_color,
			line_width,
			true
		)


func _draw_fixed_chunk_foreground(
	viewport_control: Control,
	layer: ChunkLayer,
	local_to_screen: Transform2D,
	local_view_rect: Rect2,
	viewport_rect: Rect2
) -> void:
	var selected_origin: Variant = layer.editor_selected_origin()
	for placement: ChunkPaintPlacementDef in layer.placements:
		if not layer.editor_placement_is_valid(placement):
			continue
		var chunk_def: SpecialChunkDef = placement.chunk_def
		var local_rect: Rect2 = layer.cell_rect(placement.origin, chunk_def.size_in_chunks)
		if not local_rect.grow(float(layer.chunk_size())).intersects(local_view_rect):
			continue
		var screen_rect: Rect2 = _local_rect_to_screen_bounds(local_rect, local_to_screen)
		if not screen_rect.grow(12.0).intersects(viewport_rect):
			continue

		var border: Color = chunk_def.editor_color
		border.a = 0.98
		viewport_control.draw_rect(screen_rect, border, false, maxf(1.0, layer.fixed_chunk_border_width), true)

		if selected_origin is Vector2i and placement.origin == selected_origin:
			var selection_width: float = maxf(2.0, layer.selected_chunk_border_width)
			viewport_control.draw_rect(screen_rect, layer.selected_chunk_border_color, false, selection_width, true)
			var handle_radius: float = maxf(3.0, selection_width * 0.75)
			var corners: PackedVector2Array = PackedVector2Array([
				screen_rect.position,
				Vector2(screen_rect.end.x, screen_rect.position.y),
				screen_rect.end,
				Vector2(screen_rect.position.x, screen_rect.end.y),
			])
			for corner: Vector2 in corners:
				viewport_control.draw_circle(corner, handle_radius, layer.selected_chunk_border_color)

		if layer.draw_labels and screen_rect.size.x >= 72.0 and screen_rect.size.y >= 28.0:
			_draw_chunk_label_overlay(viewport_control, screen_rect, chunk_def)


func _draw_chunk_label_overlay(viewport_control: Control, screen_rect: Rect2, chunk_def: SpecialChunkDef) -> void:
	var text: String = chunk_def.display_name.strip_edges()
	if text.is_empty():
		text = str(chunk_def.id)
	if text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(12, ThemeDB.fallback_font_size)
	var baseline: Vector2 = screen_rect.position + Vector2(6.0, float(font_size) + 5.0)
	viewport_control.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(0.0, screen_rect.size.x - 12.0),
		font_size,
		Color(1.0, 1.0, 1.0, 0.96)
	)


func _draw_chunk_hover(
	viewport_control: Control,
	layer: ChunkLayer,
	local_to_screen: Transform2D,
	viewport_rect: Rect2
) -> void:
	var hover_cell: Variant = layer.editor_hover_cell()
	if not hover_cell is Vector2i:
		return
	var size_in_chunks: Vector2i = Vector2i.ONE
	var preview_color: Color = Color(0.9, 0.9, 0.9, layer.hover_alpha)
	var preview_chunk: SpecialChunkDef = layer.editor_preview_chunk()
	if preview_chunk != null:
		size_in_chunks = preview_chunk.size_in_chunks
		preview_color = preview_chunk.editor_color
		preview_color.a = layer.hover_alpha
	var local_rect: Rect2 = layer.cell_rect(hover_cell, size_in_chunks)
	var screen_rect: Rect2 = _local_rect_to_screen_bounds(local_rect, local_to_screen)
	if not screen_rect.grow(8.0).intersects(viewport_rect):
		return
	viewport_control.draw_rect(screen_rect, preview_color, true)
	var border: Color = preview_color
	border.a = 0.95
	viewport_control.draw_rect(screen_rect, border, false, 2.0, true)


func _is_chunk_layer_selected(layer: ChunkLayer) -> bool:
	if layer == null or not is_instance_valid(layer):
		return false
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		return false
	for selected_node: Node in selection.get_selected_nodes():
		if selected_node == layer:
			return true
	return false


func _grid_layer_for_current_layout() -> ChunkLayer:
	# Prefer the ChunkLayer owned by the scene that is currently edited. The
	# inspector can temporarily keep an object from the previous scene active,
	# which must never leak its grid overlay into another canvas.
	var root: WorldLayout = EditorInterface.get_edited_scene_root() as WorldLayout
	if root != null:
		var current_layer: ChunkLayer = root.chunk_layer()
		if current_layer != null:
			return current_layer
	if _active_layer != null and is_instance_valid(_active_layer) and _active_layer.is_inside_tree():
		return _active_layer
	return null


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
		update_overlays()
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
			ToolMode.SELECT:
				_select_at(cell, button.double_click)
				return true
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
	_show_chunks.text = "Fixed chunks (grid when selected)"
	_show_chunks.button_pressed = true
	_show_chunks.toggled.connect(_on_overlay_toggled)
	_dock_content.add_child(_show_chunks)
	_show_anchors = CheckBox.new()
	_show_anchors.text = "World anchors"
	_show_anchors.button_pressed = true
	_show_anchors.toggled.connect(_on_overlay_toggled)
	_dock_content.add_child(_show_anchors)

	var selection_separator: HSeparator = HSeparator.new()
	_dock_content.add_child(selection_separator)
	var selected_title: Label = Label.new()
	selected_title.text = "Selected fixed chunk"
	selected_title.add_theme_font_size_override("font_size", 15)
	_dock_content.add_child(selected_title)
	_selected_chunk_info = Label.new()
	_selected_chunk_info.text = "No fixed chunk selected. Choose Select (Q), then click a fixed chunk."
	_selected_chunk_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_chunk_info.custom_minimum_size = Vector2(0.0, 112.0)
	_dock_content.add_child(_selected_chunk_info)
	_inspect_selected_chunk_button = Button.new()
	_inspect_selected_chunk_button.text = "Inspect SpecialChunkDef"
	_inspect_selected_chunk_button.disabled = true
	_inspect_selected_chunk_button.tooltip_text = "Open the selected SpecialChunkDef in the Inspector"
	_inspect_selected_chunk_button.pressed.connect(_on_inspect_selected_chunk_pressed)
	_dock_content.add_child(_inspect_selected_chunk_button)

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
	update_overlays()
	if _pending_open_focus:
		var target: int = _pending_focus
		_pending_focus = FocusTarget.LAYOUT
		_pending_open_focus = false
		call_deferred(&"_focus_current_layout", target)


func _on_scene_saved(_path: String) -> void:
	_refresh_editor_context()


func _on_selection_changed() -> void:
	_refresh_editor_context()
	update_overlays()


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
		_sync_overlay_controls(root as WorldLayout)
		_dock_status.text = "Layout is open. Overlay visibility follows the scene eye icons and dock toggles."
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
	update_overlays()


func _sync_overlay_controls(layout: WorldLayout) -> void:
	if layout == null:
		return
	var biomes: BiomeLayer = layout.biome_layer()
	if _show_biomes != null and biomes != null:
		_show_biomes.set_pressed_no_signal(biomes.visible)
	var chunks: ChunkLayer = layout.chunk_layer()
	if _show_chunks != null and chunks != null:
		_show_chunks.set_pressed_no_signal(chunks.visible)
	var anchors: Array[WorldAnchor] = layout.get_world_anchors()
	if _show_anchors != null and not anchors.is_empty():
		var any_visible: bool = false
		for anchor: WorldAnchor in anchors:
			any_visible = any_visible or anchor.visible
		_show_anchors.set_pressed_no_signal(any_visible)


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
			_chunk_status.text = "Select fixed chunk (double-click to inspect)"
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


func _select_at(cell: Vector2i, inspect_resource: bool = false) -> void:
	var hit: ChunkPaintPlacementDef = _active_layer.get_placement_at(cell)
	if hit == null or hit.chunk_def == null:
		_clear_selected_chunk()
		_update_chunk_status("No fixed chunk at %s" % str(cell))
		return
	_selected_placement_origin = hit.origin
	_selected_chunk_def = hit.chunk_def
	_active_layer.set_editor_selected_origin(hit.origin)
	update_overlays()
	_update_selected_chunk_info(hit)
	_update_chunk_status("Selected %s @ %s" % [str(hit.chunk_def.id), str(hit.origin)])
	if inspect_resource:
		EditorInterface.edit_resource(hit.chunk_def)


func _clear_selected_chunk() -> void:
	_selected_placement_origin = null
	_selected_chunk_def = null
	if _active_layer != null and is_instance_valid(_active_layer):
		_active_layer.clear_editor_selection()
	update_overlays()
	if _selected_chunk_info != null:
		_selected_chunk_info.text = "No fixed chunk selected. Choose Select (Q), then click a fixed chunk."
	if _inspect_selected_chunk_button != null:
		_inspect_selected_chunk_button.disabled = true


func _update_selected_chunk_info(placement: ChunkPaintPlacementDef) -> void:
	if _selected_chunk_info == null or placement == null or placement.chunk_def == null:
		return
	var chunk_def: SpecialChunkDef = placement.chunk_def
	var display_name: String = chunk_def.display_name.strip_edges()
	if display_name.is_empty():
		display_name = str(chunk_def.id)
	var allowed: String = _string_names_text(chunk_def.allowed_biomes)
	var tags: String = _string_names_text(chunk_def.tags)
	var source_path: String = chunk_def.resource_path
	if source_path.is_empty():
		source_path = "<embedded resource>"
	_selected_chunk_info.text = "%s\nID: %s\nOrigin: %s\nFootprint: %d × %d chunks\nBiomes: %s\nTags: %s\nResource: %s" % [
		display_name,
		str(chunk_def.id),
		str(placement.origin),
		chunk_def.size_in_chunks.x,
		chunk_def.size_in_chunks.y,
		allowed,
		tags,
		source_path,
	]
	_inspect_selected_chunk_button.disabled = false


func _string_names_text(values: Array[StringName]) -> String:
	if values.is_empty():
		return "<any>"
	var texts: PackedStringArray = PackedStringArray()
	for value: StringName in values:
		texts.append(str(value))
	return ", ".join(texts)


func _on_inspect_selected_chunk_pressed() -> void:
	if _selected_chunk_def != null:
		EditorInterface.edit_resource(_selected_chunk_def)


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
	_select_at(cell)
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
	if _selected_placement_origin is Vector2i and _selected_placement_origin == hit.origin:
		_clear_selected_chunk()
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
