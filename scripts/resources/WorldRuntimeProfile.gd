class_name WorldRuntimeProfile
extends Resource

# Platform streaming/simulation profile. All expensive runtime work is governed by
# time budgets so a slow device degrades loading latency instead of frame time.
@export var id: StringName = &"pc"
@export var display_name: String = "PC"

@export var use_threaded_chunk_generation: bool = true
@export var use_threaded_special_generation: bool = true
@export_range(0, 8, 1) var generation_worker_yield_ms: int = 0
@export_range(0, 8, 1) var special_worker_yield_ms: int = 0
@export_range(1, 4, 1) var load_radius: int = 2
@export_range(1, 8, 1) var main_thread_upload_budget_per_frame: int = 1
@export_range(1, 16, 1) var ready_attach_queue_limit: int = 6
@export_range(1, 8, 1) var generation_result_backlog: int = 3
@export_range(1.0, 12.0, 0.25) var streaming_pipeline_budget_ms: float = 6.0
@export_range(0.25, 8.0, 0.25) var chunk_attach_budget_ms: float = 1.5
@export_range(0.25, 8.0, 0.25) var simulation_warmup_budget_ms: float = 2.0
@export_range(256, 65536, 256) var simulation_warmup_pixels_per_slice: int = 8192
@export_range(0.25, 8.0, 0.25) var simulation_texture_activation_budget_ms: float = 1.0
@export_range(1, 4, 1) var simulation_texture_activations_per_frame: int = 1
@export_range(0, 3, 1) var predictive_prewarm_chunks: int = 1
@export_range(0.10, 4.0, 0.10) var critical_collision_budget_ms: float = 1.0
@export_range(0.25, 8.0, 0.25) var collision_build_budget_ms: float = 1.0
@export_range(1, 128, 1) var collision_shapes_per_slice: int = 12
@export_range(0.25, 12.0, 0.25) var simulation_update_budget_ms: float = 3.0
@export_range(0.1, 4.0, 0.1) var recycle_budget_ms: float = 0.5

@export var keep_cpu_visual_images: bool = false
@export_range(1, 4, 1) var visual_texture_downscale_factor: int = 1
@export_range(0, 128, 1) var chunk_renderer_pool_limit: int = 64
@export_range(0, 128, 1) var special_renderer_pool_limit: int = 32

@export var simulation_enabled: bool = true
@export_range(0, 4, 1) var simulation_radius: int = 1
@export_range(1, 4, 1) var simulation_iterations: int = 1
@export_range(1.0, 120.0, 1.0) var simulation_hz: float = 60.0
@export_range(1.0, 60.0, 1.0) var background_simulation_hz: float = 12.0
@export_range(1.0, 120.0, 1.0) var simulation_repaint_hz: float = 60.0
@export var generate_static_collision: bool = true
@export_range(0, 4, 1) var collision_radius: int = 1
@export_range(1, 32, 1) var collision_cell_size: int = 1
@export_range(16, 256, 16) var collision_sector_size: int = 64
@export_range(1, 64, 1) var collision_sector_commits_per_physics_frame: int = 16
@export_range(1.0, 60.0, 1.0) var collision_dynamic_rebuild_hz: float = 20.0
# Retained for compatibility with V2 profiles; greedy rectangles replace triangles.
@export_range(0, 20000, 100) var maximum_collision_triangles: int = 6000
@export var exchange_dynamic_materials_across_borders: bool = true
@export_range(1.0, 60.0, 1.0) var border_exchange_hz: float = 10.0
@export_range(1, 16, 1) var border_seams_per_tick: int = 2

@export var debug_overlay_visible_on_start: bool = false
@export var world_debug_visible_on_start: bool = false
@export_range(0.05, 1.0, 0.05) var debug_update_interval: float = 0.25
@export_range(0.05, 1.0, 0.05) var world_debug_redraw_interval: float = 0.20
@export var show_world_debug_chunk_bounds: bool = true
@export var show_world_debug_socket_profiles: bool = true
@export var show_world_debug_chunk_labels: bool = true
@export var show_world_debug_piece_bounds: bool = true
