class_name WandGlyph
extends TextureRect

const DEFAULT_MINIMUM_SIZE: Vector2 = Vector2(30.0, 30.0)

var wand: WandDef

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_MINIMUM_SIZE
	_refresh_visual()

func setup(definition: WandDef, _highlight: bool = false) -> void:
	wand = definition
	if is_node_ready():
		_refresh_visual()

func _refresh_visual() -> void:
	texture = wand.visual_texture if wand != null else null
	modulate = wand.visual_modulate if wand != null else Color.WHITE
	visible = wand != null and texture != null
