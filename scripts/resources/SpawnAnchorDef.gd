class_name SpawnAnchorDef
extends Resource

## Authored gameplay anchor embedded in a PieceDef/SpecialChunkDef. Coordinates
## are local pixels relative to the authored piece/chunk origin.
@export var anchor_id: StringName = &""
@export var local_position: Vector2 = Vector2.ZERO
@export var tags: Array[StringName] = []
@export_range(0.0, 100.0, 0.05) var weight: float = 1.0
@export var clearance_radius: float = 0.0
@export var enabled: bool = true


func is_valid() -> bool:
	return anchor_id != &"" and weight >= 0.0 and clearance_radius >= 0.0


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
