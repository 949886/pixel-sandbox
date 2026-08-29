class_name BiomeConfig
extends Resource

@export var id: StringName = &"mine"
@export var display_name: String = "Mine"

@export_range(0.0, 1.0) var open_chance_main_path: float = 0.82
@export_range(0.0, 1.0) var open_chance_special: float = 0.64
@export_range(0.0, 1.0) var open_chance_cave: float = 0.62
@export_range(0.0, 1.0) var open_chance_solid: float = 0.28

@export var depth_min: int = 0
@export var depth_max: int = 999

@export_category("Generated glue visuals")
@export var glue_rock_color: Color = Color8(54, 50, 45, 255)
@export var glue_dark_color: Color = Color8(32, 28, 25, 255)

@export_category("World structure")
@export_range(0.0, 1.0) var structure_main_path_wander_chance: float = 0.34
@export_range(0.0, 1.0) var structure_branch_chance: float = 0.56
@export_range(2, 8, 1) var structure_branch_max_length: int = 5
@export_range(0.0, 1.0) var structure_loop_chance: float = 0.32
@export_range(0.0, 1.0) var structure_chamber_chance: float = 0.38
@export var structure_chamber_sizes: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(1, 2),
]

func is_valid() -> bool:
	if id == &"" or depth_max < depth_min:
		return false
	if structure_branch_max_length < 2 or structure_chamber_sizes.is_empty():
		return false
	for size: Vector2i in structure_chamber_sizes:
		if size.x <= 0 or size.y <= 0:
			return false
	return true
