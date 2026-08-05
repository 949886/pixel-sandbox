class_name NoitaBolt
extends Node2D

## Fast ray-stepped wand projectile. It collides with the streamed static pixel
## collision and asks WorldManager to erase a small circle from the live sand grid.

var direction := Vector2.RIGHT
var speed: float = 760.0
var lifetime: float = 1.2
var dig_radius: float = 5.0
var source: CollisionObject2D
var world_manager: Node

func setup(
	p_direction: Vector2,
	p_source: CollisionObject2D,
	p_world_manager: Node,
	p_speed: float,
	p_lifetime: float,
	p_dig_radius: float
) -> void:
	direction = p_direction.normalized()
	source = p_source
	world_manager = p_world_manager
	speed = p_speed
	lifetime = p_lifetime
	dig_radius = p_dig_radius
	rotation = direction.angle()
	z_index = 20
	queue_redraw()

func _physics_process(delta: float) -> void:
	var start := global_position
	var finish := start + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(start, finish, 1)
	if source != null and is_instance_valid(source):
		query.exclude = [source.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.get("position", finish)
		_impact()
		return
	global_position = finish
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _impact() -> void:
	if world_manager != null and world_manager.has_method("erase_material_circle"):
		world_manager.call("erase_material_circle", global_position, dig_radius)
	queue_free()

func _draw() -> void:
	draw_line(Vector2(-9.0, 0.0), Vector2(2.0, 0.0), Color(0.45, 0.95, 1.0, 0.55), 2.0)
	draw_circle(Vector2.ZERO, 2.0, Color(0.85, 1.0, 1.0, 1.0))
