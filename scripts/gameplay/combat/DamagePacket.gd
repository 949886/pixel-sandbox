class_name DamagePacket
extends RefCounted

## Immutable-by-convention context passed through the combat pipeline.
## Source/instigator use weak references because damage packets can be observed
## after the originating projectile or caster has already been freed.
var amount: float = 0.0
var type: int = DamageTypes.Type.PHYSICAL
var _source_ref: WeakRef
var _instigator_ref: WeakRef

var source: Node:
	get:
		return _resolve_node(_source_ref)
	set(value):
		_source_ref = _make_weak_node(value)

var instigator: Node:
	get:
		return _resolve_node(_instigator_ref)
	set(value):
		_instigator_ref = _make_weak_node(value)

var world_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var impulse: float = 0.0
var tags: Array[StringName] = []

static func create(
	p_amount: float,
	p_type: int,
	p_source = null,
	p_instigator = null,
	p_world_position: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.ZERO,
	p_impulse: float = 0.0
) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.amount = maxf(0.0, p_amount)
	packet.type = p_type
	packet.source = p_source
	packet.instigator = p_instigator
	packet.world_position = p_world_position
	packet.direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.ZERO
	packet.impulse = maxf(0.0, p_impulse)
	return packet

static func _make_weak_node(value) -> WeakRef:
	if value == null or not is_instance_valid(value):
		return null
	if not (value is Node):
		return null
	return weakref(value)

static func _resolve_node(reference: WeakRef) -> Node:
	if reference == null:
		return null
	var value = reference.get_ref()
	if value == null or not is_instance_valid(value) or not (value is Node):
		return null
	return value as Node
