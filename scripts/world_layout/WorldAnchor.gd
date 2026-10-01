@tool
class_name WorldAnchor
extends Marker2D

## Semantic world position authored directly in the WorldLayout scene.
@export var anchor_id: StringName = &""
@export var tags: Array[StringName] = []
@export_range(0.0, 256.0, 1.0) var clearance_radius: float = 20.0
@export var clearance_offset: Vector2 = Vector2(0.0, -10.0)

@export_category("Editor visualization")
@export var editor_color: Color = Color(0.2, 0.9, 0.95, 1.0)
@export var editor_radius: float = 14.0
@export var draw_editor_label: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		visible = false


func is_valid() -> bool:
	return anchor_id != &"" and clearance_radius >= 0.0


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var radius: float = maxf(editor_radius, 4.0)
	var fill: Color = editor_color
	fill.a = 0.22
	draw_circle(Vector2.ZERO, radius, fill)
	draw_circle(Vector2.ZERO, radius, editor_color, false, 2.0)
	draw_line(Vector2(-radius - 5.0, 0.0), Vector2(radius + 5.0, 0.0), editor_color, 2.0)
	draw_line(Vector2(0.0, -radius - 5.0), Vector2(0.0, radius + 5.0), editor_color, 2.0)
	if not draw_editor_label:
		return
	var text: String = str(anchor_id)
	if text.is_empty():
		text = str(name)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(14, ThemeDB.fallback_font_size)
	draw_string(font, Vector2(radius + 8.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, editor_color)
