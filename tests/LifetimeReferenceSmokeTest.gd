extends Node

## Regression for V4.2.1: delayed projectiles may outlive their caster/source.
## Expired Node references must resolve to null rather than propagate the
## `previously freed` handle that used to crash CastContext.duplicate_for_impact().
func _ready() -> void:
	var caster := Node2D.new()
	caster.name = "TemporaryCaster"
	add_child(caster)

	var context := CastContext.create(caster, caster, self, self, Vector2(10, 20), Vector2.RIGHT)
	assert(context.caster == caster)
	assert(context.source == caster)

	caster.free()
	assert(context.caster == null)
	assert(context.source == null)

	var impact := context.duplicate_for_impact(null, Vector2(30, 40), Vector2.LEFT)
	assert(impact.caster == null)
	assert(impact.source == null)
	assert(impact.projectile_parent == self)
	assert(impact.world_interface == self)

	# DamagePacket is hardened too because status effects can tick after their
	# original instigator has disappeared.
	var packet := DamagePacket.create(5.0, DamageTypes.Type.FIRE, caster, caster, Vector2.ZERO)
	assert(packet.source == null)
	assert(packet.instigator == null)

	# Legacy projectiles also keep their source/world references weak so an
	# enemy projectile can safely outlive the enemy that fired it.
	var projectile_caster := CharacterBody2D.new()
	add_child(projectile_caster)
	var projectile := GameplayProjectile.new()
	add_child(projectile)
	projectile.setup(Vector2.RIGHT, projectile_caster, self, 100.0, 1.0)
	projectile_caster.free()
	assert(projectile.source == null)
	assert(projectile.world_interface == self)
	projectile.free()

	print("Lifetime Reference Smoke Test: PASS")
	get_tree().quit()
