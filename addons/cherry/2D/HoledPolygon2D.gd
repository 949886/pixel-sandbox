@tool
class_name HoledPolygon2D
extends Polygon2D

## HoledPolygon2D demo component.
##
## Polygon2D does not natively store holes. This script exposes an outer contour
## plus holes, bridges each hole into the outer contour, triangulates the result,
## and assigns Polygon2D.polygon + Polygon2D.polygons.
##
## This is intentionally dependency-free for demo use. It works well for simple
## contours and simple holes. For production with highly concave shapes, many
## holes, or arbitrary user-authored geometry, replace the bridge step with a
## robust triangulator such as Earcut.

@export var outer: PackedVector2Array:
	set(value):
		outer = value
		_rebuild()

@export var holes: Array[PackedVector2Array] = []:
	set(value):
		holes = value
		_rebuild()

@export var draw_debug_points := false:
	set(value):
		draw_debug_points = value
		queue_redraw()

@export var debug_point_radius := 4.0:
	set(value):
		debug_point_radius = value
		queue_redraw()


func _ready() -> void:
	_rebuild()


func set_shape(new_outer: PackedVector2Array, new_holes: Array[PackedVector2Array]) -> void:
	outer = new_outer
	holes = new_holes
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return

	if outer.size() < 3:
		polygon = PackedVector2Array()
		var empty_polygons: Array[PackedInt32Array] = []
		polygons = empty_polygons
		queue_redraw()
		return

	var merged := _ensure_ccw(outer)

	for hole in holes:
		if hole.size() >= 3:
			merged = _bridge_hole(merged, _ensure_cw(hole))

	var indices := Geometry2D.triangulate_polygon(merged)

	polygon = merged

	var triangle_polygons: Array[PackedInt32Array] = []
	if indices.size() >= 3:
		for i in range(0, indices.size(), 3):
			var triangle: PackedInt32Array = PackedInt32Array([
				indices[i],
				indices[i + 1],
				indices[i + 2],
			])
			triangle_polygons.append(triangle)
		polygons = triangle_polygons
	else:
		push_warning("HoledPolygon2D: triangulation failed. Check contour winding and self-intersections.")

	queue_redraw()


func _ensure_ccw(points: PackedVector2Array) -> PackedVector2Array:
	var copy := points.duplicate()
	if Geometry2D.is_polygon_clockwise(copy):
		copy.reverse()
	return copy


func _ensure_cw(points: PackedVector2Array) -> PackedVector2Array:
	var copy := points.duplicate()
	if not Geometry2D.is_polygon_clockwise(copy):
		copy.reverse()
	return copy


func _bridge_hole(shape: PackedVector2Array, hole: PackedVector2Array) -> PackedVector2Array:
	# Simple bridge strategy:
	# 1. Pick the right-most point of the hole.
	# 2. Connect it to the closest visible outer/merged contour vertex.
	#
	# This avoids external dependencies and is enough for the demo shapes. A robust
	# production implementation should do ray casting and visibility tests.
	var hole_index := _rightmost_point_index(hole)
	var hole_point := hole[hole_index]

	var shape_index := _closest_visible_vertex_index(shape, hole_point, hole)

	var result := PackedVector2Array()

	for i in range(0, shape_index + 1):
		result.append(shape[i])

	# Enter the hole.
	result.append(hole_point)

	# Walk around the hole once.
	for offset in range(1, hole.size() + 1):
		var idx := (hole_index + offset) % hole.size()
		result.append(hole[idx])

	# Return to the outer contour.
	result.append(hole_point)
	result.append(shape[shape_index])

	for i in range(shape_index + 1, shape.size()):
		result.append(shape[i])

	return result


func _rightmost_point_index(points: PackedVector2Array) -> int:
	var result := 0
	for i in points.size():
		if points[i].x > points[result].x:
			result = i
		elif is_equal_approx(points[i].x, points[result].x) and points[i].y < points[result].y:
			result = i
	return result


func _closest_visible_vertex_index(shape: PackedVector2Array, from_point: Vector2, hole: PackedVector2Array) -> int:
	var best_index := 0
	var best_dist := INF

	for i in shape.size():
		var candidate := shape[i]
		var d := from_point.distance_squared_to(candidate)
		if d >= best_dist:
			continue
		if _segment_is_reasonably_clear(from_point, candidate, shape, hole):
			best_dist = d
			best_index = i

	return best_index


func _segment_is_reasonably_clear(a: Vector2, b: Vector2, shape: PackedVector2Array, hole: PackedVector2Array) -> bool:
	# Ignore intersections at endpoints. This is a light safety check, not a full
	# computational geometry visibility solver.
	var contours: Array[PackedVector2Array] = [shape, hole]
	for contour: PackedVector2Array in contours:
		for i in contour.size():
			var c: Vector2 = contour[i]
			var d: Vector2 = contour[(i + 1) % contour.size()]
			if _same_point(a, c) or _same_point(a, d) or _same_point(b, c) or _same_point(b, d):
				continue
			var intersection: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
			if intersection != null:
				return false
	return true


func _same_point(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) < 0.0001


func _draw() -> void:
	if not draw_debug_points:
		return

	for i in polygon.size():
		draw_circle(polygon[i], debug_point_radius, Color.ORANGE)
		draw_string(ThemeDB.fallback_font, polygon[i] + Vector2(6, -6), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.ORANGE)
