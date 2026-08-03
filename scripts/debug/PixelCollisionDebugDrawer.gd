class_name PixelCollisionDebugDrawer
extends Node2D

## Lightweight visualization for the exact rectangle snapshot currently committed
## to PhysicsServer2D. It creates no CollisionShape2D nodes and is enabled only
## while the F6 collision debug layer is visible.
var _rects: PackedInt32Array = PackedInt32Array()

func _ready() -> void:
	top_level = false
	z_index = 1000
	visible = false

func set_collision_rects(rects: PackedInt32Array) -> void:
	_rects = rects.duplicate()
	queue_redraw()

func clear_collision_rects() -> void:
	_rects = PackedInt32Array()
	queue_redraw()

func _draw() -> void:
	if _rects.is_empty():
		return
	var fill := Color(0.05, 0.85, 1.0, 0.20)
	var outline := Color(0.10, 0.95, 1.0, 0.95)
	var rect_count: int = int(_rects.size() / 4)
	for index: int in range(rect_count):
		var base: int = index * 4
		var rect := Rect2(
			float(_rects[base]),
			float(_rects[base + 1]),
			float(_rects[base + 2]),
			float(_rects[base + 3])
		)
		draw_rect(rect, fill, true)
		draw_rect(rect, outline, false, 1.0, false)
