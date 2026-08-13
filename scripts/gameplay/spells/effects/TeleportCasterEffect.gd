class_name TeleportCasterEffect
extends GameplayEffect

@export var safety_offset: float = 4.0

func execute(context: CastContext) -> void:
	if context == null or not (context.caster is Node2D):
		return
	var caster := context.caster as Node2D
	var safe_normal := context.hit_normal
	if safe_normal.length_squared() <= 0.0001:
		safe_normal = -context.direction if context.direction.length_squared() > 0.0001 else Vector2.UP
	else:
		safe_normal = safe_normal.normalized()
	var target_position := context.hit_position + safe_normal * maxf(0.0, safety_offset)
	caster.global_position = target_position.round()
	if caster is CharacterBody2D:
		(caster as CharacterBody2D).velocity = Vector2.ZERO
	PixelSpellVFX.spawn_burst(context.projectile_parent, target_position, Color(0.72, 0.45, 1.0, 1.0), Color(0.2, 0.9, 1.0, 1.0), 22, 120.0, 0.32, 1.0)
