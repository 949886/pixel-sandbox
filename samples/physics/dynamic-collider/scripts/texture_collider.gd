class_name TextureCollider
extends StaticBody2D

@export var texture_rect: TextureRect
@export var update: bool = false
@export var update_interval: float = 0.1

var time_elapsed: float = 0

var thread = Thread.new()

var is_processing = false


func _ready() -> void:
	var texture = texture_rect.texture
	if texture != null:
		var collider = generate_collider(texture_rect.texture.get_image())
		collider.position = texture_rect.position
		add_child(collider)

#	thread.start(thread_task.bind("task"))

#func _process(delta: float) -> void:
#	if update:
#		# remove old colliders
#		for child in get_children():
#			if child is StaticBody2D:
#				child.queue_free()
#		
#		var collider = generate_collider(sprite.texture.get_image(), sprite.centered)
#		add_child(collider)	

#func _process(delta: float) -> void:
#	print("Thread status: ", is_running)
#	if update:
#		time_elapsed += delta
#		if time_elapsed >= update_interval:
#			time_elapsed = 0
#			_update_colliders()

func _exit_tree():
	if is_running:
		thread.wait_to_finish()  # Wait for the thread to finish before quitting

func _update_colliders() -> void:
	# remove old colliders
	for child in get_children():
		if child is StaticBody2D:
			child.queue_free()

	var texture = texture_rect.texture
	if texture != null:
		var image = texture_rect.texture.get_image()
		var collider = generate_collider(image)
		collider.position = texture_rect.position
		add_child(collider)

var semaphore: Semaphore = Semaphore.new()
	
func _handle_polys(polys: Array) -> void:
	if is_processing || polys.size() > 1500:
		semaphore.post()
		return

	is_processing = true

	print("Handling polys: ", polys.size())	

	# remove old colliders
	for child in get_children():
		if child is StaticBody2D:
			child.queue_free()
		
	var collider = StaticBody2D.new()
	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		#collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		collision_polygon.polygon = poly
		collider.add_child(collision_polygon)
	var start_time = Time.get_ticks_usec()
	add_child(collider)
	var end_time = Time.get_ticks_usec()
	is_processing = false
	semaphore.post()
	

	var elapsed_time = end_time - start_time
#	print("Elapsed time: ", elapsed_time, " μs")

# Generated polygon will not take into account the half-width and half-height offset
		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
#		if centered:
#			var half_size = bitmap.get_size() / 2
#			collision_polygon.position -= Vector2(half_size.x, half_size.y)

var is_running = false  # Flag to track thread status


func thread_task(param):
	# This function will be executed in the thread
	is_running = true
	while update:
		var start_time = Time.get_ticks_usec()
		var bitmap = BitMap.new()
		var image = texture_rect.texture.get_image()
		bitmap.create_from_image_alpha(image)
		var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.5)
		print("Is processing: ", is_processing)
		
		if not is_processing:
			_handle_polys.call_deferred(polys)

		var end_time = Time.get_ticks_usec()
		var elapsed_time = end_time - start_time
		print("Elapsed time: ", elapsed_time, " μs")		

		semaphore.wait()
		OS.delay_msec(100)
		
	is_running = false
	return "Thread Task Finished"
		
		
static func generate_collider(image: Image, centered: bool = false) -> StaticBody2D:
	var start_time = Time.get_ticks_usec()
	
	var node = StaticBody2D.new()
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image)
	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.5)

	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		#collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		collision_polygon.polygon = poly
		node.add_child(collision_polygon)

		# Generated polygon will not take into account the half-width and half-height offset
		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
		if centered:
			var half_size = bitmap.get_size() / 2
			collision_polygon.position -= Vector2(half_size.x, half_size.y)

	var end_time = Time.get_ticks_usec()
	var elapsed_time = end_time - start_time
	print("Elapsed time: ", elapsed_time, " μs")
		
	return node
