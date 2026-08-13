class_name CastContext
extends RefCounted

## Runtime context shared by spell and impact GameplayEffects.
##
## Node references are weak on purpose. Projectiles and special spell runtimes can
## outlive the caster/source that created them (for example when the player dies
## and respawns). Returning null for an expired node is safer than keeping a
## `previously freed` Object handle inside a delayed impact context.
var _caster_ref: WeakRef
var _source_ref: WeakRef
var _projectile_parent_ref: WeakRef
var _world_interface_ref: WeakRef
var _target_ref: WeakRef

var caster: Node:
	get:
		return _resolve_node(_caster_ref)
	set(value):
		_caster_ref = _make_weak_node(value)

var source: Node:
	get:
		return _resolve_node(_source_ref)
	set(value):
		_source_ref = _make_weak_node(value)

var projectile_parent: Node:
	get:
		return _resolve_node(_projectile_parent_ref)
	set(value):
		_projectile_parent_ref = _make_weak_node(value)

var world_interface: Node:
	get:
		return _resolve_node(_world_interface_ref)
	set(value):
		_world_interface_ref = _make_weak_node(value)

var target: Node:
	get:
		return _resolve_node(_target_ref)
	set(value):
		_target_ref = _make_weak_node(value)

var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var hit_position: Vector2 = Vector2.ZERO
var hit_normal: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator
var cast_state: SpellCastState

static func create(
	p_caster: Node,
	p_source: Node,
	p_projectile_parent: Node,
	p_world_interface: Node,
	p_origin: Vector2,
	p_direction: Vector2
) -> CastContext:
	var context := CastContext.new()
	context.caster = p_caster
	context.source = p_source
	context.projectile_parent = p_projectile_parent
	context.world_interface = p_world_interface
	context.origin = p_origin
	context.hit_position = p_origin
	context.direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	context.rng = RandomNumberGenerator.new()
	context.rng.randomize()
	return context

func duplicate_for_impact(p_target: Node, p_position: Vector2, p_normal: Vector2) -> CastContext:
	var context := CastContext.new()
	# These getters resolve WeakRef values, so expired Nodes become null instead
	# of propagating a `previously freed` handle into the new context.
	context.caster = caster
	context.source = source
	context.projectile_parent = projectile_parent
	context.world_interface = world_interface
	context.origin = origin
	context.direction = direction
	context.target = p_target
	context.hit_position = p_position
	context.hit_normal = p_normal.normalized() if p_normal.length_squared() > 0.0001 else Vector2.ZERO
	context.rng = rng
	context.cast_state = cast_state
	return context

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
