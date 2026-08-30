class_name WorldDefinition
extends Resource

## Macro world composition. The layout scene is authored visually with
## BiomeLayer/ChunkLayer; IDs select semantic anchors without script paths.
@export var id: StringName = &""
@export var layout_scene: PackedScene
@export var player_spawn_anchor_id: StringName = &""
@export var main_entrance_anchor_id: StringName = &""
@export var main_path_start_anchor_id: StringName = &""
@export var main_path_end_anchor_id: StringName = &""


func is_valid() -> bool:
	return id != &"" \
		and layout_scene != null \
		and player_spawn_anchor_id != &"" \
		and main_entrance_anchor_id != &"" \
		and main_path_start_anchor_id != &""
