class_name WorldRuntimeProfile
extends Resource

# Runtime/streaming profile selected by WorldManager. Generation content belongs in
# WorldGenConfig; platform and pixel-simulation behavior belongs here.
@export var id: StringName = &"pc"
@export var display_name: String = "PC"

@export var use_threaded_chunk_generation: bool = true
@export var use_threaded_special_generation: bool = true
@export_range(1, 4, 1) var load_radius: int = 2
@export_range(1, 8, 1) var main_thread_upload_budget_per_frame: int = 1

@export var keep_cpu_visual_images: bool = true
# Retained for config compatibility. PixelCanvas always simulates at native chunk resolution.
@export_range(1, 4, 1) var visual_texture_downscale_factor: int = 1
@export_range(0, 128, 1) var chunk_renderer_pool_limit: int = 64
@export_range(0, 128, 1) var special_renderer_pool_limit: int = 32

@export var simulation_enabled: bool = true
@export_range(0, 4, 1) var simulation_radius: int = 1
@export_range(1, 4, 1) var simulation_iterations: int = 1
@export_range(1.0, 60.0, 1.0) var simulation_repaint_hz: float = 15.0
@export var generate_static_collision: bool = true
@export_range(0, 20000, 100) var maximum_collision_triangles: int = 6000
@export var exchange_dynamic_materials_across_borders: bool = true
@export_range(1.0, 60.0, 1.0) var border_exchange_hz: float = 15.0

@export var debug_overlay_visible_on_start: bool = false
@export var world_debug_visible_on_start: bool = false
@export_range(0.05, 1.0, 0.05) var debug_update_interval: float = 0.20
@export_range(0.05, 1.0, 0.05) var world_debug_redraw_interval: float = 0.15

@export var show_world_debug_chunk_bounds: bool = true
@export var show_world_debug_socket_profiles: bool = true
@export var show_world_debug_chunk_labels: bool = true
@export var show_world_debug_piece_bounds: bool = true
