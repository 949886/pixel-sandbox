class_name DamageEffect
extends GameplayEffect

@export var amount: float = 10.0
@export_enum("Physical", "Projectile", "Fire", "Explosion", "Electric", "Toxic", "Environment") var damage_type: int = DamageTypes.Type.PROJECTILE
@export var impulse: float = 0.0
@export var tag: StringName = &"spell"
@export var critical_multiplier: float = 2.0

func execute(context: CastContext) -> void:
	if context == null or context.target == null:
		return
	var resolved_amount := amount + (context.cast_state.damage_add if context.cast_state != null else 0.0)
	if resolved_amount <= 0.0:
		return
	var target_health := HealthComponent.find_on(context.target)
	if target_health == null:
		return
	var source_faction := FactionComponent.find_on(context.caster)
	var target_faction := FactionComponent.find_on(context.target)
	if not FactionComponent.can_damage(source_faction, target_faction):
		return
	var critical_chance := context.cast_state.critical_chance if context.cast_state != null else 0.0
	var critical := critical_chance > 0.0 and context.rng != null and context.rng.randf() < critical_chance
	if critical:
		resolved_amount *= critical_multiplier
	var packet := DamagePacket.create(
		resolved_amount,
		damage_type,
		context.source,
		context.caster,
		context.hit_position,
		context.direction,
		impulse
	)
	if not tag.is_empty():
		packet.tags.append(tag)
	if critical:
		packet.tags.append(&"critical")
		target_health.take_damage(packet)
		PixelSpellVFX.spawn_burst(context.projectile_parent, context.hit_position, Color.WHITE, Color(1.0, 0.8, 0.25, 1.0), 9, 125.0, 0.22, 1.0)
	else:
		target_health.take_damage(packet)
