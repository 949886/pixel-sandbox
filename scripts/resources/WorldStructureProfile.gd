class_name WorldStructureProfile
extends Resource

## Global topology tuning shared by biomes. Spatial ownership/bounds are authored
## exclusively by WorldLayout/BiomeLayer; this profile must not define another
## world rectangle.
@export_range(0.0, 1.0, 0.01) var shoulder_chance: float = 0.72
@export var branch_start_offset_y: int = 2
@export var branch_end_margin_y: int = 3
@export_range(0.0, 1.0, 0.01) var branch_vertical_step_chance: float = 0.30
@export var branch_row_advance_min: int = 2
@export var branch_row_advance_max: int = 4
@export var loop_target_depth_min: int = 1
@export var loop_target_depth_max: int = 3
@export var chamber_start_offset_y: int = 4
@export var chamber_end_margin_y: int = 4
@export_range(1, 32, 1) var chamber_row_step: int = 5
@export var chamber_horizontal_offset_min: int = 3
@export var chamber_horizontal_offset_max: int = 7
@export var chamber_vertical_jitter: int = 1


func is_valid() -> bool:
	return branch_start_offset_y >= 0 \
		and branch_end_margin_y >= 0 \
		and branch_row_advance_min > 0 \
		and branch_row_advance_max >= branch_row_advance_min \
		and loop_target_depth_min >= 0 \
		and loop_target_depth_max >= loop_target_depth_min \
		and chamber_start_offset_y >= 0 \
		and chamber_end_margin_y >= 0 \
		and chamber_horizontal_offset_min >= 0 \
		and chamber_horizontal_offset_max >= chamber_horizontal_offset_min \
		and chamber_vertical_jitter >= 0 \
		and chamber_row_step > 0
