extends Sprite2D

@onready var area = $Area2D

func _ready() -> void:
	area.connect('mouse_entered', Callable(self, '_on_mouse_entered'))
	area.connect('mouse_exited', Callable(self, '_on_mouse_exited'))

	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(texture.get_image())

	var polys = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, texture.get_size()))
	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = poly
		area.add_child(collision_polygon)

		# Generated polygon will not take into account the half-width and half-height offset
		# of the image when "centered" is on. So move it backwards by this amount so it lines up.
		if centered:
			var half_size = bitmap.get_size() / 2
			collision_polygon.position -= Vector2(half_size.x, half_size.y)

func _on_mouse_entered() -> void:
	modulate = Color.RED

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
