extends TextureRect
class_name Canvas

## The simulation image is rendered by TextureRect in control-space pixels,
## while polygons returned by BitMap are in image-space pixels. Collision
## triangles are therefore mapped through the exact TextureRect draw rectangle
## before they are assigned to CollisionPolygon2D.

var image: Image:
	set(value):
		image = value
		if texture is ImageTexture and image != null:
			(texture as ImageTexture).set_image(image)

var solid_image: Image

var _thread: Thread = Thread.new()
var _thread_exit_requested: bool = false
var _static_body: StaticBody2D = StaticBody2D.new()

@onready var main: Main = get_tree().get_root().get_node("Main") as Main


func _ready() -> void:
	%SizeCopy.resized.connect(_on_resized)
	texture = ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGBA8))
	_static_body.name = "GeneratedCollisionRoot"
	add_child(_static_body)
	_thread.start(background_task.bind("generate_collider"))


func _on_resized() -> void:
	size = %SizeCopy.size


func _exit_tree() -> void:
	_thread_exit_requested = true
	# Release the worker if it is waiting for the main thread to install a body.
	semaphore.post()
	if _thread.is_started():
		_thread.wait_to_finish()


func repaint() -> void:
	var sim: SandSimulation = main.sim
	var width: int = sim.get_width()
	var height: int = sim.get_height()
	if width <= 0 or height <= 0:
		return

	var data: PackedByteArray = sim.get_color_image(Settings.flat_mode)
	var solid_data: PackedByteArray = sim.get_color_image_of_state(0)
	image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	solid_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, solid_data)


## Converts a Canvas-local point to simulation/image coordinates using the same
## draw rectangle used by both TextureRect and the generated collision body.
## This also removes the small mouse offset that occurred when the control size
## was not an exact multiple of Settings.px_scale.
func local_to_image_position(local_position: Vector2) -> Vector2:
	if image == null or image.is_empty():
		return Vector2.ZERO

	var source_size_i: Vector2i = image.get_size()
	if source_size_i.x <= 0 or source_size_i.y <= 0:
		return Vector2.ZERO

	var source_size := Vector2(source_size_i)
	var draw_rect: Rect2 = _get_texture_draw_rect(source_size)
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return Vector2.ZERO

	var normalized: Vector2 = (local_position - draw_rect.position) / draw_rect.size
	if flip_h:
		normalized.x = 1.0 - normalized.x
	if flip_v:
		normalized.y = 1.0 - normalized.y
	return normalized * source_size


@export var update_collider: bool = false
@export_range(0.0, 1.0, 0.01) var collider_alpha_threshold: float = 0.1
## BitMap uses this value as the RDP simplification tolerance in image pixels.
## 2.0 can visibly pull the collision several display pixels away from pixel art;
## 0.5 greatly reduces visible edge drift while keeping contour complexity reasonable.
@export_range(0.0, 16.0, 0.05) var collider_outline_epsilon: float = 1.5
@export var collider_min_island_area: float = 8.0
@export var collider_min_hole_area: float = 8.0
@export var max_collision_triangles: int = 12000


func background_task(_param: Variant) -> void:
	# Reuse the builder so the GDScript Earcut triangulator and its node pool are
	# reused every pass.
	var builder := HoledCollisionBuilder2D.new()
	while not _thread_exit_requested:
		# Keep a local reference. repaint() replaces solid_image with a new Image, so
		# the worker always completes against one consistent frame.
		var source_image: Image = solid_image
		if not Main.active or source_image == null or source_image.is_empty():
			OS.delay_msec(10)
			continue

		var start_time: int = Time.get_ticks_usec()
		builder.alpha_threshold = collider_alpha_threshold
		builder.outline_epsilon = collider_outline_epsilon
		builder.min_island_area = collider_min_island_area
		builder.min_hole_area = collider_min_hole_area

		var polys: Array[PackedVector2Array] = builder.build_triangles_from_image(source_image)
		var source_size: Vector2i = source_image.get_size()
		var build_succeeded: bool = builder.last_failed_island_count == 0

		# Never replace the current body with a partial collider. Pass the source
		# image size with the polygons so the main thread can map image coordinates
		# to the TextureRect's current draw rectangle exactly.
		if build_succeeded:
			_handle_polys.call_deferred(polys, source_size)

		var elapsed_time: int = Time.get_ticks_usec() - start_time
		print("Elapsed time: ", elapsed_time, " μs")

		if build_succeeded and not _thread_exit_requested:
			semaphore.wait()
		if not _thread_exit_requested:
			OS.delay_msec(int(maxf(float(polys.size()) * 0.2, 50.0)))


var semaphore: Semaphore = Semaphore.new()


func _handle_polys(polys: Array[PackedVector2Array], source_size: Vector2i) -> void:
	if polys.size() > max_collision_triangles:
		semaphore.post()
		return
	if source_size.x <= 0 or source_size.y <= 0:
		semaphore.post()
		return
	# A resize may finish while the worker is triangulating the previous image.
	# Do not install polygons from the old simulation dimensions.
	if image == null or image.is_empty() or image.get_size() != source_size:
		semaphore.post()
		return

	var start_time: int = Time.get_ticks_usec()
	print("Handling polys: ", polys.size())

	# Build the replacement first. The old valid collider remains active until the
	# new body is complete.
	var collider := StaticBody2D.new()
	collider.name = "DynamicCollider"

	var source_size_f := Vector2(source_size)
	var draw_rect: Rect2 = _get_texture_draw_rect(source_size_f)
	var draw_scale: Vector2 = draw_rect.size / source_size_f

	for poly: PackedVector2Array in polys:
		var mapped_poly: PackedVector2Array = _map_polygon_to_draw_rect(
			poly,
			source_size_f,
			draw_rect,
			draw_scale
		)
		if mapped_poly.size() < 3:
			continue

		var collision_polygon := CollisionPolygon2D.new()
		# Every polygon is already a convex triangle. BUILD_SOLIDS preserves holes
		# because only triangles belonging to opaque pixels are emitted.
		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		collision_polygon.polygon = mapped_poly
		collider.add_child(collision_polygon)

	_static_body.add_child(collider)

	# Remove the previous body only after the new one is in the scene tree. This
	# avoids a one-frame collision gap during frequent updates.
	for child: Node in _static_body.get_children():
		if child != collider and child is StaticBody2D:
			child.queue_free()

	var elapsed_time: int = Time.get_ticks_usec() - start_time
	print("Elapsed time (polys): ", elapsed_time, " μs")
	semaphore.post()


func _map_polygon_to_draw_rect(
	poly: PackedVector2Array,
	source_size: Vector2,
	draw_rect: Rect2,
	draw_scale: Vector2
) -> PackedVector2Array:
	var mapped := PackedVector2Array()
	mapped.resize(poly.size())

	for i: int in range(poly.size()):
		var point: Vector2 = poly[i]
		if flip_h:
			point.x = source_size.x - point.x
		if flip_v:
			point.y = source_size.y - point.y
		mapped[i] = draw_rect.position + point * draw_scale

	return mapped


## Returns the rectangle where TextureRect draws the source image in local
## coordinates. The current project uses STRETCH_SCALE, but handling every
## non-tiled mode keeps collision alignment correct if the scene setting changes.
func _get_texture_draw_rect(source_size: Vector2) -> Rect2:
	var control_size: Vector2 = size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	match stretch_mode:
		TextureRect.STRETCH_KEEP:
			return Rect2(Vector2.ZERO, source_size)

		TextureRect.STRETCH_KEEP_CENTERED:
			return Rect2((control_size - source_size) * 0.5, source_size)

		TextureRect.STRETCH_KEEP_ASPECT:
			var fit_scale: float = minf(
				control_size.x / source_size.x,
				control_size.y / source_size.y
			)
			return Rect2(Vector2.ZERO, source_size * fit_scale)

		TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var centered_scale: float = minf(
				control_size.x / source_size.x,
				control_size.y / source_size.y
			)
			var centered_size: Vector2 = source_size * centered_scale
			return Rect2((control_size - centered_size) * 0.5, centered_size)

		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			var cover_scale: float = maxf(
				control_size.x / source_size.x,
				control_size.y / source_size.y
			)
			var covered_size: Vector2 = source_size * cover_scale
			return Rect2((control_size - covered_size) * 0.5, covered_size)

		TextureRect.STRETCH_TILE:
			# A tiled texture has multiple copies but the simulation represents one
			# image. Map to the first tile rather than applying a false full-rect scale.
			return Rect2(Vector2.ZERO, source_size)

		_:
			# STRETCH_SCALE: independently scale X/Y to fill the control rectangle.
			return Rect2(Vector2.ZERO, control_size)
