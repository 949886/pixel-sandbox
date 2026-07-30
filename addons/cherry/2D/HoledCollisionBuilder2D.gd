class_name HoledCollisionBuilder2D
extends RefCounted

## Converts alpha-mask images into convex triangle polygons suitable for
## CollisionPolygon2D.
##
## Polygons with holes are triangulated with Earcut, which accepts hole rings
## directly. This avoids the weakly-simple contour produced by the old bridge
## method and keeps triangle count proportional to contour complexity rather
## than opaque pixel area.

const EarcutTriangulatorScript = preload("res://addons/cherry/2D/EarcutTriangulator2D.cs")

var alpha_threshold: float = 0.1
var outline_epsilon: float = 2.0
var min_island_area: float = 8.0
var min_hole_area: float = 8.0

var last_island_count: int = 0
var last_hole_count: int = 0
var last_triangle_count: int = 0
var last_failed_island_count: int = 0
## Kept for compatibility with the previous build. It now counts islands that
## had to use Godot's legacy bridge triangulation after Earcut returned no data.
var last_fallback_island_count: int = 0

var _earcut
var _image_builder: ImageHoledPolygonBuilder


func _init() -> void:
	_earcut = EarcutTriangulatorScript.new()
	_image_builder = ImageHoledPolygonBuilder.new()


func build_triangles_from_image(image: Image) -> Array[PackedVector2Array]:
	last_island_count = 0
	last_hole_count = 0
	last_triangle_count = 0
	last_failed_island_count = 0
	last_fallback_island_count = 0

	_image_builder.alpha_threshold = alpha_threshold
	_image_builder.outline_epsilon = outline_epsilon
	_image_builder.min_island_area = min_island_area
	_image_builder.min_hole_area = min_hole_area

	var shapes: Array[Dictionary] = _image_builder.build_from_image(image)
	last_island_count = _image_builder.last_island_count
	last_hole_count = _image_builder.last_hole_count

	var triangles: Array[PackedVector2Array] = []
	for island_index in shapes.size():
		var shape_data: Dictionary = shapes[island_index]
		var outer: PackedVector2Array = _sanitize_contour(shape_data.get("outer", PackedVector2Array()))
		if outer.size() < 3:
			continue

		var holes: Array[PackedVector2Array] = []
		var raw_holes: Array = shape_data.get("holes", [])
		for raw_hole: Variant in raw_holes:
			var hole: PackedVector2Array = _sanitize_contour(raw_hole)
			if hole.size() >= 3 and absf(_polygon_area(hole)) >= min_hole_area:
				holes.append(hole)

		var flattened := _flatten_rings(outer, holes)
		var vertices: PackedVector2Array = flattened["vertices"]
		var hole_indices: PackedInt32Array = flattened["hole_indices"]
		var indices: PackedInt32Array = _earcut.triangulate(vertices, hole_indices)

		if indices.size() >= 3 and indices.size() % 3 == 0:
			_append_indexed_triangles(triangles, vertices, indices)
			continue

		# Earcut is the normal path. Keep the previous bridge implementation only as
		# a rare compatibility fallback; unlike the old raster fallback, it does not
		# make shape count grow with filled pixel area.
		var merged: PackedVector2Array = _ensure_ccw(outer)
		for hole: PackedVector2Array in holes:
			merged = _bridge_hole(merged, _ensure_cw(hole))
		merged = _sanitize_merged_contour(merged)
		indices = Geometry2D.triangulate_polygon(merged)
		if indices.size() >= 3:
			last_fallback_island_count += 1
			_append_indexed_triangles(triangles, merged, indices)
		else:
			last_failed_island_count += 1
			push_warning("HoledCollisionBuilder2D: Earcut and legacy triangulation failed for island %d." % island_index)

	last_triangle_count = triangles.size()
	return triangles


func _flatten_rings(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Dictionary:
	var vertices := PackedVector2Array()
	var hole_indices := PackedInt32Array()

	# Earcut accepts either winding, but normalizing it makes the input stable and
	# keeps results deterministic if contours came from different sources.
	vertices.append_array(_ensure_ccw(outer))
	for hole: PackedVector2Array in holes:
		hole_indices.append(vertices.size())
		vertices.append_array(_ensure_cw(hole))

	return {
		"vertices": vertices,
		"hole_indices": hole_indices,
	}


func _append_indexed_triangles(output: Array[PackedVector2Array], points: PackedVector2Array, indices: PackedInt32Array) -> void:
	for i in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		if ia < 0 or ib < 0 or ic < 0:
			continue
		if ia >= points.size() or ib >= points.size() or ic >= points.size():
			continue

		var triangle := PackedVector2Array([
			points[ia],
			points[ib],
			points[ic],
		])
		if absf(_polygon_area(triangle)) > 0.001:
			output.append(triangle)


func _sanitize_contour(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if result.is_empty() or not _same_point(result[-1], point):
			result.append(point)
	if result.size() > 1 and _same_point(result[0], result[-1]):
		result.remove_at(result.size() - 1)

	# Repeat because deleting one collinear/spike point can expose another one.
	var previous_size := -1
	while result.size() >= 3 and result.size() != previous_size:
		previous_size = result.size()
		result = _remove_degenerate_points(result)
	return result


func _remove_degenerate_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 4:
		return points
	var result := PackedVector2Array()
	for i in points.size():
		var previous := points[(i - 1 + points.size()) % points.size()]
		var current := points[i]
		var next := points[(i + 1) % points.size()]
		if _same_point(previous, current) or _same_point(current, next):
			continue

		var before := current - previous
		var after := next - current
		var cross := before.cross(after)
		var scale := maxf(before.length() * after.length(), 1.0)
		if absf(cross) <= 0.00001 * scale:
			# Remove both ordinary collinear points and zero-area backtracking spikes.
			continue
		result.append(current)
	return result if result.size() >= 3 else points


func _sanitize_merged_contour(points: PackedVector2Array) -> PackedVector2Array:
	# Non-consecutive duplicates encode entering/leaving a bridged hole and must
	# remain. Only zero-length consecutive edges are removed here.
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if result.is_empty() or not _same_point(result[-1], point):
			result.append(point)
	if result.size() > 1 and _same_point(result[0], result[-1]):
		result.remove_at(result.size() - 1)
	return result


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
