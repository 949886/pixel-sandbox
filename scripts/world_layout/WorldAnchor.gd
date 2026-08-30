@tool
class_name WorldAnchor
extends Marker2D

## Visual world-level anchor placed directly in the WorldLayout scene.
@export var anchor_id: StringName = &""
@export var tags: Array[StringName] = []
@export_range(0.0, 256.0, 1.0) var clearance_radius: float = 20.0
@export var clearance_offset: Vector2 = Vector2(0.0, -10.0)


func is_valid() -> bool:
	return anchor_id != &"" and clearance_radius >= 0.0
