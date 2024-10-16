class_name SpriteRigidBody
extends RigidBody2D

@export var sprite: Sprite2D

#func _ready() -> void:
#	var bitmap = BitMap.new()
#	bitmap.create_from_image_alpha(sprite.texture.get_image())
#	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, sprite.texture.get_size()), 0.5)
#
#	for poly in polys:
#		var collision_polygon = CollisionPolygon2D.new()
##		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
#		collision_polygon.polygon = poly
#		add_child(collision_polygon)
#
#		# Generated polygon will not take into account the half-width and half-height offset
#		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
#		if sprite.centered:
#			var half_size = bitmap.get_size() / 2
#			collision_polygon.position -= Vector2(half_size.x, half_size.y)

func _ready() -> void:
	var collider = generate_collider(sprite.texture.get_image(), sprite.centered)
	if sprite != null:
		collider.add_child(sprite)
	add_child(collider)

static func generate_collider(image: Image, centered: bool = true) -> RigidBody2D:
	var node = RigidBody2D.new()
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