@tool
class_name WorldPresentationProfile
extends Resource

## Data-only presentation settings for one authored macro world. Runtime drawing
## code consumes this profile without knowing concrete world/content IDs.
@export var id: StringName = &""
@export var surface_reference_anchor_id: StringName = &""
@export var surface_y_offset: float = 0.0

@export_category("World coverage")
@export_range(0, 12, 1) var horizontal_margin_chunks: int = 3
@export_range(0, 12, 1) var top_margin_chunks: int = 3
@export_range(0, 12, 1) var bottom_margin_chunks: int = 2

@export_category("Atmosphere")
@export var sky_top_color: Color = Color(0.02, 0.07, 0.09, 1.0)
@export var sky_horizon_color: Color = Color(0.08, 0.18, 0.17, 1.0)
@export var underground_color: Color = Color(0.025, 0.022, 0.03, 1.0)
@export_range(2, 32, 1) var gradient_bands: int = 12
@export_range(0.0, 4096.0, 16.0) var underground_transition_depth: float = 768.0

@export_category("Surface silhouettes")
@export var draw_surface_silhouettes: bool = true
@export var far_silhouette_color: Color = Color(0.035, 0.12, 0.13, 1.0)
@export var near_silhouette_color: Color = Color(0.025, 0.085, 0.09, 1.0)
@export_range(0.0, 1024.0, 8.0) var far_mountain_height: float = 190.0
@export_range(0.0, 1024.0, 8.0) var near_mountain_height: float = 110.0
@export_range(64.0, 1024.0, 8.0) var mountain_step: float = 224.0


func is_valid() -> bool:
	return id != &"" \
		and surface_reference_anchor_id != &"" \
		and horizontal_margin_chunks >= 0 \
		and top_margin_chunks >= 0 \
		and bottom_margin_chunks >= 0 \
		and gradient_bands >= 2 \
		and underground_transition_depth >= 0.0 \
		and mountain_step >= 64.0
