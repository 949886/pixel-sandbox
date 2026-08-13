class_name HitscanEffect
extends GameplayEffect

@export var cast_range: float = 300.0
@export var collision_mask: int = 5
@export var damage: float = 15.0
@export_enum("Physical", "Projectile", "Fire", "Explosion", "Electric", "Toxic", "Environment") var damage_type: int = DamageTypes.Type.ELECTRIC
@export var stun_duration: float = 0.0
@export var pixel_variance: float = 5.0
@export var primary_color := Color(0.55, 0.9, 1.0, 1.0)
@export var secondary_color := Color.WHITE

func execute(context: CastContext) -> void:
	if context == null or context.projectile_parent == null:
		return
	var canvas := context.projectile_parent as Node2D
	if canvas == null:
		return
	var world := canvas.get_world_2d()
	if world == null:
		return
	var safe_direction := context.direction.normalized() if context.direction.length_squared() > 0.0001 else Vector2.RIGHT
	var resolved_range := maxf(0.01, cast_range)
	var start := context.origin
	var finish := start + safe_direction * resolved_range
	var query := PhysicsRayQueryParameters2D.create(start, finish, collision_mask)
	if context.caster is CollisionObject2D:
		query.exclude = [(context.caster as CollisionObject2D).get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	var end_position := finish
	var collider: Node = null
	if not hit.is_empty():
		end_position = hit.get("position", finish)
		collider = hit.get("collider", null) as Node
	PixelArcVFX.spawn_arc(context.projectile_parent, start, end_position, primary_color, secondary_color, pixel_variance, 0.13, 1.0)
	if collider == null:
		return
	var health := HealthComponent.find_on(collider)
	if health != null:
		var source_faction := FactionComponent.find_on(context.caster)
		var target_faction := FactionComponent.find_on(collider)
		if FactionComponent.can_damage(source_faction, target_faction):
			var resolved_damage := damage + (context.cast_state.damage_add if context.cast_state != null else 0.0)
			var packet := DamagePacket.create(resolved_damage, damage_type, context.source, context.caster, end_position, context.direction, resolved_damage * 1.2)
			packet.tags.append(&"hitscan")
			health.take_damage(packet)
	if stun_duration > 0.0:
		var status := StatusComponent.find_on(collider)
		if status != null:
			status.apply_stun(stun_duration)
	PixelSpellVFX.spawn_burst(context.projectile_parent, end_position, primary_color, secondary_color, 10, 120.0, 0.2, 1.0)
