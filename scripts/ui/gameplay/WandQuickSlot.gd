class_name WandQuickSlot
extends Button

signal wand_pressed(index: int)
signal wand_hover_changed(index: int, hovering: bool)

var wand_index: int = 0
var wand: WandDef
var equipped: bool = false

@onready var _glyph: WandGlyph = $WandGlyph
@onready var _key_label: Label = $KeyLabel

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()

func setup(index: int, definition: WandDef, is_equipped: bool) -> void:
	wand_index = index
	wand = definition
	equipped = is_equipped
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	disabled = wand == null
	_key_label.text = str(wand_index + 1)
	_glyph.setup(wand, equipped)
	add_theme_stylebox_override("normal", NoitaUITheme.highlighted_box() if equipped else NoitaUITheme.box(NoitaUITheme.BG_SLOT, NoitaUITheme.BORDER, 1))
	add_theme_stylebox_override("hover", NoitaUITheme.hover_box())
	add_theme_stylebox_override("pressed", NoitaUITheme.highlighted_box())
	add_theme_stylebox_override("disabled", NoitaUITheme.empty_box())

func _on_pressed() -> void:
	wand_pressed.emit(wand_index)

func _on_mouse_entered() -> void:
	wand_hover_changed.emit(wand_index, true)

func _on_mouse_exited() -> void:
	wand_hover_changed.emit(wand_index, false)
