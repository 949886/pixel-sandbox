class_name GoldPickup
extends Area2D

@export_range(1, 999, 1) var value: int = 5
@export var pickup_delay: float = 0.15

var _age: float = 0.0
var _base_y: float = 0.0
var _pickup_enabled: bool = false
var _collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 16
	_base_y = global_position.y
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	shape_node.shape = shape
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	global_position.y = _base_y + sin(_age * 3.2) * 2.0
	rotation += delta * 1.8
	if not _pickup_enabled and _age >= maxf(0.0, pickup_delay):
		_pickup_enabled = true
		# body_entered can fire before pickup_delay and will not fire again while
		# the body remains overlapping. Re-check overlaps once the delay expires.
		for body: Node2D in get_overlapping_bodies():
			if _try_pickup(body):
				return

func _on_body_entered(body: Node) -> void:
	if _pickup_enabled:
		_try_pickup(body)

func _try_pickup(body: Node) -> bool:
	if _collected:
		return true
	if body != null and is_instance_valid(body) and body.has_method("add_gold"):
		_collected = true
		monitoring = false
		body.call("add_gold", value)
		queue_free()
		return true
	return false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.78, 0.18, 1.0))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.94, 0.5, 1.0))
