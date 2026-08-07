class_name PixelCollisionDebugDrawer
extends Node2D

## F6 visualization for the exact active PhysicsServer2D snapshot plus the
## incremental collision pipeline state. No CollisionShape2D nodes are created.
var _rects: PackedInt32Array = PackedInt32Array()
var _sector_size: int = 64
var _dirty_sectors: Array[Vector2i] = []
var _building_sectors: Array[Vector2i] = []
var _pending_sectors: Array[Vector2i] = []

func _ready() -> void:
	top_level = false
	z_index = 1000
	visible = false

func set_collision_debug_state(
	rects: PackedInt32Array,
	sector_size: int,
	dirty_sectors: Array[Vector2i],
	building_sectors: Array[Vector2i],
	pending_sectors: Array[Vector2i]
) -> void:
	_rects = rects.duplicate()
	_sector_size = maxi(1, sector_size)
	_dirty_sectors = dirty_sectors.duplicate()
	_building_sectors = building_sectors.duplicate()
	_pending_sectors = pending_sectors.duplicate()
	queue_redraw()

func set_collision_rects(rects: PackedInt32Array) -> void:
	_rects = rects.duplicate()
	queue_redraw()

func clear_collision_rects() -> void:
	_rects = PackedInt32Array()
	_dirty_sectors.clear()
	_building_sectors.clear()
	_pending_sectors.clear()
	queue_redraw()

func _draw() -> void:
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

	for coord: Vector2i in _dirty_sectors:
		_draw_sector(coord, Color(1.0, 0.15, 0.10, 0.18), Color(1.0, 0.25, 0.15, 0.95), 2.0)
	for coord: Vector2i in _building_sectors:
		_draw_sector(coord, Color(1.0, 0.75, 0.05, 0.18), Color(1.0, 0.85, 0.10, 1.0), 2.0)
	for coord: Vector2i in _pending_sectors:
		_draw_sector(coord, Color(0.95, 0.15, 1.0, 0.15), Color(1.0, 0.25, 1.0, 1.0), 2.0)

func _draw_sector(coord: Vector2i, fill: Color, outline: Color, width: float) -> void:
	var rect := Rect2(Vector2(coord * _sector_size), Vector2.ONE * float(_sector_size))
	draw_rect(rect, fill, true)
	draw_rect(rect, outline, false, width, false)
