class_name SpellSlot
extends PanelContainer

signal slot_pressed(location: Dictionary)
signal spell_dropped(source: Dictionary, target: Dictionary)
signal hover_changed(spell: SpellDef, location: Dictionary, hovering: bool)
signal quick_move_requested(location: Dictionary)
signal drag_visual_started(spell: SpellDef)

const SLOT_SIZE := Vector2(38, 38)
const DRAG_PREVIEW_SIZE := Vector2(46, 46)

var location: Dictionary = {}
var spell: SpellDef
var selected: bool = false
var deck_cursor: bool = false
var compact: bool = false

var _icon: TextureRect
var _index_label: Label
var _uses_label: Label
var _mouse_pressed := false
var _drag_started := false
var _drop_hover := false
var _drag_source_visual := false

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hover_changed.emit(spell, location, true))
	mouse_exited.connect(func(): hover_changed.emit(spell, location, false))
	gui_input.connect(_on_gui_input)
	set_process(true)
	_build_contents()
	_refresh()

func setup(new_location: Dictionary, new_spell: SpellDef, index_text: String = "", is_compact: bool = false) -> void:
	location = new_location.duplicate(true)
	spell = new_spell
	compact = is_compact
	if _index_label != null:
		_index_label.text = index_text
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	_refresh_style()

func set_deck_cursor(value: bool) -> void:
	deck_cursor = value
	_refresh_style()

func _build_contents() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(30, 30)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_icon)

	_index_label = Label.new()
	_index_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_index_label.position = Vector2(2, 0)
	_index_label.size = Vector2(14, 12)
	NoitaUITheme.label(_index_label, 8, NoitaUITheme.MUTED)
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_index_label)

	_uses_label = Label.new()
	_uses_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_uses_label.position = Vector2(-20, -12)
	_uses_label.size = Vector2(18, 11)
	_uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	NoitaUITheme.label(_uses_label, 8, NoitaUITheme.TEXT)
	_uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_uses_label)

func _refresh() -> void:
	if _icon == null:
		return
	_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_icon.custom_minimum_size = Vector2(28, 28) if compact else Vector2(30, 30)
	_uses_label.text = "" if compact or spell == null or spell.uses <= 0 else str(spell.uses)
	_refresh_icon_modulate()
	tooltip_text = "" # Dedicated hover card owns tooltips.
	_refresh_style()

func _refresh_icon_modulate() -> void:
	if _icon == null:
		return
	if spell == null:
		_icon.modulate = Color(1, 1, 1, 0.0)
	elif _drag_source_visual:
		_icon.modulate = Color(1, 1, 1, 0.22)
	else:
		_icon.modulate = Color.WHITE

func _refresh_style() -> void:
	var style := NoitaUITheme.empty_box()
	if spell != null:
		style = NoitaUITheme.box(NoitaUITheme.BG_SLOT, NoitaUITheme.BORDER, 1)
	if deck_cursor:
		style = NoitaUITheme.highlighted_box()
	if selected:
		style = NoitaUITheme.box(Color(0.055, 0.065, 0.055, 0.98), NoitaUITheme.VALID, 2)
	if _drag_source_visual:
		style = NoitaUITheme.box(Color(0.025, 0.020, 0.020, 0.72), NoitaUITheme.BORDER_DIM, 1)
	if _drop_hover:
		style = NoitaUITheme.box(Color(0.035, 0.085, 0.045, 0.98), NoitaUITheme.VALID, 2)
	add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click or event.shift_pressed:
				_mouse_pressed = false
				_drag_started = false
				quick_move_requested.emit(location)
				accept_event()
				return
			_mouse_pressed = true
			_drag_started = false
			# Stop the parent wand-row click handler without rebuilding this slot;
			# native drag detection can still continue from the same Control.
			accept_event()
		else:
			var should_click := _mouse_pressed and not _drag_started
			_mouse_pressed = false
			if should_click:
				slot_pressed.emit(location)
				accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		slot_pressed.emit(location)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if spell == null or StringName(location.get("area", &"")) == &"runtime_deck":
		return null
	_drag_started = true
	_drag_source_visual = true
	_refresh_icon_modulate()
	_refresh_style()
	# GameplayUI owns a dedicated high-layer drag visual so the spell can never
	# disappear behind the quick inventory, wand editor, tooltips, or overlays.
	drag_visual_started.emit(spell)
	return {"spell_slot": true, "source": location.duplicate(true), "spell": spell}

func _make_drag_preview() -> Control:
	var root := Control.new()
	root.custom_minimum_size = DRAG_PREVIEW_SIZE
	root.size = DRAG_PREVIEW_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.position = -DRAG_PREVIEW_SIZE * 0.5
	panel.size = DRAG_PREVIEW_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", NoitaUITheme.highlighted_box())
	root.add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var icon := TextureRect.new()
	icon.texture = SpellIconRegistry.texture_for_spell(spell)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	return root

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid := _can_drop_payload(data) and StringName(location.get("area", &"")) != &"runtime_deck"
	if _drop_hover != valid:
		_drop_hover = valid
		_refresh_style()
	return valid

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_hover = false
	_refresh_style()
	if not _can_drop_payload(data):
		return
	var payload: Dictionary = data
	var source_variant: Variant = payload.get("source", {})
	if source_variant is Dictionary:
		var source: Dictionary = source_variant
		spell_dropped.emit(source, location)

func _can_drop_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload: Dictionary = data
	return bool(payload.get("spell_slot", false)) and payload.get("source", {}) is Dictionary

func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var dragging := viewport != null and viewport.gui_is_dragging()
	if _drag_source_visual and not dragging:
		_drag_source_visual = false
		_drag_started = false
		_mouse_pressed = false
		_refresh_icon_modulate()
		_refresh_style()
	if _drop_hover:
		var pointer_inside := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		if not dragging or not pointer_inside:
			_drop_hover = false
			_refresh_style()
