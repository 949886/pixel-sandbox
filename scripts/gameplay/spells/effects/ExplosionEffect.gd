class_name ExplosionEffect
extends GameplayEffect

@export var radius: float = 28.0
@export var damage: float = 34.0
@export var terrain_radius: float = 20.0
@export var impulse: float = 220.0
@export var actor_collision_mask: int = 6
@export var particle_count: int = 28
@export var primary_color := Color(1.0, 0.72, 0.18, 1.0)
@export var secondary_color := Color(1.0, 0.22, 0.08, 1.0)
@export var spawn_fire_pixels: bool = false
@export var fire_pixel_radius: float = 3.0

func execute(context: CastContext) -> void:
	if context == null:
		return
	var radius_bonus := context.cast_state.radius_add if context.cast_state != null else 0.0
	var resolved_terrain_radius := maxf(0.0, terrain_radius + radius_bonus)
	if resolved_terrain_radius > 0.0 and context.world_interface != null and context.world_interface.has_method("erase_material_circle"):
		context.world_interface.call("erase_material_circle", context.hit_position, resolved_terrain_radius)
	if spawn_fire_pixels and context.world_interface != null and context.world_interface.has_method("paint_material_circle"):
		context.world_interface.call("paint_material_circle", context.hit_position, maxf(1.0, fire_pixel_radius + radius_bonus * 0.15), 5, true)
	_damage_actors(context, maxf(1.0, radius + radius_bonus))
	PixelSpellVFX.spawn_burst(
		context.projectile_parent,
		context.hit_position,
		primary_color,
		secondary_color,
		particle_count,
		155.0,
		0.42,
		2.0,
		Vector2.ZERO,
		360.0,
		95.0
	)

func _damage_actors(context: CastContext, resolved_radius: float) -> void:
	var resolved_damage := damage + (context.cast_state.damage_add if context.cast_state != null else 0.0)
	if resolved_damage <= 0.0 or resolved_radius <= 0.0 or context.projectile_parent == null:
		return
	var canvas := context.projectile_parent as Node2D
	if canvas == null:
		return
	var world := canvas.get_world_2d()
	if world == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = resolved_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, context.hit_position)
	query.collision_mask = actor_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := world.direct_space_state.intersect_shape(query, 64)
	var damaged_health: Dictionary = {}
	for hit: Dictionary in hits:
		var collider := hit.get("collider", null) as Node
		var health := HealthComponent.find_on(collider) if collider != null else null
		if health == null or damaged_health.has(health):
			continue
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(collider)
		if not FactionComponent.can_damage(source_faction, target_faction):
			continue
		var target_node := health.get_parent() as Node2D
		if target_node == null or not is_instance_valid(target_node):
			continue
		var target_delta := target_node.global_position - context.hit_position
		var distance := target_delta.length()
		var falloff := clampf(1.0 - distance / maxf(resolved_radius, 1.0), 0.25, 1.0)
		var direction := target_delta.normalized() if target_delta.length_squared() > 0.0001 else context.direction
		var packet := DamagePacket.create(
			resolved_damage * falloff,
			DamageTypes.Type.EXPLOSION,
			context.source,
			context.caster,
			context.hit_position,
			direction,
			impulse * falloff
		)
		packet.tags.append(&"explosion")
		health.take_damage(packet)
		damaged_health[health] = true
