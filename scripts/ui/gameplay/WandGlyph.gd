class_name WandGlyph
extends Control

const DEFAULT_MINIMUM_SIZE: Vector2 = Vector2(30.0, 30.0)
const DRAW_INSET_TOTAL: float = 2.0

var wand: WandDef

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Callers such as the detailed wand row can request a larger glyph. Do not
	# overwrite that size in _ready(), otherwise Container layout shrinks it back.
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_MINIMUM_SIZE
	queue_redraw()

func setup(definition: WandDef, _highlight: bool = false) -> void:
	wand = definition
	queue_redraw()

func _draw() -> void:
	if wand == null or wand.visual_texture == null:
		return
	var texture: Texture2D = wand.visual_texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	# The same Texture2D/tint is used by Player.WandSprite and the UI. Keep the
	# UI rendering nearest-filtered and integer-scaled, with no inner outline.
	var available: Vector2 = Vector2(
		maxf(1.0, size.x - DRAW_INSET_TOTAL),
		maxf(1.0, size.y - DRAW_INSET_TOTAL)
	)
	var width_scale: float = available.x / tex_size.x
	var height_scale: float = available.y / tex_size.y
	var scale_factor: float = floorf(minf(width_scale, height_scale))
	scale_factor = maxf(1.0, scale_factor)
	var draw_size: Vector2 = tex_size * scale_factor
	var origin: Vector2 = ((size - draw_size) * 0.5).floor()
	draw_texture_rect(texture, Rect2(origin, draw_size), false, wand.visual_modulate)
