@tool
class_name SpecialChunkPalettePanel
extends VBoxContainer

## TileMap-like bottom palette for choosing authored SpecialChunk brushes.
##
## The panel never scans project directories. Its content is supplied by the
## selected ChunkLayer.palette_chunks array, while filter metadata comes from
## SpecialChunkDef.tags. This keeps authoring data explicit and deterministic.
signal chunk_selected(chunk_def: SpecialChunkDef)
signal chunk_activated(chunk_def: SpecialChunkDef)
signal inspect_requested(chunk_def: SpecialChunkDef)

enum TagMatchMode {
	ANY,
	ALL,
}

const TAG_CLEAR_ID: int = 1
const TAG_FIRST_ID: int = 1000
const ICON_SIZE: Vector2i = Vector2i(112, 72)
const ITEM_WIDTH: int = 132

var _chunks: Array[SpecialChunkDef] = []
var _selected_chunk: SpecialChunkDef = null
var _selected_tags: Dictionary = {}
var _tag_by_menu_id: Dictionary = {}
var _solid_icon_cache: Dictionary = {}
var _built: bool = false

var _search: LineEdit = null
var _tag_button: MenuButton = null
var _tag_match: OptionButton = null
var _clear_filters: Button = null
var _items: ItemList = null
var _result_label: Label = null
var _selection_label: Label = null
var _inspect_button: Button = null


func _ready() -> void:
	_ensure_built()


func set_chunks(chunks: Array[SpecialChunkDef], preferred: SpecialChunkDef = null) -> void:
	_ensure_built()
	_chunks.clear()
	var seen_ids: Dictionary = {}
	for chunk_def: SpecialChunkDef in chunks:
		if chunk_def == null or chunk_def.id == &"":
			continue
		if seen_ids.has(chunk_def.id):
			continue
		seen_ids[chunk_def.id] = true
		_chunks.append(chunk_def)
	_prune_selected_tags()
	_rebuild_tag_menu()

	var next_selection: SpecialChunkDef = preferred
	if next_selection == null or not _chunks.has(next_selection):
		next_selection = _selected_chunk if _chunks.has(_selected_chunk) else null
	if next_selection == null and not _chunks.is_empty():
		next_selection = _chunks[0]
	_selected_chunk = next_selection
	_rebuild_items()


func selected_chunk() -> SpecialChunkDef:
	return _selected_chunk


func select_chunk(chunk_def: SpecialChunkDef, reveal: bool = false, emit_signal: bool = false) -> bool:
	_ensure_built()
	if chunk_def == null or not _chunks.has(chunk_def):
		return false
	_selected_chunk = chunk_def
	if reveal and not _passes_filters(chunk_def):
		_clear_filter_state()
		_rebuild_tag_menu()
		_rebuild_items()
	else:
		_sync_item_selection()
	_update_selection_details()
	if emit_signal:
		chunk_selected.emit(chunk_def)
	return true


func clear_filters() -> void:
	_ensure_built()
	_clear_filter_state()
	_rebuild_tag_menu()
	_rebuild_items()


func set_search_text(text: String) -> void:
	_ensure_built()
	_search.text = text
	_rebuild_items()


func set_tag_filter(tags: Array[StringName], match_mode: int = TagMatchMode.ANY) -> void:
	_ensure_built()
	_selected_tags.clear()
	for tag: StringName in tags:
		if tag != &"":
			_selected_tags[tag] = true
	_tag_match.select(clampi(match_mode, TagMatchMode.ANY, TagMatchMode.ALL))
	_rebuild_tag_menu()
	_rebuild_items()


func visible_chunk_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for chunk_def: SpecialChunkDef in _filtered_chunks():
		result.append(chunk_def.id)
	return result


func available_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for chunk_def: SpecialChunkDef in _chunks:
		for tag: StringName in chunk_def.tags:
			if tag == &"" or seen.has(tag):
				continue
			seen[tag] = true
			result.append(tag)
	result.sort_custom(_tag_less_than)
	return result


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	name = "SpecialChunkPalette"
	custom_minimum_size = Vector2(0.0, 235.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	add_child(filter_row)

	var title: Label = Label.new()
	title.text = "SpecialChunk Palette"
	title.add_theme_font_size_override("font_size", 15)
	filter_row.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Search name, ID, biome, or tag…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(260.0, 0.0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search_changed)
	filter_row.add_child(_search)

	_tag_button = MenuButton.new()
	_tag_button.text = "Tags: All"
	_tag_button.tooltip_text = "Filter SpecialChunks by one or more tags"
	_tag_button.custom_minimum_size = Vector2(132.0, 0.0)
	var tag_popup: PopupMenu = _tag_button.get_popup()
	tag_popup.hide_on_checkable_item_selection = false
	tag_popup.id_pressed.connect(_on_tag_menu_id_pressed)
	filter_row.add_child(_tag_button)

	_tag_match = OptionButton.new()
	_tag_match.tooltip_text = "How multiple selected tags are matched"
	_tag_match.add_item("Match any", TagMatchMode.ANY)
	_tag_match.add_item("Match all", TagMatchMode.ALL)
	_tag_match.select(TagMatchMode.ANY)
	_tag_match.item_selected.connect(_on_tag_match_selected)
	filter_row.add_child(_tag_match)

	_clear_filters = Button.new()
	_clear_filters.text = "Clear"
	_clear_filters.tooltip_text = "Clear search and tag filters"
	_clear_filters.pressed.connect(clear_filters)
	filter_row.add_child(_clear_filters)

	_items = ItemList.new()
	_items.icon_mode = ItemList.ICON_MODE_TOP
	_items.fixed_icon_size = ICON_SIZE
	_items.fixed_column_width = ITEM_WIDTH
	_items.max_columns = 1
	_items.max_text_lines = 2
	_items.same_column_width = true
	_items.allow_reselect = true
	_items.select_mode = ItemList.SELECT_SINGLE
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.custom_minimum_size = Vector2(0.0, 150.0)
	_items.item_selected.connect(_on_item_selected)
	_items.item_activated.connect(_on_item_activated)
	_items.resized.connect(_update_item_columns)
	add_child(_items)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	add_child(footer)

	_result_label = Label.new()
	_result_label.text = "0 / 0 chunks"
	_result_label.custom_minimum_size = Vector2(120.0, 0.0)
	footer.add_child(_result_label)

	_selection_label = Label.new()
	_selection_label.text = "Brush: —"
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_selection_label)

	_inspect_button = Button.new()
	_inspect_button.text = "Inspect"
	_inspect_button.disabled = true
	_inspect_button.tooltip_text = "Open the selected SpecialChunkDef in the Inspector"
	_inspect_button.pressed.connect(_on_inspect_pressed)
	footer.add_child(_inspect_button)

	_rebuild_tag_menu()
	_rebuild_items()
	call_deferred(&"_update_item_columns")


func _rebuild_tag_menu() -> void:
	if _tag_button == null:
		return
	var popup: PopupMenu = _tag_button.get_popup()
	popup.clear()
	_tag_by_menu_id.clear()
	popup.add_item("Clear tag filter", TAG_CLEAR_ID)
	var tags: Array[StringName] = available_tags()
	if not tags.is_empty():
		popup.add_separator()
	var next_id: int = TAG_FIRST_ID
	for tag: StringName in tags:
		popup.add_check_item(str(tag), next_id)
		var index: int = popup.get_item_index(next_id)
		popup.set_item_checked(index, _selected_tags.has(tag))
		_tag_by_menu_id[next_id] = tag
		next_id += 1
	_update_tag_button_text()


func _rebuild_items() -> void:
	if _items == null:
		return
	_items.clear()
	var filtered: Array[SpecialChunkDef] = _filtered_chunks()
	for chunk_def: SpecialChunkDef in filtered:
		var label: String = _display_name(chunk_def)
		label += "  [%d×%d]" % [chunk_def.size_in_chunks.x, chunk_def.size_in_chunks.y]
		var index: int = _items.get_item_count()
		_items.add_item(label, _icon_for_chunk(chunk_def), true)
		_items.set_item_metadata(index, chunk_def)
		_items.set_item_tooltip(index, _tooltip_for_chunk(chunk_def))
		var item_background: Color = chunk_def.editor_color.darkened(0.64)
		item_background.a = 0.9
		_items.set_item_custom_bg_color(index, item_background)
	_result_label.text = "%d / %d chunks" % [filtered.size(), _chunks.size()]
	_sync_item_selection()
	_update_selection_details()


func _update_item_columns() -> void:
	if _items == null:
		return
	# ItemList does not auto-wrap when max_columns is zero: zero means an
	# unlimited single row. Compute a responsive column cap from the panel width
	# so the palette behaves like the TileMap bottom palette at any dock size.
	var usable_width: float = maxf(_items.size.x, float(ITEM_WIDTH))
	_items.max_columns = maxi(1, floori(usable_width / float(ITEM_WIDTH)))


func _prune_selected_tags() -> void:
	var valid_tags: Dictionary = {}
	for tag: StringName in available_tags():
		valid_tags[tag] = true
	for selected_tag: Variant in _selected_tags.keys():
		if not valid_tags.has(StringName(selected_tag)):
			_selected_tags.erase(selected_tag)


func _tag_less_than(a: StringName, b: StringName) -> bool:
	return str(a).naturalnocasecmp_to(str(b)) < 0


func _filtered_chunks() -> Array[SpecialChunkDef]:
	var result: Array[SpecialChunkDef] = []
	for chunk_def: SpecialChunkDef in _chunks:
		if _passes_filters(chunk_def):
			result.append(chunk_def)
	return result


func _passes_filters(chunk_def: SpecialChunkDef) -> bool:
	if chunk_def == null:
		return false
	var needle: String = _search.text.strip_edges().to_lower() if _search != null else ""
	if not needle.is_empty():
		var parts: PackedStringArray = PackedStringArray([
			_display_name(chunk_def),
			str(chunk_def.id),
			_string_names_text(chunk_def.tags),
			_string_names_text(chunk_def.allowed_biomes),
		])
		var haystack: String = " ".join(parts).to_lower()
		if not haystack.contains(needle):
			return false

	if _selected_tags.is_empty():
		return true
	var match_mode: int = _tag_match.get_selected_id() if _tag_match != null else TagMatchMode.ANY
	if match_mode == TagMatchMode.ALL:
		for tag: Variant in _selected_tags.keys():
			if not chunk_def.tags.has(StringName(tag)):
				return false
		return true
	for tag: Variant in _selected_tags.keys():
		if chunk_def.tags.has(StringName(tag)):
			return true
	return false


func _sync_item_selection() -> void:
	if _items == null:
		return
	_items.deselect_all()
	if _selected_chunk == null:
		return
	for index: int in range(_items.get_item_count()):
		if _items.get_item_metadata(index) == _selected_chunk:
			_items.select(index)
			if _items.has_method(&"ensure_current_is_visible"):
				_items.ensure_current_is_visible()
			return


func _update_selection_details() -> void:
	if _selection_label == null or _inspect_button == null:
		return
	if _selected_chunk == null:
		_selection_label.text = "Brush: —"
		_selection_label.tooltip_text = ""
		_inspect_button.disabled = true
		return
	_selection_label.text = "Brush: %s  •  %d×%d  •  %s" % [
		_display_name(_selected_chunk),
		_selected_chunk.size_in_chunks.x,
		_selected_chunk.size_in_chunks.y,
		_string_names_text(_selected_chunk.tags),
	]
	_selection_label.tooltip_text = _tooltip_for_chunk(_selected_chunk)
	_inspect_button.disabled = false


func _icon_for_chunk(chunk_def: SpecialChunkDef) -> Texture2D:
	if chunk_def.editor_preview != null:
		return chunk_def.editor_preview
	var cache_key: String = chunk_def.editor_color.to_html(true)
	if _solid_icon_cache.has(cache_key):
		return _solid_icon_cache[cache_key] as Texture2D
	var image: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(chunk_def.editor_color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_solid_icon_cache[cache_key] = texture
	return texture


func _tooltip_for_chunk(chunk_def: SpecialChunkDef) -> String:
	var resource_path: String = chunk_def.resource_path
	if resource_path.is_empty():
		resource_path = "<embedded resource>"
	return "%s\nID: %s\nFootprint: %d × %d chunks\nBiomes: %s\nTags: %s\nResource: %s" % [
		_display_name(chunk_def),
		str(chunk_def.id),
		chunk_def.size_in_chunks.x,
		chunk_def.size_in_chunks.y,
		_string_names_text(chunk_def.allowed_biomes),
		_string_names_text(chunk_def.tags),
		resource_path,
	]


func _display_name(chunk_def: SpecialChunkDef) -> String:
	var value: String = chunk_def.display_name.strip_edges()
	return value if not value.is_empty() else str(chunk_def.id)


func _string_names_text(values: Array[StringName]) -> String:
	if values.is_empty():
		return "<none>"
	var texts: PackedStringArray = PackedStringArray()
	for value: StringName in values:
		texts.append(str(value))
	return ", ".join(texts)


func _clear_filter_state() -> void:
	_selected_tags.clear()
	if _search != null:
		_search.set_text("")
	if _tag_match != null:
		_tag_match.select(TagMatchMode.ANY)


func _update_tag_button_text() -> void:
	if _tag_button == null:
		return
	var count: int = _selected_tags.size()
	if count <= 0:
		_tag_button.text = "Tags: All"
	elif count == 1:
		_tag_button.text = "Tag: %s" % str(_selected_tags.keys()[0])
	else:
		_tag_button.text = "Tags: %d" % count
	_tag_match.visible = count > 1
	_clear_filters.disabled = count == 0 and (_search == null or _search.text.is_empty())


func _on_search_changed(_text: String) -> void:
	_rebuild_items()
	_update_tag_button_text()


func _on_tag_menu_id_pressed(id: int) -> void:
	if id == TAG_CLEAR_ID:
		_selected_tags.clear()
	else:
		var tag_value: Variant = _tag_by_menu_id.get(id)
		if tag_value == null:
			return
		var tag: StringName = StringName(tag_value)
		if _selected_tags.has(tag):
			_selected_tags.erase(tag)
		else:
			_selected_tags[tag] = true
	_rebuild_tag_menu()
	_rebuild_items()


func _on_tag_match_selected(_index: int) -> void:
	_rebuild_items()


func _on_item_selected(index: int) -> void:
	var chunk_def: SpecialChunkDef = _items.get_item_metadata(index) as SpecialChunkDef
	if chunk_def == null:
		return
	_selected_chunk = chunk_def
	_update_selection_details()
	chunk_selected.emit(chunk_def)


func _on_item_activated(index: int) -> void:
	var chunk_def: SpecialChunkDef = _items.get_item_metadata(index) as SpecialChunkDef
	if chunk_def == null:
		return
	_selected_chunk = chunk_def
	_update_selection_details()
	chunk_activated.emit(chunk_def)
	inspect_requested.emit(chunk_def)


func _on_inspect_pressed() -> void:
	if _selected_chunk != null:
		inspect_requested.emit(_selected_chunk)
