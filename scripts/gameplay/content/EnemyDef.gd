class_name EnemyDef
extends Resource

## Catalog-level enemy metadata. Enemy-specific tuning remains serialized in the
## referenced scene/resource composition so new enemies do not require registry
## code changes.
@export var enemy_id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export_range(0.0, 1000.0, 0.25) var threat_cost: float = 1.0
@export var placement_tags: Array[StringName] = []


func is_valid() -> bool:
	return enemy_id != &"" and scene != null and threat_cost >= 0.0
