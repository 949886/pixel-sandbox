class_name GameplayProjectile
extends Node2D

## Shared pixel-native projectile used by actors and the migrated Luna spell deck.
var direction := Vector2.RIGHT
var velocity := Vector2.ZERO
var speed: float = 760.0
var lifetime: float = 1.2
var gravity: float = 0.0
var dig_radius: float = 0.0
var damage_amount: float = 0.0
var damage_type: int = DamageTypes.Type.PROJECTILE
var collision_query_mask: int = 1
var _source_ref: WeakRef
var _world_interface_ref: WeakRef
var source: CollisionObject2D:
	get:
		return _resolve_collision_object(_source_ref)
	set(value):
		_source_ref = weakref(value) if value != null and is_instance_valid(value) else null
var world_interface: Node:
	get:
		return _resolve_node(_world_interface_ref)
	set(value):
		_world_interface_ref = weakref(value) if value != null and is_instance_valid(value) else null
var dig_on_entity_hit: bool = false
var projectile_color := Color(0.85, 1.0, 1.0, 1.0)
var trail_color := Color(0.45, 0.95, 1.0, 0.55)
var projectile_def: ProjectileDef
var cast_context: CastContext

var _secondary_color := Color(0.35, 0.85, 1.0, 1.0)
var _core_pixel_size: float = 2.0
var _trail_length: int = 7
var _trail_spacing: float = 4.0
var _trail_jitter: float = 1.0
var _impact_particle_count: int = 10
var _impact_pixel_size: float = 2.0
var _impact_particle_speed: float = 85.0
var _detonate_on_timeout: bool = false
var _trail_points: Array[Vector2] = []
var _trail_distance_accum: float = 0.0
var _rng := RandomNumberGenerator.new()
var _remaining_bounces: int = 0
var _remaining_pierces: int = 0
var _bounce_energy: float = 0.82
var _ignored_rids: Array[RID] = []
var _trail_material_timer: float = 0.0
var _satellite_pixels: int = 0

func setup(
	p_direction: Vector2,
	p_source: CollisionObject2D,
	p_world_interface: Node,
	p_speed: float,
	p_lifetime: float,
	p_dig_radius: float = 0.0,
	p_damage_amount: float = 0.0,
	p_damage_type: int = DamageTypes.Type.PROJECTILE,
	p_collision_query_mask: int = 1,
	p_projectile_color: Color = Color(0.85, 1.0, 1.0, 1.0)
) -> void:
	projectile_def = null
	cast_context = null
	direction = _safe_direction(p_direction, Vector2.RIGHT)
	source = p_source if p_source != null and is_instance_valid(p_source) else null
	world_interface = p_world_interface if p_world_interface != null and is_instance_valid(p_world_interface) else null
	speed = maxf(0.0, p_speed)
	lifetime = maxf(0.02, p_lifetime)
	gravity = 0.0
	velocity = direction * speed
	dig_radius = maxf(0.0, p_dig_radius)
	damage_amount = maxf(0.0, p_damage_amount)
	damage_type = p_damage_type
	collision_query_mask = maxi(0, p_collision_query_mask)
	projectile_color = p_projectile_color
	_secondary_color = Color(projectile_color.r * 0.55, projectile_color.g * 0.8, projectile_color.b, 1.0)
	trail_color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.62)
	_configure_visuals()

func setup_from_def(p_def: ProjectileDef, context: CastContext, p_direction: Vector2) -> void:
	if p_def == null:
		projectile_def = null
		cast_context = context
		queue_free()
		return
	projectile_def = p_def
	cast_context = context
	direction = _safe_direction(p_direction, Vector2.RIGHT)
	world_interface = context.world_interface if context != null else null
	if world_interface != null and not is_instance_valid(world_interface):
		world_interface = null
	var context_caster := context.caster if context != null else null
	source = context_caster as CollisionObject2D if context_caster is CollisionObject2D else null
	var state := context.cast_state if context != null else null
	var speed_scale := state.speed_scale if state != null else 1.0
	var speed_add := state.speed_add if state != null else 0.0
	speed = maxf(1.0, p_def.speed * speed_scale + speed_add)
	lifetime = maxf(0.02, p_def.lifetime + (state.lifetime_add if state != null else 0.0))
	gravity = p_def.gravity
	velocity = direction * speed
	collision_query_mask = maxi(0, p_def.collision_query_mask)
	projectile_color = p_def.primary_color
	_secondary_color = p_def.secondary_color
	_core_pixel_size = maxf(1.0, p_def.core_pixel_size)
	_trail_length = maxi(0, p_def.trail_length)
	_trail_spacing = maxf(1.0, p_def.trail_spacing)
	_trail_jitter = maxf(0.0, p_def.trail_jitter)
	_impact_particle_count = maxi(0, p_def.impact_particle_count)
	_impact_pixel_size = maxf(1.0, p_def.impact_pixel_size)
	_impact_particle_speed = maxf(0.0, p_def.impact_particle_speed)
	_detonate_on_timeout = p_def.detonate_on_timeout
	_remaining_bounces = maxi(0, p_def.max_bounces) if p_def.can_bounce else 0
	_remaining_pierces = maxi(0, p_def.max_pierces) if p_def.can_pierce else 0
	_bounce_energy = maxf(0.0, p_def.bounce_energy)
	_satellite_pixels = maxi(0, p_def.satellite_pixels) + (2 if state != null and state.add_pixel_light else 0)
	trail_color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.68)
	_configure_visuals()

func _configure_visuals() -> void:
	_rng.randomize()
	rotation = direction.angle()
	z_index = 20
	_trail_points.clear()
	_trail_points.append(global_position.round())
	_ignored_rids.clear()
	if source != null and is_instance_valid(source):
		_ignored_rids.append(source.get_rid())
	else:
		source = null
	queue_redraw()

func _physics_process(delta: float) -> void:
	var start := global_position
	velocity.y += gravity * delta
	var finish := start + velocity * delta
	var motion := finish - start
	if motion.length_squared() > 0.000001:
		var query := PhysicsRayQueryParameters2D.create(start, finish, collision_query_mask)
		query.exclude = _ignored_rids
		var world := get_world_2d()
		var hit := world.direct_space_state.intersect_ray(query) if world != null else {}
		if not hit.is_empty():
			var hit_position: Vector2 = hit.get("position", finish)
			global_position = hit_position.round()
			if _impact(hit):
				return
		else:
			global_position = finish
	if velocity.length_squared() > 0.0001:
		direction = velocity.normalized()
		rotation = direction.angle()
	_record_trail(start.distance_to(global_position))
	_update_world_trail(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		if _detonate_on_timeout:
			_impact({})
		else:
			_spawn_impact_vfx(0.45)
			queue_free()
		return
	queue_redraw()

func _record_trail(distance_moved: float) -> void:
	if _trail_length <= 0:
		return
	_trail_distance_accum += distance_moved
	if _trail_distance_accum < maxf(1.0, _trail_spacing):
		return
	_trail_distance_accum = 0.0
	var perpendicular := Vector2(-direction.y, direction.x)
	var jitter := perpendicular * _rng.randf_range(-_trail_jitter, _trail_jitter)
	_trail_points.push_front((global_position + jitter).round())
	while _trail_points.size() > _trail_length:
		_trail_points.pop_back()

func _update_world_trail(delta: float) -> void:
	if projectile_def == null or projectile_def.trail_material_element_id < 0 or projectile_def.trail_material_radius <= 0.0:
		return
	if world_interface == null or not is_instance_valid(world_interface):
		world_interface = null
		return
	if not world_interface.has_method("paint_material_circle"):
		return
	_trail_material_timer -= delta
	if _trail_material_timer > 0.0:
		return
	_trail_material_timer = maxf(0.02, projectile_def.trail_material_interval)
	world_interface.call(
		"paint_material_circle",
		global_position.round(),
		projectile_def.trail_material_radius,
		projectile_def.trail_material_element_id,
		projectile_def.trail_material_only_air
	)

## Returns true when the projectile has been destroyed.
func _impact(hit: Dictionary) -> bool:
	var collider := hit.get("collider", null) as Node
	var hit_normal := _safe_collision_normal(hit.get("normal", Vector2.ZERO))
	_execute_impact_effects(collider, hit_normal)
	_spawn_impact_vfx(0.65 if _remaining_bounces > 0 or _remaining_pierces > 0 else 1.0)

	if collider is CollisionObject2D and _remaining_pierces > 0:
		var rid := (collider as CollisionObject2D).get_rid()
		if not _ignored_rids.has(rid):
			_ignored_rids.append(rid)
		_remaining_pierces -= 1
		global_position += direction * 2.0
		return false

	if not hit.is_empty() and _remaining_bounces > 0:
		_remaining_bounces -= 1
		velocity = velocity.bounce(hit_normal) * maxf(0.0, _bounce_energy)
		if velocity.length_squared() <= 0.0001:
			queue_free()
			return true
		direction = velocity.normalized()
		global_position += hit_normal * 1.5
		return false

	queue_free()
	return true

func _execute_impact_effects(collider: Node, hit_normal: Vector2) -> void:
	if projectile_def != null and cast_context != null:
		var impact_context := cast_context.duplicate_for_impact(collider, global_position, hit_normal)
		impact_context.source = self
		impact_context.direction = direction
		for effect: Resource in projectile_def.impact_effects:
			if effect != null and effect.has_method("execute"):
				effect.call("execute", impact_context)
	else:
		_legacy_impact(collider)

func _legacy_impact(collider: Node) -> void:
	var target_health := HealthComponent.find_on(collider) if collider != null else null
	var hit_damageable := false
	if target_health != null and damage_amount > 0.0:
		var live_source: Node = source if source != null and is_instance_valid(source) else null
		var source_faction := FactionComponent.find_on(live_source) if live_source != null else null
		var target_faction := FactionComponent.find_on(collider)
		if FactionComponent.can_damage(source_faction, target_faction):
			var packet := DamagePacket.create(
				damage_amount,
				damage_type,
				self,
				live_source,
				global_position,
				direction,
				damage_amount * 2.0
			)
			target_health.take_damage(packet)
			hit_damageable = true
	if dig_radius > 0.0 and (not hit_damageable or dig_on_entity_hit):
		if world_interface != null and is_instance_valid(world_interface) and world_interface.has_method("erase_material_circle"):
			world_interface.call("erase_material_circle", global_position, dig_radius)

func _spawn_impact_vfx(scale: float) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	PixelSpellVFX.spawn_burst(
		parent,
		global_position.round(),
		projectile_color,
		_secondary_color,
		maxi(2, int(round(float(_impact_particle_count) * scale))),
		_impact_particle_speed,
		0.25,
		_impact_pixel_size,
		-direction,
		155.0,
		45.0
	)

static func _resolve_collision_object(reference: WeakRef) -> CollisionObject2D:
	if reference == null:
		return null
	var value = reference.get_ref()
	if value == null or not is_instance_valid(value) or not (value is CollisionObject2D):
		return null
	return value as CollisionObject2D

static func _resolve_node(reference: WeakRef) -> Node:
	if reference == null:
		return null
	var value = reference.get_ref()
	if value == null or not is_instance_valid(value) or not (value is Node):
		return null
	return value as Node

func _safe_collision_normal(candidate) -> Vector2:
	var normal: Vector2 = candidate if typeof(candidate) == TYPE_VECTOR2 else Vector2.ZERO
	if normal.length_squared() > 0.0001:
		return normal.normalized()
	# Rays that begin inside a collider can report a zero normal. Reflecting on
	# that vector is invalid in Godot, so use the incoming direction instead.
	var incoming := velocity if velocity.length_squared() > 0.0001 else direction
	if incoming.length_squared() > 0.0001:
		return -incoming.normalized()
	return Vector2.UP

static func _safe_direction(candidate: Vector2, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	if candidate.length_squared() > 0.0001:
		return candidate.normalized()
	if fallback.length_squared() > 0.0001:
		return fallback.normalized()
	return Vector2.RIGHT

func _draw() -> void:
	for index: int in range(_trail_points.size() - 1, -1, -1):
		var life_ratio := 1.0 - float(index) / maxf(1.0, float(_trail_points.size()))
		var color := _secondary_color if index % 2 == 0 else trail_color
		color.a *= clampf(life_ratio, 0.18, 0.75)
		var trail_size := maxf(1.0, floorf(_core_pixel_size * (0.45 + life_ratio * 0.35)))
		var local_point := to_local(_trail_points[index]).round()
		draw_rect(Rect2(local_point - Vector2.ONE * floorf(trail_size * 0.5), Vector2.ONE * trail_size), color)
	var core_size := maxf(1.0, _core_pixel_size)
	draw_rect(Rect2(Vector2(-floorf(core_size * 0.5), -floorf(core_size * 0.5)), Vector2.ONE * core_size), projectile_color)
	if core_size >= 3.0:
		draw_rect(Rect2(Vector2(0.0, -1.0), Vector2(1.0, 1.0)), _secondary_color)
	for index: int in range(_satellite_pixels):
		var phase := Time.get_ticks_msec() * 0.006 + float(index) * TAU / maxf(1.0, float(_satellite_pixels))
		var offset := Vector2(cos(phase), sin(phase)) * (core_size + 2.0 + float(index % 2))
		draw_rect(Rect2(offset.round(), Vector2.ONE), _secondary_color)
