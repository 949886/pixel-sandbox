class_name CreativeSpellTile
extends PanelContainer

signal spell_activated(spell: SpellDef)
signal drag_visual_started(spell: SpellDef)

var spell: SpellDef
var _pressed: bool = false
var _drag_started: bool = false

@onready var _icon: TextureRect = $Center/Icon

func setup(definition: SpellDef) -> void:
	spell = definition
	if is_node_ready():
		_refresh()

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_refresh()

func _refresh() -> void:
	if _icon == null:
		return
	_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	tooltip_text = "%s\n%s" % [spell.display_name, spell.description] if spell != null else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		add_theme_stylebox_override("panel", PaintingCreativeStyle.surface_box(PaintingCreativeStyle.SURFACE_HOVER, 4, 4))
	elif what == NOTIFICATION_MOUSE_EXIT:
		add_theme_stylebox_override("panel", PaintingCreativeStyle.slot_box(false, false))

func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_pressed = true
		_drag_started = false
	else:
		var activate: bool = _pressed and not _drag_started
		_pressed = false
		if activate and spell != null:
			spell_activated.emit(spell)
			accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if spell == null:
		return null
	_drag_started = true
	drag_visual_started.emit(spell)
	return {"creative_spell": true, "spell": spell}
