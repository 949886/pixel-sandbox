class_name ChainLightningEffect
extends GameplayEffect

@export var initial_damage: float = 18.0
@export var chain_distance: float = 120.0
@export_range(1, 8, 1) var max_chains: int = 3
@export_range(0.1, 1.0, 0.05) var chain_damage_multiplier: float = 0.7
@export var stun_duration: float = 0.65
@export var actor_collision_mask: int = 6
@export var primary_color := Color(0.55, 0.88, 1.0, 1.0)
@export var secondary_color := Color.WHITE

func execute(context: CastContext) -> void:
	if context == null or context.projectile_parent == null:
		return
	var hit_target := context.target as Node2D
	if hit_target == null:
		return
	var visited: Dictionary = {hit_target: true}
	var current := hit_target
	var current_position := context.hit_position
	for chain_index: int in range(max_chains):
		var target := _find_nearest_target(context, current_position, visited)
		if target == null:
			break
		PixelArcVFX.spawn_arc(context.projectile_parent, current_position, target.global_position, primary_color, secondary_color, 8.0, 0.14, 1.0)
		var health := HealthComponent.find_on(target)
		if health != null:
			var resolved_damage := (initial_damage + (context.cast_state.damage_add if context.cast_state != null else 0.0)) * pow(chain_damage_multiplier, chain_index)
			var strike_delta := target.global_position - current_position
			var strike_direction := strike_delta.normalized() if strike_delta.length_squared() > 0.0001 else context.direction
			var packet := DamagePacket.create(resolved_damage, DamageTypes.Type.ELECTRIC, context.source, context.caster, target.global_position, strike_direction, 12.0)
			packet.tags.append(&"chain_lightning")
			health.take_damage(packet)
		var status := StatusComponent.find_on(target)
		if status != null and stun_duration > 0.0:
			status.apply_stun(stun_duration * (1.0 + 0.15 * chain_index))
		visited[target] = true
		current = target
		current_position = current.global_position

func _find_nearest_target(context: CastContext, position: Vector2, visited: Dictionary) -> Node2D:
	var canvas := context.projectile_parent as Node2D
	if canvas == null:
		return null
	var world := canvas.get_world_2d()
	if world == null or chain_distance <= 0.0:
		return null
	var shape := CircleShape2D.new()
	shape.radius = maxf(0.01, chain_distance)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = actor_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := world.direct_space_state.intersect_shape(query, 64)
	var best: Node2D = null
	var best_distance := INF
	for hit: Dictionary in hits:
		var collider := hit.get("collider", null) as Node
		if collider == null:
			continue
		var actor := collider as Node2D
		if actor == null or visited.has(actor):
			continue
		var health := HealthComponent.find_on(actor)
		if health == null:
			continue
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(actor)
		if not FactionComponent.can_damage(source_faction, target_faction):
			continue
		var distance := position.distance_squared_to(actor.global_position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best
