extends TextureRect
class_name Canvas

@export var px_scale: int = 3

var image: Image:
	set(val):
		image = val
		texture.set_image(image)

var _thread = Thread.new()
var _static_body: StaticBody2D = StaticBody2D.new()

func _ready() -> void:
	%SizeCopy.resized.connect(_on_resized)
	texture = ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGB8))
	add_child(_static_body)
	_thread.start(background_task.bind("generate_collider"))

func _on_resized() -> void:
	size = %SizeCopy.size
	
func _exit_tree():
	_thread.wait_to_finish()
		
func repaint() -> void:
	var width: int = CommonReference.main.sim.get_width()
	var height: int = CommonReference.main.sim.get_height()
	if width <= 0 or height <= 0: return
	var data: PackedByteArray = CommonReference.main.sim.get_color_image(Settings.flat_mode)
	var start_time = Time.get_ticks_usec()
	image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
#	generate_collider(image)
#	texture.set_image(image)
	var end_time = Time.get_ticks_usec()
	var elapsed_time = end_time - start_time
	
#	_update_colliders()
#	print("Elapsed time: ", elapsed_time, " μs")



#func generate_collider(image: Image, centered: bool = false) -> StaticBody2D:
#	var node = StaticBody2D.new()
#	var bitmap = BitMap.new()
#	bitmap.create_from_image_alpha(image)
#	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.5)
#
#	for poly in polys:
#		var collision_polygon = CollisionPolygon2D.new()
#		#		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
#		collision_polygon.polygon = poly
#		node.add_child(collision_polygon)
#
#		# Generated polygon will not take into account the half-width and half-height offset
#		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
#		if centered:
#			var half_size = bitmap.get_size() / 2
#			collision_polygon.position -= Vector2(half_size.x, half_size.y)
#
#	return node
#
#func _update_colliders() -> void:
#	# remove old colliders
#	for child in get_children():
#		if child is StaticBody2D:
#			child.queue_free()
#
#	var collider = generate_collider(image)
#	collider.position = position
#	add_child(collider)


@export var update_collider: bool = false

func background_task(param):
	# This function will be executed in the thread
	while true:
		if !Main.active || image == null:
			OS.delay_msec(10)
			continue
			
		var start_time = Time.get_ticks_usec()
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image)
		var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.5)
		
		_handle_polys.call_deferred(polys)

		var end_time = Time.get_ticks_usec()
		var elapsed_time = end_time - start_time
		print("Elapsed time: ", elapsed_time, " μs")
		
		semaphore.wait()
		OS.delay_msec(max(polys.size() * 0.2, 50))

var semaphore: Semaphore = Semaphore.new()
func _handle_polys(polys: Array) -> void:
	if polys.size() > 3000:
		semaphore.post()
		return

	var start_time = Time.get_ticks_usec()
	print("Handling polys: ", polys.size())

	# remove old colliders
	for child in _static_body.get_children():
		if child is StaticBody2D:
			child.queue_free()

	var collider = StaticBody2D.new()
	collider.name = "DynamicCollider"
	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		#collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		collision_polygon.polygon = poly
		collider.add_child(collision_polygon)

	_static_body.add_child(collider)
	var end_time = Time.get_ticks_usec()
	var elapsed_time = end_time - start_time
	print("Elapsed time (polys): ", elapsed_time, " μs")
	
	semaphore.post()
	
