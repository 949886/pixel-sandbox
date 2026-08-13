class_name GameplayUI
extends CanvasLayer

const SLOT := 38.0
const QUICK_GAP := 6.0
const SPELL_INVENTORY_COLUMNS := 12
const WAND_SPELL_COLUMNS := 12
const SPELL_SLOT_PITCH := 40.0
const DRAG_OVERLAY_LAYER := 120

var _player: Node
var _health: HealthComponent
var _status: StatusComponent
var _wand: WandController
var _inventory: PlayerInventory

var _root: Control
var _quick_root: Control
var _wand_quick_row: HBoxContainer
var _item_quick_row: HBoxContainer
var _spell_inventory_section: VBoxContainer
var _spell_inventory_grid: GridContainer
var _inventory_layer: ColorRect
var _editor_root: Control
var _wand_rows: VBoxContainer
var _wand_detail_panel: PanelContainer
var _wand_detail_title: Label
var _wand_detail_body: Label
var _spell_tooltip: PanelContainer
var _tooltip_icon: TextureRect
var _tooltip_title: Label
var _tooltip_kind: Label
var _tooltip_body: Label
var _close_hint: Label

var _health_bar: ProgressBar
var _health_text: Label
var _mana_bar: ProgressBar
var _mana_text: Label
var _fuel_bar: ProgressBar
var _fuel_text: Label
var _gold_label: Label
var _status_box: VBoxContainer
var _death_label: Label
var _toast_panel: PanelContainer
var _toast_icon: TextureRect
var _toast_label: Label
var _drag_layer: CanvasLayer
var _drag_preview_panel: PanelContainer
var _drag_preview_icon: TextureRect

var _inventory_open := false
var _paused_before_inventory := false
var _editor_wand_index := 0
var _selected_location: Dictionary = {}
var _inventory_refresh_queued := false
var _toast_until_msec := 0
var _hovered_wand_index := -1

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_build_ui()
	call_deferred("_bind_player")

func _exit_tree() -> void:
	if _inventory_open and get_tree() != null:
		get_tree().paused = _paused_before_inventory

func _process(_delta: float) -> void:
	if _toast_panel != null and _toast_panel.visible and Time.get_ticks_msec() >= _toast_until_msec:
		_toast_panel.visible = false
	var viewport := get_viewport()
	var dragging := viewport != null and viewport.gui_is_dragging()
	if _drag_preview_panel != null and _drag_preview_panel.visible:
		if dragging:
			_drag_preview_panel.position = viewport.get_mouse_position() + Vector2(14, 14)
		else:
			_drag_preview_panel.visible = false
	if _spell_tooltip != null and _spell_tooltip.visible:
		if dragging:
			_spell_tooltip.visible = false
		else:
			_position_spell_tooltip()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory_toggle"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and _inventory_open:
		set_inventory_open(false)
		get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	set_inventory_open(not _inventory_open)

func set_inventory_open(open: bool) -> void:
	if _inventory_open == open:
		return
	_inventory_open = open
	_inventory_layer.visible = open
	_spell_inventory_section.visible = open
	_close_hint.visible = open
	if open:
		_paused_before_inventory = get_tree().paused
		get_tree().paused = true
		_selected_location.clear()
		_editor_wand_index = _inventory.equipped_wand_index if _inventory != null else 0
		_refresh_inventory_editor()
	else:
		get_tree().paused = _paused_before_inventory
		_selected_location.clear()
		_spell_tooltip.visible = false
	_refresh_quick_inventory()

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_show_toast(null, "Gameplay UI: player not found")
		return
	_health = _player.get_node_or_null("HealthComponent") as HealthComponent
	_status = _player.get_node_or_null("StatusComponent") as StatusComponent
	_wand = _player.get_node_or_null("WandController") as WandController
	_inventory = _player.get_node_or_null("PlayerInventory") as PlayerInventory
	if _player.has_signal("flight_fuel_changed"):
		_player.connect("flight_fuel_changed", Callable(self, "_on_flight_fuel_changed"))
	if _player.has_signal("health_changed"):
		_player.connect("health_changed", Callable(self, "_on_health_changed"))
	if _player.has_signal("gold_changed"):
		_player.connect("gold_changed", Callable(self, "_on_gold_changed"))
	if _player.has_signal("player_died"):
		_player.connect("player_died", Callable(self, "_on_player_died"))
	if _status != null:
		_status.statuses_changed.connect(_on_status_changed)
	if _wand != null:
		_wand.mana_changed.connect(_on_mana_changed)
		_wand.spell_changed.connect(_on_spell_changed)
		_wand.deck_changed.connect(_on_deck_changed)
		_wand.recharge_changed.connect(_on_recharge_changed)
		if _wand.has_signal("wand_changed"):
			_wand.wand_changed.connect(_on_wand_changed)
	if _inventory != null:
		_inventory.inventory_changed.connect(_queue_inventory_refresh)
		_inventory.wand_slots_changed.connect(_queue_inventory_refresh)
		_inventory.equipped_wand_changed.connect(_on_equipped_wand_changed)
		_inventory.spell_added.connect(_on_spell_added)
		_inventory.inventory_full.connect(_on_inventory_full)
	_refresh_all()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_world_hud()
	_build_inventory_layer()
	_build_quick_inventory()
	_build_spell_tooltip()
	_build_drag_overlay()
	_build_toast()
	_build_death_overlay()

# -----------------------------------------------------------------------------
# Noita-inspired world HUD: quick inventory at top-left, vitals at top-right.
# No large bottom combat panel; the world stays visually dominant.
# -----------------------------------------------------------------------------
func _build_quick_inventory() -> void:
	_quick_root = Control.new()
	_quick_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quick_root.position = Vector2(14, 10)
	_quick_root.size = Vector2(1030, 72)
	_quick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quick_root.z_index = 20
	_root.add_child(_quick_root)

	var sections := HBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quick_root.add_child(sections)

	var wand_section := VBoxContainer.new()
	wand_section.add_theme_constant_override("separation", 2)
	sections.add_child(wand_section)
	wand_section.add_child(NoitaUITheme.section_label("WANDS"))
	_wand_quick_row = HBoxContainer.new()
	_wand_quick_row.add_theme_constant_override("separation", 2)
	wand_section.add_child(_wand_quick_row)

	var item_section := VBoxContainer.new()
	item_section.add_theme_constant_override("separation", 2)
	sections.add_child(item_section)
	item_section.add_child(NoitaUITheme.section_label("ITEMS"))
	_item_quick_row = HBoxContainer.new()
	_item_quick_row.add_theme_constant_override("separation", 2)
	item_section.add_child(_item_quick_row)
	for index: int in range(4):
		_item_quick_row.add_child(_make_empty_item_slot(index))

	_spell_inventory_section = VBoxContainer.new()
	_spell_inventory_section.add_theme_constant_override("separation", 2)
	_spell_inventory_section.visible = false
	sections.add_child(_spell_inventory_section)
	_spell_inventory_section.add_child(NoitaUITheme.section_label("SPELLS"))
	_spell_inventory_grid = GridContainer.new()
	_spell_inventory_grid.columns = 12
	_spell_inventory_grid.add_theme_constant_override("h_separation", 2)
	_spell_inventory_grid.add_theme_constant_override("v_separation", 2)
	_spell_inventory_section.add_child(_spell_inventory_grid)

func _build_world_hud() -> void:
	var hud := VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud.position = Vector2(-246, 12)
	hud.size = Vector2(230, 180)
	hud.add_theme_constant_override("separation", 3)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hud)

	var vitals := PanelContainer.new()
	vitals.add_theme_stylebox_override("panel", NoitaUITheme.box(Color(0.012, 0.012, 0.012, 0.76), Color(0, 0, 0, 0), 0))
	hud.add_child(vitals)
	var vitals_box := VBoxContainer.new()
	vitals_box.add_theme_constant_override("separation", 2)
	vitals.add_child(vitals_box)
	_health_bar = _make_thin_bar(NoitaUITheme.HP)
	_health_text = _make_vital_row(vitals_box, "♥", _health_bar, NoitaUITheme.HP)
	_mana_bar = _make_thin_bar(NoitaUITheme.MANA)
	_mana_text = _make_vital_row(vitals_box, "◆", _mana_bar, NoitaUITheme.MANA)
	_fuel_bar = _make_thin_bar(NoitaUITheme.FUEL)
	_fuel_text = _make_vital_row(vitals_box, "↑", _fuel_bar, NoitaUITheme.FUEL)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	NoitaUITheme.label(_gold_label, 12, NoitaUITheme.TEXT)
	hud.add_child(_gold_label)

	_status_box = VBoxContainer.new()
	_status_box.alignment = BoxContainer.ALIGNMENT_END
	_status_box.add_theme_constant_override("separation", 1)
	hud.add_child(_status_box)

func _build_inventory_layer() -> void:
	_inventory_layer = ColorRect.new()
	_inventory_layer.color = Color(0, 0, 0, 0.16)
	_inventory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_layer.visible = false
	_inventory_layer.z_index = 5
	_root.add_child(_inventory_layer)

	# Wand editor stack sits directly over the world instead of inside a huge centered modal.
	_editor_root = Control.new()
	_editor_root.position = Vector2(14, 92)
	_editor_root.size = Vector2(770, 520)
	_inventory_layer.add_child(_editor_root)

	_wand_rows = VBoxContainer.new()
	_wand_rows.size = Vector2(770, 500)
	_wand_rows.add_theme_constant_override("separation", 6)
	_editor_root.add_child(_wand_rows)

	_wand_detail_panel = PanelContainer.new()
	_wand_detail_panel.position = Vector2(806, 92)
	_wand_detail_panel.custom_minimum_size = Vector2(300, 0)
	_wand_detail_panel.size = Vector2(300, 0)
	_wand_detail_panel.visible = false
	_wand_detail_panel.add_theme_stylebox_override("panel", NoitaUITheme.box(NoitaUITheme.BG, NoitaUITheme.AMBER, 1))
	_inventory_layer.add_child(_wand_detail_panel)
	var detail_margin := MarginContainer.new()
	_set_margins(detail_margin, 10)
	_wand_detail_panel.add_child(detail_margin)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	detail_margin.add_child(detail_box)
	_wand_detail_title = Label.new()
	NoitaUITheme.label(_wand_detail_title, 15, NoitaUITheme.TEXT)
	detail_box.add_child(_wand_detail_title)
	_wand_detail_body = Label.new()
	_wand_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NoitaUITheme.label(_wand_detail_body, 12, NoitaUITheme.TEXT)
	detail_box.add_child(_wand_detail_body)

	_close_hint = Label.new()
	_close_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_close_hint.position = Vector2(14, -42)
	_close_hint.size = Vector2(760, 24)
	_close_hint.text = "TAB / I  CLOSE INVENTORY     ·     DRAG SPELLS BETWEEN WAND AND SPELL INVENTORY"
	NoitaUITheme.label(_close_hint, 10, NoitaUITheme.MUTED)
	_inventory_layer.add_child(_close_hint)

func _build_spell_tooltip() -> void:
	_spell_tooltip = PanelContainer.new()
	_spell_tooltip.custom_minimum_size = Vector2(286, 0)
	_spell_tooltip.size = Vector2(286, 0)
	_spell_tooltip.z_index = 50
	_spell_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_tooltip.visible = false
	_spell_tooltip.add_theme_stylebox_override("panel", NoitaUITheme.box(Color(0.012, 0.010, 0.010, 0.985), NoitaUITheme.AMBER, 1))
	_root.add_child(_spell_tooltip)
	var margin := MarginContainer.new()
	_set_margins(margin, 9)
	_spell_tooltip.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	_tooltip_icon = TextureRect.new()
	_tooltip_icon.custom_minimum_size = Vector2(44, 44)
	_tooltip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tooltip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tooltip_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_tooltip_icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_tooltip_title = Label.new()
	NoitaUITheme.label(_tooltip_title, 14, NoitaUITheme.TEXT)
	names.add_child(_tooltip_title)
	_tooltip_kind = Label.new()
	NoitaUITheme.label(_tooltip_kind, 10, NoitaUITheme.MUTED)
	names.add_child(_tooltip_kind)
	_tooltip_body = Label.new()
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NoitaUITheme.label(_tooltip_body, 11, NoitaUITheme.TEXT)
	box.add_child(_tooltip_body)

func _build_drag_overlay() -> void:
	# Native Control drag previews can be occluded by higher-z inventory controls.
	# Render the dragged spell in its own CanvasLayer so it is always visible.
	_drag_layer = CanvasLayer.new()
	_drag_layer.layer = DRAG_OVERLAY_LAYER
	_drag_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_drag_layer)
	var drag_root := Control.new()
	drag_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.add_child(drag_root)
	_drag_preview_panel = PanelContainer.new()
	_drag_preview_panel.size = Vector2(52, 52)
	_drag_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview_panel.visible = false
	_drag_preview_panel.add_theme_stylebox_override("panel", NoitaUITheme.highlighted_box())
	drag_root.add_child(_drag_preview_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview_panel.add_child(center)
	_drag_preview_icon = TextureRect.new()
	_drag_preview_icon.custom_minimum_size = Vector2(40, 40)
	_drag_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_drag_preview_icon)

func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position = Vector2(-132, 22)
	_toast_panel.size = Vector2(264, 48)
	_toast_panel.add_theme_stylebox_override("panel", NoitaUITheme.box(Color(0.018, 0.014, 0.014, 0.96), NoitaUITheme.AMBER, 1))
	_toast_panel.visible = false
	_toast_panel.z_index = 60
	_root.add_child(_toast_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_toast_panel.add_child(h)
	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(40, 40)
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_toast_icon)
	_toast_label = Label.new()
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NoitaUITheme.label(_toast_label, 11, NoitaUITheme.TEXT)
	h.add_child(_toast_label)

func _build_death_overlay() -> void:
	_death_label = Label.new()
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.position = Vector2(-190, -48)
	_death_label.size = Vector2(380, 96)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.text = "YOU DIED"
	NoitaUITheme.label(_death_label, 30, NoitaUITheme.DANGER)
	_death_label.visible = false
	_death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_death_label)

# -----------------------------------------------------------------------------
# Refresh / construction helpers
# -----------------------------------------------------------------------------
func _refresh_all() -> void:
	if _player == null:
		return
	if _health != null:
		_on_health_changed(_health.current_health, _health.maximum_health)
	_on_flight_fuel_changed(float(_player.get("flight_fuel")), float(_player.get("maximum_flight_fuel")))
	_on_gold_changed(int(_player.get("gold")))
	_on_status_changed(_status.summary_text() if _status != null else "")
	if _wand != null:
		_on_mana_changed(_wand.current_mana, _wand.maximum_mana())
	_refresh_quick_inventory()
	_refresh_inventory_editor()

func _refresh_quick_inventory() -> void:
	if _wand_quick_row == null:
		return
	_clear_control_children(_wand_quick_row)
	if _inventory == null:
		for index: int in range(4):
			_wand_quick_row.add_child(_make_wand_quick_slot(index, null, false))
		return
	for index: int in range(_inventory.wands.size()):
		_wand_quick_row.add_child(_make_wand_quick_slot(index, _inventory.wands[index], index == _inventory.equipped_wand_index))
	if _inventory_open:
		_refresh_spell_inventory_top()

func _refresh_spell_inventory_top() -> void:
	if _spell_inventory_grid == null or _inventory == null:
		return
	_clear_control_children(_spell_inventory_grid)
	for slot_index: int in range(_inventory.spell_inventory.size()):
		var location := {"area": &"inventory", "slot": slot_index}
		_add_spell_slot(_spell_inventory_grid, location, _inventory.inventory_spell(slot_index), "", false)
	_layout_inventory_sections()

func _layout_inventory_sections() -> void:
	if _editor_root == null:
		return
	var inventory_slots := _inventory.spell_inventory.size() if _inventory != null else SPELL_INVENTORY_COLUMNS
	var inventory_rows := maxi(1, ceili(float(inventory_slots) / float(SPELL_INVENTORY_COLUMNS)))
	# The quick strip starts at y=10. Its section label is roughly one slot-half high,
	# then each spell row consumes one 38px slot plus the 2px gap. Keep the wand
	# editor below the full spell inventory footprint instead of relying on y=92.
	var editor_y := maxf(92.0, 36.0 + float(inventory_rows) * SPELL_SLOT_PITCH)
	_editor_root.position.y = editor_y
	_quick_root.size.y = editor_y - 12.0
	_wand_detail_panel.position.y = editor_y

func _refresh_inventory_editor() -> void:
	if _inventory == null or _wand_rows == null:
		return
	_refresh_quick_inventory()
	_clear_control_children(_wand_rows)
	for wand_index: int in range(_inventory.wands.size()):
		var wand := _inventory.wands[wand_index]
		if wand == null:
			continue
		_wand_rows.add_child(_build_wand_row(wand_index, wand))
	_show_wand_detail(_wand_for_detail())

func _build_wand_row(index: int, wand: WandDef) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(770, 78)
	var active := index == _editor_wand_index
	var equipped := _inventory != null and index == _inventory.equipped_wand_index
	row.add_theme_stylebox_override("panel", NoitaUITheme.highlighted_box() if active else NoitaUITheme.box(NoitaUITheme.BG, NoitaUITheme.BORDER, 1))
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_wand_row_input.bind(index))
	row.mouse_entered.connect(_on_wand_row_hover.bind(index, true))
	row.mouse_exited.connect(_on_wand_row_hover.bind(index, false))

	var margin := MarginContainer.new()
	_set_margins(margin, 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	margin.add_child(h)

	var glyph_frame := PanelContainer.new()
	glyph_frame.custom_minimum_size = Vector2(56, 56)
	glyph_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	glyph_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph_frame.add_theme_stylebox_override("panel", NoitaUITheme.box(NoitaUITheme.BG_SLOT, NoitaUITheme.AMBER if equipped else NoitaUITheme.BORDER_DIM, 1))
	h.add_child(glyph_frame)
	var glyph_center := CenterContainer.new()
	glyph_center.custom_minimum_size = Vector2(56, 56)
	glyph_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph_frame.add_child(glyph_center)
	var glyph := WandGlyph.new()
	glyph.custom_minimum_size = Vector2(48, 48)
	glyph.setup(wand, equipped)
	glyph_center.add_child(glyph)

	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = 146
	summary.add_theme_constant_override("separation", 2)
	h.add_child(summary)
	var title := Label.new()
	title.text = ("%d  " % (index + 1)) + (wand.display_name if wand != null else "EMPTY")
	NoitaUITheme.label(title, 12, NoitaUITheme.TEXT if wand != null else NoitaUITheme.MUTED)
	summary.add_child(title)
	var shuffle := Label.new()
	shuffle.text = "Shuffle       %s" % ("Yes" if wand != null and wand.shuffle else "No")
	NoitaUITheme.label(shuffle, 10, NoitaUITheme.TEXT)
	summary.add_child(shuffle)
	var cast_count := Label.new()
	cast_count.text = "Spells/Cast   %d" % (maxi(1, wand.multicast) if wand != null else 0)
	NoitaUITheme.label(cast_count, 10, NoitaUITheme.TEXT)
	summary.add_child(cast_count)

	# Wand spell slots wrap into additional rows. There is intentionally no
	# horizontal scrollbar: capacity is visible at a glance, like Noita's editor.
	var spell_grid := GridContainer.new()
	spell_grid.columns = WAND_SPELL_COLUMNS
	spell_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_grid.add_theme_constant_override("h_separation", 2)
	spell_grid.add_theme_constant_override("v_separation", 2)
	h.add_child(spell_grid)
	if wand != null:
		for slot_index: int in range(_inventory.wand_capacity(index)):
			var location := {"area": &"wand", "wand": index, "slot": slot_index}
			_add_spell_slot(spell_grid, location, _inventory.wand_slot_spell(index, slot_index), "", false)
	else:
		var empty := Label.new()
		empty.text = "EMPTY WAND SLOT"
		NoitaUITheme.label(empty, 10, NoitaUITheme.MUTED)
		spell_grid.add_child(empty)
	return row

func _make_wand_quick_slot(index: int, wand: WandDef, equipped: bool) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = wand == null
	button.add_theme_stylebox_override("normal", NoitaUITheme.highlighted_box() if equipped else NoitaUITheme.box(NoitaUITheme.BG_SLOT, NoitaUITheme.BORDER, 1))
	button.add_theme_stylebox_override("hover", NoitaUITheme.hover_box())
	button.add_theme_stylebox_override("pressed", NoitaUITheme.highlighted_box())
	button.add_theme_stylebox_override("disabled", NoitaUITheme.empty_box())
	button.pressed.connect(_equip_wand_from_quickbar.bind(index))
	button.mouse_entered.connect(_on_wand_row_hover.bind(index, true))
	button.mouse_exited.connect(_on_wand_row_hover.bind(index, false))
	var glyph := WandGlyph.new()
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.setup(wand, equipped)
	button.add_child(glyph)
	var key := Label.new()
	key.position = Vector2(2, 0)
	key.size = Vector2(14, 12)
	key.text = str(index + 1)
	NoitaUITheme.label(key, 8, NoitaUITheme.MUTED)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(key)
	return button

func _make_empty_item_slot(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)
	panel.add_theme_stylebox_override("panel", NoitaUITheme.empty_box())
	panel.tooltip_text = "Item slot %d · item system coming later" % (index + 1)
	var mark := Label.new()
	mark.text = "·"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NoitaUITheme.label(mark, 15, NoitaUITheme.BORDER_DIM)
	panel.add_child(mark)
	return panel

func _add_spell_slot(parent: Control, location: Dictionary, spell: SpellDef, index_text: String, compact: bool) -> void:
	var slot := SpellSlot.new()
	parent.add_child(slot)
	slot.setup(location, spell, index_text, compact)
	slot.set_selected(not _selected_location.is_empty() and _same_location(_selected_location, location))
	slot.slot_pressed.connect(_on_slot_pressed)
	slot.spell_dropped.connect(_on_spell_dropped)
	slot.hover_changed.connect(_on_slot_hover_changed)
	slot.quick_move_requested.connect(_on_quick_move_requested)
	slot.drag_visual_started.connect(_on_drag_visual_started)

func _on_drag_visual_started(spell: SpellDef) -> void:
	if _drag_preview_panel == null or _drag_preview_icon == null or spell == null:
		return
	_drag_preview_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_drag_preview_panel.position = get_viewport().get_mouse_position() + Vector2(14, 14)
	_drag_preview_panel.visible = true
	_spell_tooltip.visible = false

# -----------------------------------------------------------------------------
# Details / tooltips
# -----------------------------------------------------------------------------
func _show_wand_detail(wand: WandDef) -> void:
	if _wand_detail_panel == null:
		return
	if wand == null:
		_wand_detail_panel.visible = false
		return
	_wand_detail_panel.visible = true
	_wand_detail_title.text = wand.display_name.to_upper()
	var equipped_text := "\nEQUIPPED" if _inventory != null and _inventory.equipped_wand() == wand else ""
	_wand_detail_body.text = "Shuffle              %s\nSpells/Cast          %d\nCast delay           %.2f s\nRechrg. Time         %.2f s\nMana max             %.0f\nMana chg. Spd        %.0f\nCapacity             %d\nSpread               %.1f DEG%s" % [
		"Yes" if wand.shuffle else "No",
		maxi(1, wand.multicast),
		wand.cast_delay,
		wand.recharge_time,
		wand.mana_max,
		wand.mana_recharge_per_second,
		wand.capacity,
		wand.spread_degrees,
		equipped_text,
	]
	_fit_content_panel(_wand_detail_panel, 300.0)

func _show_spell_tooltip(spell: SpellDef) -> void:
	if spell == null:
		_spell_tooltip.visible = false
		return
	_tooltip_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_tooltip_title.text = spell.display_name.to_upper()
	_tooltip_kind.text = _kind_name(spell.kind)
	var lines: PackedStringArray = []
	lines.append("Mana drain           %.0f" % spell.mana_cost)
	if not is_zero_approx(spell.cast_delay_add):
		lines.append("Cast delay          %+0.2f s" % spell.cast_delay_add)
	if not is_zero_approx(spell.recharge_time_add):
		lines.append("Rechrg. Time        %+0.2f s" % spell.recharge_time_add)
	if not is_zero_approx(spell.spread_degrees):
		lines.append("Spread              %+0.1f DEG" % spell.spread_degrees)
	if spell.extra_draw > 0:
		lines.append("Draw                 +%d" % spell.extra_draw)
	if spell.tags.size() > 0:
		lines.append("Tags                 %s" % ", ".join(spell.tags))
	if not spell.description.is_empty():
		lines.append("")
		lines.append(spell.description)
	_tooltip_body.text = "\n".join(lines)
	_spell_tooltip.visible = true
	_fit_content_panel(_spell_tooltip, 286.0)
	_position_spell_tooltip()

func _position_spell_tooltip() -> void:
	if _spell_tooltip == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := get_viewport().get_mouse_position() + Vector2(18, 18)
	desired.x = clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - _spell_tooltip.size.x - 8.0))
	desired.y = clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - _spell_tooltip.size.y - 8.0))
	_spell_tooltip.position = desired

func _wand_for_detail() -> WandDef:
	if _inventory == null:
		return null
	var index := _hovered_wand_index if _hovered_wand_index >= 0 else _editor_wand_index
	return _inventory.wands[index] if index >= 0 and index < _inventory.wands.size() else null

# -----------------------------------------------------------------------------
# Interaction
# -----------------------------------------------------------------------------
func _equip_wand_from_quickbar(index: int) -> void:
	if _inventory == null:
		return
	if _inventory.equip_wand(index):
		_editor_wand_index = index
		_refresh_inventory_editor()

func _on_wand_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_editor_wand_index = index
		_selected_location.clear()
		_refresh_inventory_editor()
		get_viewport().set_input_as_handled()

func _on_wand_row_hover(index: int, hovering: bool) -> void:
	_hovered_wand_index = index if hovering else -1
	_show_wand_detail(_wand_for_detail())

func _on_slot_pressed(location: Dictionary) -> void:
	if _inventory == null:
		return
	if _selected_location.is_empty():
		if _inventory.spell_at(location) == null:
			return
		_selected_location = location.duplicate(true)
	else:
		if _same_location(_selected_location, location):
			_selected_location.clear()
		else:
			_inventory.move_spell(_selected_location, location)
			_selected_location.clear()
	_queue_inventory_refresh()

func _on_spell_dropped(source: Dictionary, target: Dictionary) -> void:
	if _inventory != null:
		_inventory.move_spell(source, target)
	_selected_location.clear()
	_spell_tooltip.visible = false
	if _drag_preview_panel != null:
		_drag_preview_panel.visible = false
	_queue_inventory_refresh()

func _on_quick_move_requested(location: Dictionary) -> void:
	if _inventory == null or _inventory.spell_at(location) == null:
		return
	var area := StringName(location.get("area", &""))
	var target: Dictionary = {}
	if area == &"inventory":
		target = _first_empty_wand_location(_editor_wand_index)
	elif area == &"wand":
		target = _first_empty_inventory_location()
	if target.is_empty():
		_show_toast(_inventory.spell_at(location), "NO EMPTY SPELL SLOT")
		return
	_inventory.move_spell(location, target)
	_selected_location.clear()
	_spell_tooltip.visible = false
	_queue_inventory_refresh()

func _first_empty_inventory_location() -> Dictionary:
	if _inventory == null:
		return {}
	for index: int in range(_inventory.spell_inventory.size()):
		if _inventory.inventory_spell(index) == null:
			return {"area": &"inventory", "slot": index}
	return {}

func _first_empty_wand_location(wand_index: int) -> Dictionary:
	if _inventory == null or wand_index < 0 or wand_index >= _inventory.wands.size() or _inventory.wands[wand_index] == null:
		return {}
	for slot_index: int in range(_inventory.wand_capacity(wand_index)):
		if _inventory.wand_slot_spell(wand_index, slot_index) == null:
			return {"area": &"wand", "wand": wand_index, "slot": slot_index}
	return {}

func _on_slot_hover_changed(spell: SpellDef, _location: Dictionary, hovering: bool) -> void:
	if hovering:
		_show_spell_tooltip(spell)
	else:
		_spell_tooltip.visible = false

func _queue_inventory_refresh() -> void:
	if _inventory_refresh_queued or not is_inside_tree():
		return
	_inventory_refresh_queued = true
	call_deferred("_flush_inventory_refresh")

func _flush_inventory_refresh() -> void:
	_inventory_refresh_queued = false
	if not is_inside_tree():
		return
	_refresh_quick_inventory()
	if _inventory_open:
		_refresh_inventory_editor()

# -----------------------------------------------------------------------------
# Signals / HUD
# -----------------------------------------------------------------------------
func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maxf(1.0, maximum)
	_health_bar.value = current
	_health_text.text = "%d / %d" % [int(ceil(current)), int(ceil(maximum))]
	if _death_label != null and current > 0.0:
		_death_label.visible = false

func _on_player_died() -> void:
	if _death_label != null:
		_death_label.visible = true

func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maxf(1.0, maximum)
	_mana_bar.value = current
	_mana_text.text = "%d / %d" % [int(floor(current)), int(floor(maximum))]

func _on_flight_fuel_changed(current: float, maximum: float) -> void:
	_fuel_bar.max_value = maxf(0.001, maximum)
	_fuel_bar.value = current
	_fuel_text.text = "%d%%" % int(round(100.0 * current / maxf(0.001, maximum)))

func _on_gold_changed(current: int) -> void:
	_gold_label.text = "GOLD   %d" % current

func _on_status_changed(summary: String) -> void:
	_clear_control_children(_status_box)
	if summary.is_empty():
		return
	for part: String in summary.split(","):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.text = part.strip_edges().to_upper()
		NoitaUITheme.label(label, 10, Color(0.88, 0.82, 0.66, 1.0))
		_status_box.add_child(label)

func _on_spell_changed(_index: int, _spell: SpellDef) -> void:
	pass

func _on_deck_changed(_cursor: int, _total: int) -> void:
	pass

func _on_recharge_changed(_recharging: bool, _remaining: float) -> void:
	pass

func _on_wand_changed(_definition: WandDef) -> void:
	_refresh_quick_inventory()
	if _inventory_open:
		_refresh_inventory_editor()

func _on_equipped_wand_changed(index: int, _definition: WandDef) -> void:
	_editor_wand_index = index
	_refresh_quick_inventory()
	if _inventory_open:
		_refresh_inventory_editor()

func _on_spell_added(spell: SpellDef) -> void:
	_show_toast(spell, "PICKED UP  %s" % spell.display_name.to_upper())
	_queue_inventory_refresh()

func _on_inventory_full(spell: SpellDef) -> void:
	_show_toast(spell, "SPELL INVENTORY FULL")

# -----------------------------------------------------------------------------
# Primitive helpers
# -----------------------------------------------------------------------------
func _make_vital_row(parent: VBoxContainer, symbol: String, bar: ProgressBar, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var icon := Label.new()
	icon.text = symbol
	icon.custom_minimum_size.x = 14
	NoitaUITheme.label(icon, 11, color)
	row.add_child(icon)
	row.add_child(bar)
	var value := Label.new()
	value.custom_minimum_size.x = 72
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	NoitaUITheme.label(value, 10, NoitaUITheme.TEXT)
	row.add_child(value)
	return value

func _make_thin_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(118, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", NoitaUITheme.box(Color(0.055, 0.045, 0.043, 0.95), Color(0.10, 0.08, 0.07, 1.0), 1))
	bar.add_theme_stylebox_override("fill", NoitaUITheme.box(fill_color, fill_color, 0))
	return bar

func _show_toast(spell: SpellDef, text: String) -> void:
	if _toast_panel == null:
		return
	_toast_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_until_msec = Time.get_ticks_msec() + 2200


func _fit_content_panel(panel: Control, width: float) -> void:
	if panel == null:
		return
	# Width is stable for readable wrapping; height is computed only when content changes.
	# This avoids fixed empty space without adding any per-frame layout work.
	panel.custom_minimum_size = Vector2(width, 0.0)
	panel.size = Vector2(width, 0.0)
	var minimum := panel.get_combined_minimum_size()
	panel.size = Vector2(width, ceil(minimum.y))

func _kind_name(kind: int) -> String:
	match kind:
		SpellDef.Kind.PROJECTILE: return "PROJECTILE"
		SpellDef.Kind.MATERIAL: return "MATERIAL"
		SpellDef.Kind.PASSIVE: return "PASSIVE"
		SpellDef.Kind.UTILITY: return "UTILITY"
		SpellDef.Kind.STATIC: return "STATIC"
		SpellDef.Kind.MODIFIER: return "MODIFIER"
		SpellDef.Kind.MULTICAST: return "MULTICAST"
		_: return "SPELL"

func _clear_control_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _same_location(a: Dictionary, b: Dictionary) -> bool:
	return StringName(a.get("area", &"")) == StringName(b.get("area", &"")) and int(a.get("slot", -1)) == int(b.get("slot", -1)) and int(a.get("wand", -1)) == int(b.get("wand", -1))

func _set_margins(container: MarginContainer, value: int) -> void:
	container.add_theme_constant_override("margin_left", value)
	container.add_theme_constant_override("margin_top", value)
	container.add_theme_constant_override("margin_right", value)
	container.add_theme_constant_override("margin_bottom", value)

func _ensure_input_actions() -> void:
	_add_key_action(&"inventory_toggle", [KEY_TAB, KEY_I])
	if not InputMap.has_action(&"ui_cancel"):
		InputMap.add_action(&"ui_cancel")
	_add_key_action(&"ui_cancel", [KEY_ESCAPE])

func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var exists := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).keycode == key:
				exists = true
				break
		if not exists:
			var key_event := InputEventKey.new()
			key_event.keycode = key
			InputMap.action_add_event(action, key_event)
