class_name HoledCollisionBuilder2D
extends RefCounted

## Converts alpha-mask images into convex triangle polygons suitable for
## CollisionPolygon2D. Holes are bridged into their owning opaque island before
## triangulation, so transparent enclosed regions remain collision-free.

var alpha_threshold: float = 0.1
var outline_epsilon: float = 2.0
var min_island_area: float = 8.0
var min_hole_area: float = 8.0

var last_island_count: int = 0
var last_hole_count: int = 0
var last_triangle_count: int = 0


func build_triangles_from_image(image: Image) -> Array[PackedVector2Array]:
	last_island_count = 0
	last_hole_count = 0
	last_triangle_count = 0

	var image_builder := ImageHoledPolygonBuilder.new()
	image_builder.alpha_threshold = alpha_threshold
	image_builder.outline_epsilon = outline_epsilon
	image_builder.min_island_area = min_island_area
	image_builder.min_hole_area = min_hole_area

	var shapes: Array[Dictionary] = image_builder.build_from_image(image)
	last_island_count = image_builder.last_island_count
	last_hole_count = image_builder.last_hole_count

	var triangles: Array[PackedVector2Array] = []
	for shape_data: Dictionary in shapes:
		var outer: PackedVector2Array = shape_data.get("outer", PackedVector2Array())
		if outer.size() < 3:
			continue

		var merged: PackedVector2Array = _ensure_ccw(outer)
		var raw_holes: Array = shape_data.get("holes", [])
		for raw_hole: Variant in raw_holes:
			var hole: PackedVector2Array = raw_hole
			if hole.size() >= 3:
				merged = _bridge_hole(merged, _ensure_cw(hole))

		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(merged)
		if indices.size() < 3:
			push_warning("HoledCollisionBuilder2D: triangulation failed for an island.")
			continue

		for i in range(0, indices.size(), 3):
			var triangle := PackedVector2Array([
				merged[indices[i]],
				merged[indices[i + 1]],
				merged[indices[i + 2]],
			])
			if absf(_polygon_area(triangle)) > 0.001:
				triangles.append(triangle)

	last_triangle_count = triangles.size()
	return triangles


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
	var hole_index := _rightmost_point_index(hole)
	var hole_point := hole[hole_index]
	var shape_index := _closest_visible_vertex_index(shape, hole_point, hole)
	var result := PackedVector2Array()

	for i in range(0, shape_index + 1):
		result.append(shape[i])
	result.append(hole_point)
	for offset in range(1, hole.size() + 1):
		result.append(hole[(hole_index + offset) % hole.size()])
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
		var distance := from_point.distance_squared_to(candidate)
		if distance < best_dist and _segment_is_reasonably_clear(from_point, candidate, shape, hole):
			best_dist = distance
			best_index = i
	return best_index


func _segment_is_reasonably_clear(a: Vector2, b: Vector2, shape: PackedVector2Array, hole: PackedVector2Array) -> bool:
	var contours: Array[PackedVector2Array] = [shape, hole]
	for contour: PackedVector2Array in contours:
		for i in contour.size():
			var c := contour[i]
			var d := contour[(i + 1) % contour.size()]
			if _same_point(a, c) or _same_point(a, d) or _same_point(b, c) or _same_point(b, d):
				continue
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
	return true


func _same_point(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) < 0.0001


func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5
