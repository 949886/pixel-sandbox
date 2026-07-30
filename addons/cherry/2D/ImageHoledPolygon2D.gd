@tool
class_name ImageHoledPolygon2D
extends HoledPolygon2D

## Builds one Polygon2D mesh from an image/texture alpha mask.
##
## This node delegates image analysis to ImageHoledPolygonBuilder, then renders
## all returned islands into this single Polygon2D node. The split makes the
## builder reusable for baking, collision generation, and tests.

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
		_apply_last_shapes()

@export var min_island_area: float = 8.0:
	set(value):
		min_island_area = value
		_rebuild_from_texture()

@export var min_hole_area: float = 8.0:
	set(value):
		min_hole_area = value
		_rebuild_from_texture()

@export var auto_rebuild_in_editor: bool = true

var image_size: Vector2i = Vector2i.ZERO
var island_count: int = 0
var total_hole_count: int = 0
var last_shapes: Array[Dictionary] = []


func _ready() -> void:
	_rebuild_from_texture()


func rebuild_from_image(image: Image) -> void:
	var builder: ImageHoledPolygonBuilder = _make_builder()
	last_shapes = builder.build_from_image(image)
	image_size = builder.image_size
	_apply_last_shapes()


func rebuild_from_texture(texture_to_read: Texture2D) -> void:
	if texture_to_read == null:
		_clear_shape()
		return
	rebuild_from_image(texture_to_read.get_image())


func build_shape_data_from_image(image: Image) -> Array[Dictionary]:
	var builder: ImageHoledPolygonBuilder = _make_builder()
	return builder.build_from_image(image)


func build_shape_data_from_texture(texture_to_read: Texture2D) -> Array[Dictionary]:
	var builder: ImageHoledPolygonBuilder = _make_builder()
	return builder.build_from_texture(texture_to_read)


func _make_builder() -> ImageHoledPolygonBuilder:
	var builder: ImageHoledPolygonBuilder = ImageHoledPolygonBuilder.new()
	builder.alpha_threshold = alpha_threshold
	builder.outline_epsilon = outline_epsilon
	builder.min_island_area = min_island_area
	builder.min_hole_area = min_hole_area
	return builder


func _rebuild_from_texture() -> void:
	if not auto_rebuild_in_editor and Engine.is_editor_hint():
		return
	if source_texture == null:
		return
	rebuild_from_texture(source_texture)


func _clear_shape() -> void:
	image_size = Vector2i.ZERO
	island_count = 0
	total_hole_count = 0
	var empty_shapes: Array[Dictionary] = []
	last_shapes = empty_shapes
	outer = PackedVector2Array()
	var empty_holes: Array[PackedVector2Array] = []
	holes = empty_holes
	polygon = PackedVector2Array()
	var empty_polygons: Array[PackedInt32Array] = []
	polygons = empty_polygons
	queue_redraw()


func _apply_last_shapes() -> void:
	if last_shapes.is_empty():
		_clear_shape()
		return
	_apply_shape_data(last_shapes)


func _apply_shape_data(shape_data_list: Array[Dictionary]) -> void:
	var combined_points: PackedVector2Array = PackedVector2Array()
	var combined_triangles: Array[PackedInt32Array] = []

	island_count = 0
	total_hole_count = 0

	# Keep representative data on inherited fields for inspection/debug.
	var first_shape: Dictionary = shape_data_list[0]
	outer = _transform_image_points(_outer_from_dictionary(first_shape))
	holes = _transform_holes(_holes_from_dictionary(first_shape))

	for island_index in shape_data_list.size():
		var shape_data: Dictionary = shape_data_list[island_index]
		var island_outer: PackedVector2Array = _transform_image_points(_outer_from_dictionary(shape_data))
		var island_hole_list: Array[PackedVector2Array] = _transform_holes(_holes_from_dictionary(shape_data))

		var merged: PackedVector2Array = _ensure_ccw(island_outer)
		for island_hole: PackedVector2Array in island_hole_list:
			if island_hole.size() >= 3:
				merged = _bridge_hole(merged, _ensure_cw(island_hole))

		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(merged)
		if indices.size() < 3:
			push_warning("ImageHoledPolygon2D: triangulation failed for island %d." % island_index)
			continue

		var offset: int = combined_points.size()
		for p: Vector2 in merged:
			combined_points.append(p)

		for i in range(0, indices.size(), 3):
			combined_triangles.append(PackedInt32Array([
				offset + indices[i],
				offset + indices[i + 1],
				offset + indices[i + 2],
			]))

		island_count += 1
		total_hole_count += island_hole_list.size()

	polygon = combined_points
	polygons = combined_triangles
	queue_redraw()


func _outer_from_dictionary(shape_data: Dictionary) -> PackedVector2Array:
	if not shape_data.has("outer"):
		return PackedVector2Array()
	var result: PackedVector2Array = shape_data["outer"]
	return result


func _holes_from_dictionary(shape_data: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not shape_data.has("holes"):
		return result
	var raw_holes: Array = shape_data["holes"]
	for raw_hole: Variant in raw_holes:
		var hole: PackedVector2Array = raw_hole
		result.append(hole)
	return result


func _transform_holes(raw_holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for raw_hole: PackedVector2Array in raw_holes:
		result.append(_transform_image_points(raw_hole))
	return result


func _transform_image_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var offset: Vector2 = Vector2.ZERO
	if centered_from_image:
		offset = -Vector2(image_size) * 0.5
	for p: Vector2 in points:
		result.append(p + offset)
	return result
