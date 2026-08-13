class_name SpellSlot
extends PanelContainer

signal slot_pressed(location: Dictionary)
signal spell_dropped(source: Dictionary, target: Dictionary)
signal hover_changed(spell: SpellDef, location: Dictionary, hovering: bool)
signal quick_move_requested(location: Dictionary)
signal drag_visual_started(spell: SpellDef)
signal creative_spell_dropped(spell: SpellDef, target: Dictionary)

const SLOT_SIZE := Vector2(38, 38)
const DRAG_PREVIEW_SIZE := Vector2(46, 46)

var location: Dictionary = {}
var spell: SpellDef
var selected: bool = false
var deck_cursor: bool = false
var compact: bool = false
var painting_style: bool = false

@onready var _icon: TextureRect = $Center/Icon
@onready var _index_label: Label = $IndexLabel
@onready var _uses_label: Label = $UsesLabel
var _mouse_pressed := false
var _drag_started := false
var _drop_hover := false
var _drag_source_visual := false

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	if painting_style:
		custom_minimum_size = Vector2(48, 48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hover_changed.emit(spell, location, true))
	mouse_exited.connect(func(): hover_changed.emit(spell, location, false))
	gui_input.connect(_on_gui_input)
	set_process(true)
	_apply_scene_label_style()
	_refresh()

func setup(new_location: Dictionary, new_spell: SpellDef, index_text: String = "", is_compact: bool = false, use_painting_style: bool = false) -> void:
	location = new_location.duplicate(true)
	spell = new_spell
	compact = is_compact
	painting_style = use_painting_style
	if _index_label != null:
		_index_label.text = index_text
		_apply_scene_label_style()
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	_refresh_style()

func set_deck_cursor(value: bool) -> void:
	deck_cursor = value
	_refresh_style()

func _apply_scene_label_style() -> void:
	if painting_style:
		PaintingCreativeStyle.label(_index_label, 10, PaintingCreativeStyle.MUTED)
		PaintingCreativeStyle.label(_uses_label, 10, PaintingCreativeStyle.TEXT)
	else:
		NoitaUITheme.label(_index_label, 8, NoitaUITheme.MUTED)
		NoitaUITheme.label(_uses_label, 8, NoitaUITheme.TEXT)

func _refresh() -> void:
	if _icon == null:
		return
	_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	if painting_style:
		_icon.custom_minimum_size = Vector2(34, 34)
	else:
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
	if painting_style:
		var painting_box: StyleBoxFlat = PaintingCreativeStyle.slot_box(selected or deck_cursor, _drop_hover)
		if _drag_source_visual:
			painting_box = PaintingCreativeStyle.surface_box(Color(0.28, 0.28, 0.32, 0.72), 4, 4)
		add_theme_stylebox_override("panel", painting_box)
		return
	var style: StyleBox = NoitaUITheme.empty_box()
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
	if bool(payload.get("creative_spell", false)):
		var creative_spell: SpellDef = payload.get("spell", null) as SpellDef
		if creative_spell != null:
			creative_spell_dropped.emit(creative_spell, location)
		return
	var source_variant: Variant = payload.get("source", {})
	if source_variant is Dictionary:
		var source: Dictionary = source_variant
		spell_dropped.emit(source, location)

func _can_drop_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload: Dictionary = data
	if bool(payload.get("creative_spell", false)):
		return payload.get("spell", null) is SpellDef
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
