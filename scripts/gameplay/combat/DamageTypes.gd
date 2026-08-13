class_name DamageTypes
extends RefCounted

## Shared gameplay damage categories. Keep this intentionally small for the
## first combat slice; resistances and spell modifiers can key off these values.
enum Type {
	PHYSICAL,
	PROJECTILE,
	FIRE,
	EXPLOSION,
	ELECTRIC,
	TOXIC,
	ENVIRONMENT,
}

static func display_name(type: int) -> String:
	match type:
		Type.PHYSICAL:
			return "Physical"
		Type.PROJECTILE:
			return "Projectile"
		Type.FIRE:
			return "Fire"
		Type.EXPLOSION:
			return "Explosion"
		Type.ELECTRIC:
			return "Electric"
		Type.TOXIC:
			return "Toxic"
		Type.ENVIRONMENT:
			return "Environment"
	return "Unknown"
