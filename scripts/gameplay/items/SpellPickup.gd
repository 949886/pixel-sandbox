class_name SpellPickup
extends Area2D

@export var spell: SpellDef
@export var pickup_delay: float = 0.15
@export var float_amplitude: float = 2.0

var _age: float = 0.0
var _base_y: float = 0.0
var _pickup_enabled: bool = false
var _collected: bool = false
var _retry_elapsed: float = 0.0
var _icon: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 17
	_base_y = global_position.y
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	shape_node.shape = shape
	add_child(shape_node)
	_icon = Sprite2D.new()
	_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.scale = Vector2(1.0, 1.0)
	add_child(_icon)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	global_position.y = _base_y + sin(_age * 3.0) * float_amplitude
	rotation = sin(_age * 1.7) * 0.06
	queue_redraw()
	if not _pickup_enabled and _age >= maxf(0.0, pickup_delay):
		_pickup_enabled = true
		_retry_overlaps()
	elif _pickup_enabled:
		_retry_elapsed += delta
		if _retry_elapsed >= 0.25:
			_retry_elapsed = 0.0
			_retry_overlaps()

func _retry_overlaps() -> void:
	if _collected:
		return
	for body: Node2D in get_overlapping_bodies():
		if _try_pickup(body):
			return

func _on_body_entered(body: Node) -> void:
	if _pickup_enabled:
		_try_pickup(body)

func _try_pickup(body: Node) -> bool:
	if _collected:
		return true
	if spell == null or body == null or not is_instance_valid(body):
		return false
	if not body.has_method("pickup_spell"):
		return false
	if bool(body.call("pickup_spell", spell)):
		_collected = true
		monitoring = false
		queue_free()
		return true
	return false

func _draw() -> void:
	draw_rect(Rect2(-10, -10, 20, 20), Color(0.035, 0.03, 0.045, 0.92), true)
	draw_rect(Rect2(-10, -10, 20, 20), _border_color(), false, 1.0)
	var phase := fmod(_age * 6.0, 8.0)
	draw_rect(Rect2(-12.0 + phase, -12.0, 2.0, 2.0), _border_color(), true)
	draw_rect(Rect2(10.0 - phase, 10.0, 2.0, 2.0), _border_color(), true)

func _border_color() -> Color:
	if spell == null:
		return Color(0.65, 0.65, 0.7, 1.0)
	match spell.kind:
		SpellDef.Kind.MODIFIER:
			return Color(0.42, 0.78, 1.0, 1.0)
		SpellDef.Kind.MULTICAST:
			return Color(0.9, 0.62, 1.0, 1.0)
		SpellDef.Kind.MATERIAL:
			return Color(0.42, 1.0, 0.58, 1.0)
		_:
			return Color(1.0, 0.82, 0.35, 1.0)
