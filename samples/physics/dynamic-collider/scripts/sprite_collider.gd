class_name SpriteCollider
extends StaticBody2D

@export var sprite: Sprite2D
@export var update: bool = false
@export var update_interval: float = 0.1

var time_elapsed: float = 0

func _ready() -> void:
	var collider = generate_collider(sprite.texture.get_image(), sprite.centered)
	if sprite != null:
		collider.add_child(sprite)
	add_child(collider)

#func _process(delta: float) -> void:
#	if update:
#		# remove old colliders
#		for child in get_children():
#			if child is StaticBody2D:
#				child.queue_free()
#		
#		var collider = generate_collider(sprite.texture.get_image(), sprite.centered)
#		add_child(collider)	
		
func _process(delta: float) -> void:
	if update:
		time_elapsed += delta
		if time_elapsed >= update_interval:
			time_elapsed = 0
			# remove old colliders
			for child in get_children():
				if child is StaticBody2D:
					child.queue_free()
	
			var collider = generate_collider(sprite.texture.get_image(), sprite.centered)
			add_child(collider)
			

static func generate_collider(image: Image, centered: bool = true) -> StaticBody2D:
	var node = StaticBody2D.new()
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image)
	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.5)

	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		#		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		collision_polygon.polygon = poly
		node.add_child(collision_polygon)

		# Generated polygon will not take into account the half-width and half-height offset
		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
		if centered:
			var half_size = bitmap.get_size() / 2
			collision_polygon.position -= Vector2(half_size.x, half_size.y)

	return node