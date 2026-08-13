class_name NoitaUITheme
extends RefCounted

const BG := Color(0.018, 0.014, 0.014, 0.94)
const BG_SOFT := Color(0.028, 0.021, 0.020, 0.90)
const BG_SLOT := Color(0.060, 0.036, 0.033, 0.96)
const BORDER := Color(0.30, 0.145, 0.115, 1.0)
const BORDER_DIM := Color(0.20, 0.105, 0.085, 0.95)
const AMBER := Color(0.94, 0.63, 0.17, 1.0)
const AMBER_PALE := Color(1.0, 0.82, 0.42, 1.0)
const TEXT := Color(0.92, 0.90, 0.82, 1.0)
const MUTED := Color(0.61, 0.57, 0.50, 1.0)
const HP := Color(0.43, 0.83, 0.24, 1.0)
const MANA := Color(0.20, 0.58, 0.95, 1.0)
const FUEL := Color(0.96, 0.72, 0.18, 1.0)
const DANGER := Color(0.98, 0.27, 0.22, 1.0)
const VALID := Color(0.42, 1.0, 0.52, 1.0)

static func box(background: Color = BG, border: Color = BORDER, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	# Intentionally square: Noita's UI reads as thin pixel frames, not modern rounded cards.
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

static func empty_box() -> StyleBoxFlat:
	return box(Color(0.035, 0.023, 0.022, 0.82), BORDER_DIM, 1)

static func highlighted_box() -> StyleBoxFlat:
	return box(Color(0.075, 0.045, 0.026, 0.98), AMBER, 2)

static func hover_box() -> StyleBoxFlat:
	return box(Color(0.085, 0.050, 0.034, 0.98), AMBER_PALE, 1)

static func label(label: Label, size: int = 12, color: Color = TEXT) -> Label:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

static func section_label(text: String) -> Label:
	var result := Label.new()
	result.text = text.to_upper()
	label(result, 13, TEXT)
	return result
