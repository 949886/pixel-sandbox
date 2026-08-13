class_name CreativeMaterialTile
extends Button

signal material_selected(element_id: int)

var element_id: int = 0
var material_color: Color = PaintingCreativeStyle.SURFACE

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(entry: MaterialEntry) -> void:
	if entry == null:
		return
	element_id = entry.engine_element_id
	text = String(entry.id).replace("_", " ").to_upper()
	material_color = entry.color
	material_color.a = 0.78
	_refresh_style(false)

func set_selected_state(selected: bool) -> void:
	_refresh_style(selected)

func _refresh_style(selected: bool) -> void:
	if selected:
		add_theme_stylebox_override("normal", PaintingCreativeStyle.selected_box())
		add_theme_stylebox_override("hover", PaintingCreativeStyle.surface_box(Color(0.980392, 0.545098, 0.243137, 1.0), 4, 4))
		return
	add_theme_stylebox_override("normal", PaintingCreativeStyle.surface_box(material_color.darkened(0.20), 4, 4))
	add_theme_stylebox_override("hover", PaintingCreativeStyle.surface_box(material_color.lightened(0.10), 4, 4))
	add_theme_stylebox_override("pressed", PaintingCreativeStyle.surface_box(material_color.darkened(0.40), 4, 4))

func _on_pressed() -> void:
	material_selected.emit(element_id)
