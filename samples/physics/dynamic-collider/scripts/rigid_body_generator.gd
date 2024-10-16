extends RigidBody2D

@onready var sprite = $Sprite2D

func _ready() -> void:
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(sprite.texture.get_image())
	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, sprite.texture.get_size()), 0.5)

	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
#		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		collision_polygon.polygon = poly
		add_child(collision_polygon)

		# Generated polygon will not take into account the half-width and half-height offset
		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
		if sprite.centered:
			var half_size = bitmap.get_size() / 2
			collision_polygon.position -= Vector2(half_size.x, half_size.y)
