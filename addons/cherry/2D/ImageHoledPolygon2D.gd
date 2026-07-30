@tool
class_name ImageHoledPolygon2D
extends HoledPolygon2D

## Builds a HoledPolygon2D shape from an image/texture alpha mask.
##
## Opaque pixels become the outer shape. Fully enclosed transparent regions
## become holes. Border-touching transparent regions are ignored because they
## represent the outside of the image, not a hole.

@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		_rebuild_from_texture()

@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.1:
	set(value):
		alpha_threshold = value
		_rebuild_from_texture()

@export_range(0.1, 16.0, 0.1) var outline_epsilon: float = 2.0:
	set(value):
		outline_epsilon = value
		_rebuild_from_texture()

@export var centered_from_image: bool = true:
	set(value):
		centered_from_image = value
		_rebuild_from_texture()

@export var auto_rebuild_in_editor: bool = true

var image_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_rebuild_from_texture()


func rebuild_from_image(image: Image) -> void:
	if image == null or image.is_empty():
		_clear_shape()
		return

	image_size = image.get_size()
	var rect: Rect2i = Rect2i(Vector2i.ZERO, image_size)

	var opaque_bitmap: BitMap = BitMap.new()
	opaque_bitmap.create_from_image_alpha(image, alpha_threshold)

	var opaque_raw: Array[PackedVector2Array] = opaque_bitmap.opaque_to_polygons(rect, outline_epsilon)
	if opaque_raw.is_empty():
		_clear_shape()
		return

	var opaque_polys: Array[PackedVector2Array] = _normalize_polygon_list(opaque_raw)
	var outer_poly: PackedVector2Array = _largest_polygon(opaque_polys)
	outer_poly = _transform_image_points(outer_poly)

	var transparent_bitmap: BitMap = _make_transparent_bitmap(image)
	var transparent_raw: Array[PackedVector2Array] = transparent_bitmap.opaque_to_polygons(rect, outline_epsilon)
	var transparent_polys: Array[PackedVector2Array] = _normalize_polygon_list(transparent_raw)

	var found_holes: Array[PackedVector2Array] = []
	for transparent_poly: PackedVector2Array in transparent_polys:
		if transparent_poly.size() < 3:
			continue
		if _polygon_touches_image_border(transparent_poly, image_size):
			continue
		var probe: Vector2 = _polygon_centroid(transparent_poly)
		if not Geometry2D.is_point_in_polygon(probe, _untransform_image_points(outer_poly)):
			continue
		found_holes.append(_transform_image_points(transparent_poly))

	set_shape(outer_poly, found_holes)


func rebuild_from_texture(texture_to_read: Texture2D) -> void:
	if texture_to_read == null:
		_clear_shape()
		return
	var image: Image = texture_to_read.get_image()
	rebuild_from_image(image)


func _rebuild_from_texture() -> void:
	if not auto_rebuild_in_editor and Engine.is_editor_hint():
		return
	if source_texture == null:
		return
	rebuild_from_texture(source_texture)


func _clear_shape() -> void:
	var empty_holes: Array[PackedVector2Array] = []
	set_shape(PackedVector2Array(), empty_holes)


func _make_transparent_bitmap(image: Image) -> BitMap:
	var result: BitMap = BitMap.new()
	var size: Vector2i = image.get_size()
	result.create(size)
	for y in range(size.y):
		for x in range(size.x):
			var px: Color = image.get_pixel(x, y)
			result.set_bit(x, y, px.a <= alpha_threshold)
	return result


func _normalize_polygon_list(raw_polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in raw_polygons:
		if poly.size() >= 3 and absf(_polygon_area(poly)) > 0.001:
			result.append(poly)
	return result


func _largest_polygon(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best: PackedVector2Array = PackedVector2Array()
	var best_area: float = -1.0
	for poly: PackedVector2Array in polys:
		var area: float = absf(_polygon_area(poly))
		if area > best_area:
			best_area = area
			best = poly
	return best


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


func _transform_image_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var offset: Vector2 = Vector2.ZERO
	if centered_from_image:
		offset = -Vector2(image_size) * 0.5
	for p: Vector2 in points:
		result.append(p + offset)
	return result


func _untransform_image_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var offset: Vector2 = Vector2.ZERO
	if centered_from_image:
		offset = Vector2(image_size) * 0.5
	for p: Vector2 in points:
		result.append(p + offset)
	return result
