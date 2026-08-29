class_name GameplayUI
extends CanvasLayer

@export var spell_slot_scene: PackedScene
@export var wand_row_scene: PackedScene
@export var wand_quick_slot_scene: PackedScene
@export var status_label_scene: PackedScene


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
	_bind_scene_nodes()
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
	if _gameplay_input_blocked():
		if _inventory_open:
			set_inventory_open(false)
		return
	if _creative_mode_active():
		if _inventory_open:
			set_inventory_open(false)
		return
	if event.is_action_pressed(&"inventory_toggle"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and _inventory_open:
		set_inventory_open(false)
		get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	set_inventory_open(not _inventory_open)

func set_inventory_open(open: bool) -> void:
	if open and _gameplay_input_blocked():
		return
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

func _bind_scene_nodes() -> void:
	_root = %Root
	_quick_root = %QuickRoot
	_wand_quick_row = %WandQuickRow
	_spell_inventory_section = %SpellInventorySection
	_spell_inventory_grid = %SpellInventoryGrid
	_inventory_layer = %InventoryLayer
	_editor_root = %EditorRoot
	_wand_rows = %WandRows
	_wand_detail_panel = %WandDetailPanel
	_wand_detail_title = %WandDetailTitle
	_wand_detail_body = %WandDetailBody
	_spell_tooltip = %SpellTooltip
	_tooltip_icon = %TooltipIcon
	_tooltip_title = %TooltipTitle
	_tooltip_kind = %TooltipKind
	_tooltip_body = %TooltipBody
	_close_hint = %CloseHint
	_health_bar = %HealthBar
	_health_text = %HealthText
	_mana_bar = %ManaBar
	_mana_text = %ManaText
	_fuel_bar = %FuelBar
	_fuel_text = %FuelText
	_gold_label = %GoldLabel
	_status_box = %StatusBox
	_death_label = %DeathLabel
	_toast_panel = %ToastPanel
	_toast_icon = %ToastIcon
	_toast_label = %ToastLabel
	_drag_layer = %DragLayer
	_drag_preview_panel = %DragPreviewPanel
	_drag_preview_icon = %DragPreviewIcon

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
	var row: WandRowUI = wand_row_scene.instantiate() as WandRowUI
	row.setup(
		index,
		wand,
		_inventory,
		index == _editor_wand_index,
		_inventory != null and index == _inventory.equipped_wand_index,
		_selected_location
	)
	row.row_pressed.connect(_select_wand_row)
	row.hover_changed.connect(_on_wand_row_hover)
	row.slot_pressed.connect(_on_slot_pressed)
	row.spell_dropped.connect(_on_spell_dropped)
	row.slot_hover_changed.connect(_on_slot_hover_changed)
	row.quick_move_requested.connect(_on_quick_move_requested)
	row.drag_visual_started.connect(_on_drag_visual_started)
	return row

func _select_wand_row(index: int) -> void:
	_editor_wand_index = index
	_selected_location.clear()
	_refresh_inventory_editor()

func _make_wand_quick_slot(index: int, wand: WandDef, equipped: bool) -> Control:
	var slot: WandQuickSlot = wand_quick_slot_scene.instantiate() as WandQuickSlot
	slot.setup(index, wand, equipped)
	slot.wand_pressed.connect(_equip_wand_from_quickbar)
	slot.wand_hover_changed.connect(_on_wand_row_hover)
	return slot

func _add_spell_slot(parent: Control, location: Dictionary, spell: SpellDef, index_text: String, compact: bool) -> void:
	var slot: SpellSlot = spell_slot_scene.instantiate() as SpellSlot
	slot.setup(location, spell, index_text, compact)
	parent.add_child(slot)
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

func _on_player_died(_player_id: int, _context: Variant) -> void:
	if _death_label != null:
		_death_label.visible = _health == null or _health.current_health <= 0.0

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
		var label: Label = status_label_scene.instantiate() as Label
		label.text = part.strip_edges().to_upper()
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

func _creative_mode_active() -> bool:
	var manager: GameModeManager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	return manager != null and manager.is_creative()

func _gameplay_input_blocked() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method(&"is_gameplay_input_blocked"):
		return false
	return bool(_player.call(&"is_gameplay_input_blocked"))
