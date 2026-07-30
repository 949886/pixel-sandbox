@tool
class_name ImageHoledPolygonBuilder
extends RefCounted

## Converts an Image alpha mask into holed polygon shape data.
##
## Output format:
## Array[Dictionary], where each Dictionary is:
## {
##     "outer": PackedVector2Array,
##     "holes": Array[PackedVector2Array]
## }
##
## Coordinates are in image pixel space. The caller can center, scale, render,
## bake to resources, or generate collision shapes from the returned data.

var alpha_threshold: float = 0.1
var outline_epsilon: float = 2.0
var min_island_area: float = 8.0
var min_hole_area: float = 8.0

var image_size: Vector2i = Vector2i.ZERO
var last_island_count: int = 0
var last_hole_count: int = 0


func build_from_texture(texture: Texture2D) -> Array[Dictionary]:
	if texture == null:
		return []
	return build_from_image(texture.get_image())


func build_from_image(image: Image) -> Array[Dictionary]:
	last_island_count = 0
	last_hole_count = 0

	if image == null or image.is_empty():
		image_size = Vector2i.ZERO
		return []

	image_size = image.get_size()
	var rect: Rect2i = Rect2i(Vector2i.ZERO, image_size)

	var opaque_bitmap: BitMap = BitMap.new()
	opaque_bitmap.create_from_image_alpha(image, alpha_threshold)

	var opaque_raw: Array[PackedVector2Array] = opaque_bitmap.opaque_to_polygons(rect, outline_epsilon)
	var opaque_polys: Array[PackedVector2Array] = _normalize_polygon_list(opaque_raw, min_island_area)
	if opaque_polys.is_empty():
		return []

	opaque_polys.sort_custom(_sort_polygons_by_area_desc)

	var result: Array[Dictionary] = []
	for opaque_poly: PackedVector2Array in opaque_polys:
		var empty_holes: Array[PackedVector2Array] = []
		result.append({
			"outer": opaque_poly,
			"holes": empty_holes,
		})

	var transparent_bitmap: BitMap = _make_transparent_bitmap(image)
	var transparent_raw: Array[PackedVector2Array] = transparent_bitmap.opaque_to_polygons(rect, outline_epsilon)
	var transparent_polys: Array[PackedVector2Array] = _normalize_polygon_list(transparent_raw, min_hole_area)

	for transparent_poly: PackedVector2Array in transparent_polys:
		if transparent_poly.size() < 3:
			continue
		if _polygon_touches_image_border(transparent_poly, image_size):
			continue

		var probe: Vector2 = _polygon_centroid(transparent_poly)
		var owner_index: int = _find_containing_island(probe, opaque_polys)
		if owner_index < 0:
			continue

		var shape_data: Dictionary = result[owner_index]
		var holes: Array[PackedVector2Array] = _typed_holes_from_dictionary(shape_data)
		holes.append(transparent_poly)
		shape_data["holes"] = holes
		result[owner_index] = shape_data

	last_island_count = result.size()
	last_hole_count = 0
	for shape_data: Dictionary in result:
		last_hole_count += _typed_holes_from_dictionary(shape_data).size()

	return result


func _typed_holes_from_dictionary(shape_data: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not shape_data.has("holes"):
		return result
	var raw_holes: Array = shape_data["holes"]
	for raw_hole: Variant in raw_holes:
		var hole: PackedVector2Array = raw_hole
		result.append(hole)
	return result


func _make_transparent_bitmap(image: Image) -> BitMap:
	var result: BitMap = BitMap.new()
	var size: Vector2i = image.get_size()
	result.create(size)
	for y in range(size.y):
		for x in range(size.x):
			var px: Color = image.get_pixel(x, y)
			result.set_bit(x, y, px.a <= alpha_threshold)
	return result


func _normalize_polygon_list(raw_polygons: Array[PackedVector2Array], min_area: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in raw_polygons:
		if poly.size() >= 3 and absf(_polygon_area(poly)) >= min_area:
			result.append(poly)
	return result


func _sort_polygons_by_area_desc(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return absf(_polygon_area(a)) > absf(_polygon_area(b))


func _find_containing_island(point: Vector2, opaque_polys: Array[PackedVector2Array]) -> int:
	for i in opaque_polys.size():
		if Geometry2D.is_point_in_polygon(point, opaque_polys[i]):
			return i
	return -1


func _polygon_area(poly: PackedVector2Array) -> float:
	var area: float = 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / float(poly.size())


func _polygon_touches_image_border(poly: PackedVector2Array, size: Vector2i) -> bool:
	for p: Vector2 in poly:
		if p.x <= 0.001:
			return true
		if p.y <= 0.001:
			return true
		if p.x >= float(size.x) - 0.001:
			return true
		if p.y >= float(size.y) - 0.001:
			return true
	return false
