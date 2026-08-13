class_name SpecialSpellRuntime
extends Node2D

enum Mode { BLACK_HOLE, DEATH_CROSS, DRAGON_BREATH, CHAINSAW, GLUE_FIELD }

var mode: int = Mode.BLACK_HOLE
var context: CastContext
var duration: float = 2.0
var radius: float = 40.0
var damage_per_second: float = 10.0
var move_speed: float = 0.0
var pull_force: float = 0.0
var terrain_radius: float = 0.0
var actor_collision_mask: int = 6
var slow_factor: float = 0.35
var status_duration: float = 0.5
var primary := Color.WHITE
var secondary := Color(0.4, 0.8, 1.0, 1.0)
var tick_interval: float = 0.1

var _tick_remaining: float = 0.0
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(
	p_mode: int,
	p_context: CastContext,
	p_duration: float,
	p_radius: float,
	p_damage_per_second: float,
	p_move_speed: float,
	p_pull_force: float,
	p_terrain_radius: float,
	p_primary: Color,
	p_secondary: Color,
	p_slow_factor: float = 0.35,
	p_status_duration: float = 0.5
) -> void:
	mode = p_mode
	context = p_context
	duration = maxf(0.0, p_duration)
	radius = maxf(0.01, p_radius + (p_context.cast_state.radius_add if p_context != null and p_context.cast_state != null else 0.0))
	damage_per_second = maxf(0.0, p_damage_per_second)
	move_speed = p_move_speed
	pull_force = maxf(0.0, p_pull_force)
	terrain_radius = maxf(0.0, p_terrain_radius)
	primary = p_primary
	secondary = p_secondary
	slow_factor = clampf(p_slow_factor, 0.05, 1.0)
	status_duration = maxf(0.0, p_status_duration)
	tick_interval = maxf(0.02, tick_interval)
	_rng.randomize()
	z_index = 22
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	duration -= delta
	if duration <= 0.0 or context == null:
		_finish()
		return
	if mode == Mode.DRAGON_BREATH or mode == Mode.CHAINSAW:
		if not _follow_caster():
			_finish()
			return
	else:
		global_position += context.direction * move_speed * delta
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = tick_interval
		_tick()
	queue_redraw()

func _follow_caster() -> bool:
	var resolved_caster := context.caster if context != null else null
	if resolved_caster == null or not (resolved_caster is Node2D):
		return false
	var caster := resolved_caster as Node2D
	var reach := radius * (0.58 if mode == Mode.DRAGON_BREATH else 0.45)
	global_position = (caster.global_position + context.direction * reach).round()
	rotation = context.direction.angle()
	return true

func _tick() -> void:
	match mode:
		Mode.BLACK_HOLE:
			_apply_radial_damage_and_pull()
			_erode_terrain()
			PixelSpellVFX.spawn_burst(get_parent(), global_position, primary, secondary, 3, 45.0, 0.2, 1.0, Vector2.ZERO, 360.0, -30.0)
		Mode.DEATH_CROSS:
			_apply_cross_damage()
		Mode.DRAGON_BREATH:
			_apply_cone_damage()
			_paint_fire_cone()
			PixelSpellVFX.spawn_burst(get_parent(), global_position, primary, secondary, 6, 90.0, 0.24, 2.0, context.direction, 42.0, -15.0)
		Mode.CHAINSAW:
			_apply_radial_damage(false)
			_erode_terrain()
			PixelSpellVFX.spawn_burst(get_parent(), global_position, primary, secondary, 5, 75.0, 0.16, 1.0, context.direction, 95.0, 30.0)
		Mode.GLUE_FIELD:
			_apply_radial_damage(false, true)
			PixelSpellVFX.spawn_burst(get_parent(), global_position, primary, secondary, 2, 28.0, 0.22, 2.0, Vector2.ZERO, 360.0, 35.0)

func _actor_hits(query_radius: float) -> Array:
	if query_radius <= 0.0 or context == null or context.projectile_parent == null:
		return []
	var canvas := context.projectile_parent as Node2D
	if canvas == null:
		return []
	var world := canvas.get_world_2d()
	if world == null:
		return []
	var shape := CircleShape2D.new()
	shape.radius = maxf(0.01, query_radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = actor_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return world.direct_space_state.intersect_shape(query, 64)

func _apply_radial_damage(with_pull: bool = false, apply_slow: bool = false) -> void:
	var resolved_damage := maxf(0.0, damage_per_second + (context.cast_state.damage_add if context.cast_state != null else 0.0)) * tick_interval
	var seen: Dictionary = {}
	for hit: Dictionary in _actor_hits(radius):
		var collider := hit.get("collider", null) as Node
		var health := HealthComponent.find_on(collider) if collider != null else null
		if health == null or seen.has(health):
			continue
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(collider)
		if not FactionComponent.can_damage(source_faction, target_faction):
			continue
		var actor := health.get_parent() as Node2D
		if actor == null:
			continue
		var delta_pos := global_position - actor.global_position
		var damage_direction := -delta_pos.normalized() if delta_pos.length_squared() > 0.0001 else context.direction
		var packet := DamagePacket.create(resolved_damage, DamageTypes.Type.PROJECTILE, self, context.caster, actor.global_position, damage_direction, 0.0)
		packet.tags.append(&"persistent_spell")
		health.take_damage(packet)
		if with_pull and pull_force > 0.0:
			_apply_pull(actor, delta_pos)
		if apply_slow:
			var status := StatusComponent.find_on(actor)
			if status != null:
				status.apply_slow(slow_factor, status_duration)
		seen[health] = true

func _apply_radial_damage_and_pull() -> void:
	_apply_radial_damage(true, false)

func _apply_pull(actor: Node2D, delta_pos: Vector2) -> void:
	if delta_pos.length_squared() <= 0.001:
		return
	var strength := pull_force * clampf(1.0 - delta_pos.length() / maxf(radius, 1.0), 0.1, 1.0) * tick_interval
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity += delta_pos.normalized() * strength
	elif actor is RigidBody2D:
		(actor as RigidBody2D).apply_central_force(delta_pos.normalized() * strength * 10.0)

func _apply_cross_damage() -> void:
	var arm_half := radius
	var width := maxf(4.0, radius * 0.18)
	var resolved_damage := maxf(0.0, damage_per_second + (context.cast_state.damage_add if context.cast_state != null else 0.0)) * tick_interval
	var seen: Dictionary = {}
	for hit: Dictionary in _actor_hits(radius * 1.2):
		var collider := hit.get("collider", null) as Node
		var health := HealthComponent.find_on(collider) if collider != null else null
		if health == null or seen.has(health):
			continue
		var actor := health.get_parent() as Node2D
		if actor == null:
			continue
		var local := (actor.global_position - global_position).rotated(-_elapsed * 3.0)
		if not (absf(local.x) <= arm_half and absf(local.y) <= width or absf(local.y) <= arm_half and absf(local.x) <= width):
			continue
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(actor)
		if not FactionComponent.can_damage(source_faction, target_faction):
			continue
		var packet := DamagePacket.create(resolved_damage, DamageTypes.Type.PROJECTILE, self, context.caster, actor.global_position)
		packet.tags.append(&"death_cross")
		health.take_damage(packet)
		seen[health] = true

func _apply_cone_damage() -> void:
	var caster := context.caster as Node2D
	if caster == null:
		return
	var resolved_damage := maxf(0.0, damage_per_second + (context.cast_state.damage_add if context.cast_state != null else 0.0)) * tick_interval
	var seen: Dictionary = {}
	for hit: Dictionary in _actor_hits(radius):
		var collider := hit.get("collider", null) as Node
		var health := HealthComponent.find_on(collider) if collider != null else null
		if health == null or seen.has(health):
			continue
		var actor := health.get_parent() as Node2D
		if actor == null:
			continue
		var from_caster := actor.global_position - caster.global_position
		if from_caster.length_squared() <= 0.0001:
			continue
		if from_caster.length() > radius or absf(rad_to_deg(context.direction.angle_to(from_caster.normalized()))) > 28.0:
			continue
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(actor)
		if not FactionComponent.can_damage(source_faction, target_faction):
			continue
		var packet := DamagePacket.create(resolved_damage, DamageTypes.Type.FIRE, self, context.caster, actor.global_position, context.direction, 6.0)
		packet.tags.append(&"dragon_breath")
		health.take_damage(packet)
		var status := StatusComponent.find_on(actor)
		if status != null:
			status.ignite(1.2, context.caster)
		seen[health] = true

func _paint_fire_cone() -> void:
	if context.world_interface == null or not context.world_interface.has_method("paint_material_circle"):
		return
	var caster := context.caster as Node2D
	if caster == null:
		return
	for step: int in range(2, 7):
		var distance := radius * float(step) / 7.0
		var perpendicular := Vector2(-context.direction.y, context.direction.x)
		var jitter := perpendicular * _rng.randf_range(-distance * 0.16, distance * 0.16)
		var point := caster.global_position + context.direction * distance + jitter
		context.world_interface.call("paint_material_circle", point.round(), 1.5, GameplayMaterialRules.FIRE_ID, true)

func _erode_terrain() -> void:
	if terrain_radius <= 0.0 or context.world_interface == null or not context.world_interface.has_method("erase_material_circle"):
		return
	context.world_interface.call("erase_material_circle", global_position.round(), terrain_radius)

func _finish() -> void:
	PixelSpellVFX.spawn_burst(get_parent(), global_position, primary, secondary, 12, 105.0, 0.32, 1.0)
	queue_free()

func _draw() -> void:
	match mode:
		Mode.BLACK_HOLE:
			var pulse := 5.0 + sin(_elapsed * 10.0) * 1.0
			draw_rect(Rect2(Vector2(-pulse, -pulse), Vector2.ONE * pulse * 2.0), Color(0.03, 0.01, 0.08, 1.0))
			for index: int in range(8):
				var angle := _elapsed * (2.0 + float(index % 3)) + float(index) * TAU / 8.0
				var orbit := Vector2.from_angle(angle) * (9.0 + float(index % 3) * 3.0)
				draw_rect(Rect2(orbit.round(), Vector2.ONE * (1.0 + float(index % 2))), primary if index % 2 == 0 else secondary)
		Mode.DEATH_CROSS:
			var arm := radius
			var width := maxf(2.0, floorf(radius * 0.14))
			var transform_angle := _elapsed * 3.0
			draw_set_transform(Vector2.ZERO, transform_angle, Vector2.ONE)
			draw_rect(Rect2(Vector2(-arm, -width), Vector2(arm * 2.0, width * 2.0)), primary)
			draw_rect(Rect2(Vector2(-width, -arm), Vector2(width * 2.0, arm * 2.0)), primary)
			draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), secondary)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Mode.DRAGON_BREATH:
			for index: int in range(16):
				var t := float(index + 1) / 16.0
				var x := t * radius * 0.75
				var y := sin(float(index) * 2.7 + _elapsed * 13.0) * (2.0 + t * radius * 0.16)
				draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE * (2.0 if index % 3 == 0 else 1.0)), primary if index % 3 != 0 else secondary)
		Mode.CHAINSAW:
			for index: int in range(10):
				var x := float(index) * 2.0 - 10.0
				var y := float((index + int(_elapsed * 30.0)) % 3 - 1)
				draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 1)), primary if index % 2 == 0 else secondary)
		Mode.GLUE_FIELD:
			for index: int in range(14):
				var angle := float(index) * 2.399 + _elapsed * 0.2
				var distance := radius * sqrt(float(index + 1) / 14.0) * 0.72
				var point := Vector2.from_angle(angle) * distance
				draw_rect(Rect2(point.round(), Vector2.ONE * (2.0 if index % 4 == 0 else 1.0)), primary if index % 3 else secondary)
