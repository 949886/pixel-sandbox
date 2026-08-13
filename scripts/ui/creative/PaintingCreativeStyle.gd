class_name PaintingCreativeStyle
extends RefCounted

const BASE_THEME: Theme = preload("res://painting/ui/_theme/theme.tres")

const PANEL_BG: Color = Color(0.509804, 0.517647, 0.560784, 1.0)
const SURFACE: Color = Color(0.313726, 0.313726, 0.360784, 1.0)
const SURFACE_HOVER: Color = Color(0.416687, 0.416761, 0.472713, 1.0)
const SURFACE_PRESSED: Color = Color(0.188235, 0.188235, 0.239216, 1.0)
const SURFACE_DARK: Color = Color(0.223529, 0.215686, 0.278431, 1.0)
const SELECTED: Color = Color(1.0, 0.65098, 0.25098, 1.0)
const SELECTED_DARK: Color = Color(0.839216, 0.364706, 0.0941176, 1.0)
const TEXT: Color = Color.WHITE
const MUTED: Color = Color(0.88, 0.88, 0.92, 1.0)
const VALID: Color = Color(0.317647, 0.631373, 0.988235, 1.0)

static func panel_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.expand_margin_top = 30.0
	style.anti_aliasing = false
	return style

static func surface_box(color: Color = SURFACE, radius: int = 4, bottom_border: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.anti_aliasing = false
	if bottom_border > 0:
		style.border_width_bottom = bottom_border
		style.border_color = SURFACE_DARK
	return style

static func selected_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = surface_box(SELECTED_DARK, 4, 4)
	style.border_color = Color.WHITE
	return style

static func slot_box(selected: bool = false, drop_hover: bool = false) -> StyleBoxFlat:
	if drop_hover:
		var hover_style: StyleBoxFlat = surface_box(VALID, 4, 3)
		hover_style.border_color = Color.WHITE
		return hover_style
	if selected:
		return selected_box()
	return surface_box(SURFACE, 4, 4)

static func label(control: Label, font_size: int = 15, color: Color = TEXT) -> void:
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)

static func style_tab_button(button: Button, active: bool) -> void:
	button.add_theme_font_size_override("font_size", 15)
	if active:
		button.add_theme_stylebox_override("normal", selected_box())
		button.add_theme_stylebox_override("hover", surface_box(Color(0.980392, 0.545098, 0.243137, 1.0), 4, 4))
		button.add_theme_stylebox_override("pressed", surface_box(SELECTED_DARK, 4, 4))
		button.add_theme_color_override("font_color", Color.WHITE)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_color_override("font_color")
static func style_line_edit(control: LineEdit, font_size: int = 15) -> void:
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_stylebox_override("normal", surface_box(SURFACE, 4, 0))
	control.add_theme_stylebox_override("focus", surface_box(Color(0.247059, 0.247059, 0.301961, 1.0), 4, 0))

static func style_spin_box(control: SpinBox, width: float = 105.0) -> void:
	control.custom_minimum_size.x = width
	var edit: LineEdit = control.get_line_edit()
	if edit != null:
		style_line_edit(edit, 15)

