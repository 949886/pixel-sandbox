class_name LootEntryDef
extends Resource

## One independently rolled entry in a LootTableDef.
##
## The entry owns the PackedScene and payload contract as serialized data. The
## runtime spawner therefore never maps a gameplay id to a path or concrete
## pickup scene in code.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var drop_scene: PackedScene
@export var payload_property: StringName = &""
@export var requires_payload: bool = false
@export var offset_min: Vector2 = Vector2.ZERO
@export var offset_max: Vector2 = Vector2.ZERO


func is_valid() -> bool:
	return drop_scene != null and chance >= 0.0 and chance <= 1.0


func roll_payload(_content: GameplayContentDB, _rng: RandomNumberGenerator) -> Variant:
	return null


func roll_offset(rng: RandomNumberGenerator) -> Vector2:
	if rng == null:
		return (offset_min + offset_max) * 0.5
	return Vector2(
		rng.randf_range(minf(offset_min.x, offset_max.x), maxf(offset_min.x, offset_max.x)),
		rng.randf_range(minf(offset_min.y, offset_max.y), maxf(offset_min.y, offset_max.y)),
	)
