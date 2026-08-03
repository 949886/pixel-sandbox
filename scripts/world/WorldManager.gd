extends Node2D

# Runtime streaming coordinator for the migrated piece world.
# TileMap generation has been removed from the main runtime path; chunks are
# generated as 4 x 4 piece-unit images where each unit is 128px.
#
# Threading model:
# - Background worker: PieceChunkData + visual/material Image composition.
# - Main thread: scene-tree changes, ImageTexture upload, debug UI updates.

const DEFAULT_CONFIG_PATH: String = "res://resources/world_gen/default_world_gen_config.tres"
const DEFAULT_MATERIAL_PALETTE_PATH: String = "res://resources/materials/default_material_palette.tres"
const PC_RUNTIME_PROFILE_PATH: String = "res://resources/runtime_profiles/pc_runtime_profile.tres"
const MOBILE_RUNTIME_PROFILE_PATH: String = "res://resources/runtime_profiles/mobile_runtime_profile.tres"
const PROFILE_AUTO: int = 0
const PROFILE_PC: int = 1
const PROFILE_MOBILE: int = 2
const PROFILE_CUSTOM: int = 3
const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

@export var world_gen_config: WorldGenConfig
@export var piece_library: PieceLibrary
@export var material_palette: MaterialPalette
@export var override_seed: bool = false
@export var world_seed: int = 20260706
@export var use_runtime_generated_fallback: bool = false
@export_enum("Auto", "PC", "Mobile", "Custom") var runtime_profile_mode: int = PROFILE_AUTO
@export var pc_runtime_profile: WorldRuntimeProfile
@export var mobile_runtime_profile: WorldRuntimeProfile
@export var custom_runtime_profile: WorldRuntimeProfile

var runtime_profile: WorldRuntimeProfile
var use_threaded_chunk_generation: bool = true
var use_threaded_special_generation: bool = true
var generation_worker_yield_ms: int = 0
var special_worker_yield_ms: int = 0
var main_thread_upload_budget_per_frame: int = 2
var ready_attach_queue_limit: int = 6
var generation_result_backlog: int = 3
var streaming_pipeline_budget_ms: float = 6.0
var keep_cpu_visual_images: bool = true
var visual_texture_downscale_factor: int = 1
var chunk_renderer_pool_limit: int = 64
var debug_update_interval: float = 0.20
var simulation_enabled: bool = true
var simulation_radius: int = 1
var simulation_iterations: int = 1
var simulation_hz: float = 60.0
var background_simulation_hz: float = 12.0
var simulation_repaint_hz: float = 60.0
var generate_static_collision: bool = true
var maximum_collision_triangles: int = 6000
var exchange_dynamic_materials_across_borders: bool = true
var border_exchange_hz: float = 15.0
var border_seams_per_tick: int = 2
var chunk_attach_budget_ms: float = 1.5
var simulation_warmup_budget_ms: float = 2.0
var simulation_warmup_pixels_per_slice: int = 8192
var simulation_texture_activation_budget_ms: float = 1.0
var simulation_texture_activations_per_frame: int = 1
var predictive_prewarm_chunks: int = 1
var collision_build_budget_ms: float = 1.0
var collision_shapes_per_slice: int = 12
var simulation_update_budget_ms: float = 3.0
var collision_radius: int = 1
var collision_cell_size: int = 8
var recycle_budget_ms: float = 0.5

var library: PieceLibrary
var generator: PieceChunkGenerator
var chunk_worker: ChunkGenerationWorker
var loaded_chunks: Dictionary = {}
var chunk_renderers: Dictionary = {}
var chunk_renderer_pool: Array[PieceChunkRenderer] = []
var pending_chunks: Dictionary = {}
var wanted_chunks: Dictionary = {}
var player: Node2D
var debug_overlay: CanvasLayer
var world_debug_drawer: WorldDebugDrawer
var debug_world_visible: bool = false
var active_config: WorldGenConfig
var load_radius: int = 2
var special_chunk_planner: SpecialChunkPlanner
var special_chunk_manager: SpecialChunkManager
var special_chunks_parent: Node2D
var chunk_renderers_parent: Node2D
var world_structure: WorldStructure
var debug_update_accum: float = 999.0
var cached_seam_debug: Dictionary = {}
var seam_debug_dirty: bool = true
var last_chunk_generation_ms: int = 0
var last_chunk_upload_count: int = 0
var current_player_chunk: Vector2i = Vector2i.ZERO
var _border_exchange_accumulator: float = 0.0
var _border_exchange_phase: int = 0
var ready_chunk_queue: Array[PieceChunkData] = []
var deferred_renderer_recycle_queue: Array[PieceChunkRenderer] = []
var _last_stream_center: Vector2i = Vector2i(2147483647, 2147483647)
var _activity_dirty: bool = true
var _simulation_round_robin_cursor: int = 0
var _last_warmup_count: int = 0
var _last_activation_count: int = 0
var _last_collision_shape_count: int = 0
var _last_simulation_tick_count: int = 0
var _last_prewarm_direction: Vector2i = Vector2i.ZERO
var _pipeline_deadline_usec: int = 0
var _last_pipeline_usec: int = 0

func _ready() -> void:
	active_config = _load_config()
	if active_config == null:
		push_error("WorldManager: Unable to load WorldGenConfig.")
		return
	if override_seed:
		active_config.world_seed = world_seed
	world_seed = active_config.world_seed
	runtime_profile = _resolve_runtime_profile()
	_apply_runtime_profile()
	library = _load_piece_library()
	if library == null:
		push_error("WorldManager: Unable to load PieceLibrary.")
		return
	material_palette = _load_material_palette()
	if material_palette == null:
		push_error("WorldManager: Unable to load MaterialPalette.")
		return
	material_palette.rebuild_cache()
	SandSimulationConfigurator.prepare(material_palette)
	# Important: this caches Texture2D -> Image on the main thread before any
	# background workers start.
	library.prepare()

	chunk_renderers_parent = get_node_or_null("ChunkRenderers") as Node2D
	if chunk_renderers_parent == null:
		chunk_renderers_parent = Node2D.new()
		chunk_renderers_parent.name = "ChunkRenderers"
		add_child(chunk_renderers_parent)

	_build_world_runtime()
	player = get_node_or_null("Player") as Node2D
	debug_overlay = get_node_or_null("DebugOverlay") as CanvasLayer
	world_debug_drawer = get_node_or_null("WorldDebugDrawer") as WorldDebugDrawer
	if world_debug_drawer != null:
		world_debug_drawer.world_manager = self
	_apply_runtime_profile_to_debug_nodes()
	if player == null:
		push_warning("WorldManager: Player node not found. Chunks will load around origin.")
	_update_loaded_chunks(true)

func _exit_tree() -> void:
	_stop_workers()

func _build_world_runtime() -> void:
	world_structure = WorldStructureBuilder.new(world_seed, active_config).build()
	var planning_biome_map: BiomeMap = BiomeMap.new(world_seed, active_config)
	planning_biome_map.world_structure = world_structure
	special_chunk_planner = SpecialChunkPlanner.new(world_seed, active_config, planning_biome_map, world_structure)
	special_chunks_parent = get_node_or_null("SpecialChunks") as Node2D
	if special_chunks_parent == null:
		special_chunks_parent = Node2D.new()
		special_chunks_parent.name = "SpecialChunks"
		add_child(special_chunks_parent)
	var special_pool_limit: int = runtime_profile.special_renderer_pool_limit if runtime_profile != null else 32
	special_chunk_manager = SpecialChunkManager.new(
		special_chunk_planner,
		special_chunks_parent,
		material_palette,
		use_threaded_special_generation,
		special_pool_limit,
		simulation_enabled,
		generate_static_collision,
		simulation_iterations,
		simulation_hz,
		simulation_repaint_hz,
		maximum_collision_triangles,
		collision_cell_size,
		visual_texture_downscale_factor,
		keep_cpu_visual_images,
		special_worker_yield_ms
	)
	generator = PieceChunkGenerator.new(
		world_seed,
		library,
		active_config,
		special_chunk_planner,
		world_structure,
		material_palette,
		collision_cell_size,
		visual_texture_downscale_factor,
		generate_static_collision
	)
	_start_chunk_worker()

func _start_chunk_worker() -> void:
	if not use_threaded_chunk_generation:
		chunk_worker = null
		return
	chunk_worker = ChunkGenerationWorker.new()
	if not chunk_worker.start(
		generator, generation_result_backlog, generation_worker_yield_ms
	):
		push_warning("WorldManager: chunk worker failed to start; falling back to synchronous generation.")
		chunk_worker = null
		use_threaded_chunk_generation = false

func _stop_workers() -> void:
	if chunk_worker != null:
		chunk_worker.stop()
		chunk_worker = null
	if special_chunk_manager != null:
		special_chunk_manager.stop()

func _load_config() -> WorldGenConfig:
	if world_gen_config != null:
		return world_gen_config
	var loaded: WorldGenConfig = ResourceLoader.load(DEFAULT_CONFIG_PATH) as WorldGenConfig
	if loaded != null:
		return loaded
	return null

func _load_piece_library() -> PieceLibrary:
	if piece_library != null:
		return piece_library.duplicate(false) as PieceLibrary
	if active_config != null and active_config.piece_library != null:
		return active_config.piece_library.duplicate(false) as PieceLibrary
	var loaded: PieceLibrary = ResourceLoader.load("res://resources/pieces/piece_library.tres") as PieceLibrary
	if loaded != null:
		return loaded.duplicate(false) as PieceLibrary
	var runtime_library: PieceLibrary = PieceLibrary.new()
	runtime_library.load_from_default_dirs()
	return runtime_library

func _load_material_palette() -> MaterialPalette:
	if material_palette != null:
		return material_palette
	return ResourceLoader.load(DEFAULT_MATERIAL_PALETTE_PATH) as MaterialPalette


func _resolve_runtime_profile() -> WorldRuntimeProfile:
	var mode: int = runtime_profile_mode
	if mode == PROFILE_AUTO:
		mode = PROFILE_MOBILE if _is_mobile_platform() else PROFILE_PC
	match mode:
		PROFILE_PC:
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)
		PROFILE_MOBILE:
			return _load_runtime_profile(mobile_runtime_profile, MOBILE_RUNTIME_PROFILE_PATH)
		PROFILE_CUSTOM:
			if custom_runtime_profile != null:
				return custom_runtime_profile
			push_warning("WorldManager: Runtime profile mode is Custom, but no custom_runtime_profile is assigned. Falling back to PC profile.")
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)
		_:
			return _load_runtime_profile(pc_runtime_profile, PC_RUNTIME_PROFILE_PATH)

func _load_runtime_profile(assigned_profile: WorldRuntimeProfile, fallback_path: String) -> WorldRuntimeProfile:
	if assigned_profile != null:
		return assigned_profile
	var loaded: WorldRuntimeProfile = ResourceLoader.load(fallback_path) as WorldRuntimeProfile
	if loaded != null:
		return loaded
	var fallback: WorldRuntimeProfile = WorldRuntimeProfile.new()
	fallback.display_name = "Fallback"
	return fallback

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.get_name() == "Android" or OS.get_name() == "iOS"

func _apply_runtime_profile() -> void:
	if runtime_profile == null:
		runtime_profile = _resolve_runtime_profile()
	load_radius = runtime_profile.load_radius if runtime_profile != null else active_config.load_radius
	use_threaded_chunk_generation = runtime_profile.use_threaded_chunk_generation if runtime_profile != null else true
	use_threaded_special_generation = runtime_profile.use_threaded_special_generation if runtime_profile != null else true
	generation_worker_yield_ms = runtime_profile.generation_worker_yield_ms if runtime_profile != null else 0
	special_worker_yield_ms = runtime_profile.special_worker_yield_ms if runtime_profile != null else 0
	main_thread_upload_budget_per_frame = runtime_profile.main_thread_upload_budget_per_frame if runtime_profile != null else 2
	ready_attach_queue_limit = runtime_profile.ready_attach_queue_limit if runtime_profile != null else 6
	generation_result_backlog = runtime_profile.generation_result_backlog if runtime_profile != null else 3
	streaming_pipeline_budget_ms = runtime_profile.streaming_pipeline_budget_ms if runtime_profile != null else 6.0
	keep_cpu_visual_images = runtime_profile.keep_cpu_visual_images if runtime_profile != null else true
	visual_texture_downscale_factor = runtime_profile.visual_texture_downscale_factor if runtime_profile != null else 1
	chunk_renderer_pool_limit = runtime_profile.chunk_renderer_pool_limit if runtime_profile != null else 64
	debug_update_interval = runtime_profile.debug_update_interval if runtime_profile != null else 0.20
	debug_world_visible = runtime_profile.world_debug_visible_on_start if runtime_profile != null else false
	simulation_enabled = runtime_profile.simulation_enabled if runtime_profile != null else true
	simulation_radius = runtime_profile.simulation_radius if runtime_profile != null else 1
	simulation_iterations = runtime_profile.simulation_iterations if runtime_profile != null else 1
	simulation_hz = runtime_profile.simulation_hz if runtime_profile != null else 60.0
	background_simulation_hz = runtime_profile.background_simulation_hz if runtime_profile != null else 12.0
	simulation_repaint_hz = runtime_profile.simulation_repaint_hz if runtime_profile != null else 60.0
	generate_static_collision = runtime_profile.generate_static_collision if runtime_profile != null else true
	maximum_collision_triangles = runtime_profile.maximum_collision_triangles if runtime_profile != null else 6000
	exchange_dynamic_materials_across_borders = runtime_profile.exchange_dynamic_materials_across_borders if runtime_profile != null else true
	border_exchange_hz = runtime_profile.border_exchange_hz if runtime_profile != null else 15.0
	border_seams_per_tick = runtime_profile.border_seams_per_tick if runtime_profile != null else 2
	chunk_attach_budget_ms = runtime_profile.chunk_attach_budget_ms if runtime_profile != null else 1.5
	simulation_warmup_budget_ms = runtime_profile.simulation_warmup_budget_ms if runtime_profile != null else 2.0
	simulation_warmup_pixels_per_slice = runtime_profile.simulation_warmup_pixels_per_slice if runtime_profile != null else 8192
	simulation_texture_activation_budget_ms = runtime_profile.simulation_texture_activation_budget_ms if runtime_profile != null else 1.0
	simulation_texture_activations_per_frame = runtime_profile.simulation_texture_activations_per_frame if runtime_profile != null else 1
	predictive_prewarm_chunks = runtime_profile.predictive_prewarm_chunks if runtime_profile != null else 1
	collision_build_budget_ms = runtime_profile.collision_build_budget_ms if runtime_profile != null else 1.0
	collision_shapes_per_slice = runtime_profile.collision_shapes_per_slice if runtime_profile != null else 12
	simulation_update_budget_ms = runtime_profile.simulation_update_budget_ms if runtime_profile != null else 3.0
	collision_radius = runtime_profile.collision_radius if runtime_profile != null else simulation_radius
	collision_cell_size = runtime_profile.collision_cell_size if runtime_profile != null else 8
	recycle_budget_ms = runtime_profile.recycle_budget_ms if runtime_profile != null else 0.5

func _apply_runtime_profile_to_debug_nodes() -> void:
	if runtime_profile == null:
		runtime_profile = _resolve_runtime_profile()
	if debug_overlay != null:
		debug_overlay.visible = runtime_profile.debug_overlay_visible_on_start if runtime_profile != null else false
	if world_debug_drawer != null:
		world_debug_drawer.visible = runtime_profile.world_debug_visible_on_start if runtime_profile != null else false
		debug_world_visible = world_debug_drawer.visible
		if runtime_profile != null:
			world_debug_drawer.redraw_interval = runtime_profile.world_debug_redraw_interval
			world_debug_drawer.show_chunk_bounds = runtime_profile.show_world_debug_chunk_bounds
			world_debug_drawer.show_socket_profiles = runtime_profile.show_world_debug_socket_profiles
			world_debug_drawer.show_chunk_labels = runtime_profile.show_world_debug_chunk_labels
			world_debug_drawer.show_piece_bounds = runtime_profile.show_world_debug_piece_bounds

func _process(delta: float) -> void:
	var pipeline_started_usec: int = Time.get_ticks_usec()
	_pipeline_deadline_usec = pipeline_started_usec + int(streaming_pipeline_budget_ms * 1000.0)
	var prewarm_direction: Vector2i = _current_prewarm_direction()
	if prewarm_direction != _last_prewarm_direction:
		_last_prewarm_direction = prewarm_direction
		_activity_dirty = true
	_update_loaded_chunks(false)
	# Existing foreground simulation is the most latency-sensitive work. Refresh its
	# rate/activity immediately after player movement, before any chunk attachment or
	# loading work can consume this frame's budget.
	if _activity_dirty:
		_update_simulation_activity()
		_activity_dirty = false
	_process_simulation_budget()

	var collect_capacity: int = maxi(0, ready_attach_queue_limit - ready_chunk_queue.size())
	if collect_capacity > 0:
		_collect_chunk_results(collect_capacity)
	var attach_started_usec: int = Time.get_ticks_usec()
	var attach_deadline_usec: int = mini(
		_pipeline_deadline_usec, attach_started_usec + int(chunk_attach_budget_ms * 1000.0)
	)
	var normal_uploads: int = _attach_ready_chunks(main_thread_upload_budget_per_frame, attach_deadline_usec)
	var special_uploads: int = 0
	if special_chunk_manager != null and Time.get_ticks_usec() < attach_deadline_usec:
		var remaining_uploads: int = maxi(0, main_thread_upload_budget_per_frame - normal_uploads)
		if remaining_uploads > 0:
			special_uploads = special_chunk_manager.process_ready(remaining_uploads)
			if special_uploads > 0:
				_activity_dirty = true
	last_chunk_upload_count = normal_uploads + special_uploads
	# Newly attached canvases receive their timing before warmup starts. They join the
	# simulation scheduler on the following frame, avoiding a same-frame load spike.
	if _activity_dirty:
		_update_simulation_activity()
		_activity_dirty = false
	# Collision safety comes before visual warmup. Initial/current-direction collision
	# snapshots must become complete before optional texture work consumes the budget.
	_process_collision_budget()
	_process_warmup_budget()
	_process_texture_activation_budget()
	_process_recycle_budget()
	if exchange_dynamic_materials_across_borders and simulation_enabled:
		_border_exchange_accumulator += delta
		var border_interval: float = 1.0 / maxf(border_exchange_hz, 1.0)
		if _border_exchange_accumulator >= border_interval and Time.get_ticks_usec() < _pipeline_deadline_usec:
			_border_exchange_accumulator = fmod(_border_exchange_accumulator, border_interval)
			_exchange_chunk_borders()
	_last_pipeline_usec = Time.get_ticks_usec() - pipeline_started_usec
	debug_update_accum += delta
	if debug_update_accum >= debug_update_interval:
		debug_update_accum = 0.0
		_update_debug_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				if debug_overlay != null:
					debug_overlay.visible = not debug_overlay.visible
					debug_update_accum = debug_update_interval
			KEY_F2:
				debug_world_visible = not debug_world_visible
				if world_debug_drawer != null:
					world_debug_drawer.visible = debug_world_visible
					world_debug_drawer.queue_redraw()
			KEY_F3:
				_regenerate_world(false)
			KEY_F4:
				_regenerate_world(true)
			KEY_F5:
				simulation_enabled = not simulation_enabled
				_activity_dirty = true

func _update_debug_ui() -> void:
	if debug_overlay == null or not debug_overlay.visible or not debug_overlay.has_method("set_debug_snapshot"):
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	debug_overlay.call("set_debug_snapshot", _build_debug_snapshot(center))

func _build_debug_snapshot(center: Vector2i) -> Dictionary:
	var current_chunk: PieceChunkData = loaded_chunks.get(center, null) as PieceChunkData
	if seam_debug_dirty:
		cached_seam_debug = ChunkSeamValidator.validate_loaded_chunks(loaded_chunks)
		seam_debug_dirty = false
	var seam_debug: Dictionary = cached_seam_debug
	var special_info: String = ""
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(center):
		var placement: SpecialChunkPlacement = special_chunk_planner.get_chunk_at(center)
		if placement != null and placement.chunk_def != null:
			special_info = "%s @ %s" % [str(placement.chunk_def.id), str(placement.origin_chunk)]
	elif world_structure != null:
		var special_node: WorldStructureNode = world_structure.get_node(center)
		if special_node != null and special_node.special_chunk_id != &"":
			if special_node.has_tag(&"special_chunk_gateway"):
				special_info = "gateway %s via %s" % [str(special_node.special_chunk_id), str(special_node.special_chunk_gateway_side)]
			else:
				special_info = "near %s" % str(special_node.special_chunk_id)
	var chunk_type_text: String = "unknown"
	if current_chunk != null:
		chunk_type_text = BiomeMap.chunk_type_name(current_chunk.chunk_type)
	elif special_info != "":
		chunk_type_text = "special"
	return {
		"seed": world_seed,
		"runtime_profile": runtime_profile.display_name if runtime_profile != null else "None",
		"center_chunk": center,
		"loaded_count": loaded_chunks.size(),
		"pending_count": pending_chunks.size(),
		"worker_queue": chunk_worker.queued_count() if chunk_worker != null else 0,
		"worker_results": chunk_worker.result_count() if chunk_worker != null else 0,
		"special_pending": special_chunk_manager.queued_count() if special_chunk_manager != null else 0,
		"special_worker_queue": special_chunk_manager.worker_queue_count() if special_chunk_manager != null else 0,
		"threaded_chunks": use_threaded_chunk_generation and chunk_worker != null,
		"threaded_specials": use_threaded_special_generation and special_chunk_manager != null and special_chunk_manager.image_worker != null,
		"last_chunk_ms": last_chunk_generation_ms,
		"last_upload_count": last_chunk_upload_count,
		"pipeline_ms": float(_last_pipeline_usec) / 1000.0,
		"pipeline_budget_ms": streaming_pipeline_budget_ms,
		"ready_attach_queue": ready_chunk_queue.size(),
		"warmup_completed": _last_warmup_count,
		"texture_activations": _last_activation_count,
		"collision_shapes_built": _last_collision_shape_count,
		"simulation_ticks": _last_simulation_tick_count,
		"simulation_hz": simulation_hz,
		"background_simulation_hz": background_simulation_hz,
		"simulation_repaint_hz": simulation_repaint_hz,
		"load_radius": load_radius,
		"visual_downscale": visual_texture_downscale_factor,
		"renderer_pool": chunk_renderer_pool.size(),
		"renderer": "PixelCanvas threaded" if use_threaded_chunk_generation and chunk_worker != null else "PixelCanvas sync",
		"simulation_enabled": simulation_enabled,
		"simulation_radius": simulation_radius,
		"special_pixel_canvases": special_chunk_manager.loaded_canvas_count() if special_chunk_manager != null else 0,
		"current_canvas_mode": _canvas_for_chunk(center).upload_mode_name() if _canvas_for_chunk(center) != null else "not attached",
		"unit_size": UNIT_SIZE,
		"units_per_chunk": UNITS_PER_CHUNK,
		"biome": current_chunk.biome_id if current_chunk != null else biome_map_name(center),
		"chunk_type": chunk_type_text,
		"open_sides": current_chunk.open_side_count if current_chunk != null else 0,
		"top_profile": _profile_to_string(current_chunk.top_profile) if current_chunk != null else "SSSS",
		"right_profile": _profile_to_string(current_chunk.right_profile) if current_chunk != null else "SSSS",
		"bottom_profile": _profile_to_string(current_chunk.bottom_profile) if current_chunk != null else "SSSS",
		"left_profile": _profile_to_string(current_chunk.left_profile) if current_chunk != null else "SSSS",
		"actual_top_profile": _profile_to_string(current_chunk.actual_top_profile) if current_chunk != null else "SSSS",
		"actual_right_profile": _profile_to_string(current_chunk.actual_right_profile) if current_chunk != null else "SSSS",
		"actual_bottom_profile": _profile_to_string(current_chunk.actual_bottom_profile) if current_chunk != null else "SSSS",
		"actual_left_profile": _profile_to_string(current_chunk.actual_left_profile) if current_chunk != null else "SSSS",
		"seam_repairs": current_chunk.seam_repair_count if current_chunk != null else 0,
		"seam_expected_broken": int(seam_debug.get("expected_broken", 0)),
		"seam_neighbor_broken": int(seam_debug.get("neighbor_broken", 0)),
		"seam_neighbor_exact": int(seam_debug.get("neighbor_exact", 0)),
		"seam_neighbor_compatible": int(seam_debug.get("neighbor_compatible", 0)),
		"exact_matches": _loaded_regular_piece_count(),
		"compatible_matches": _loaded_open_socket_count(),
		"fallback_count": _loaded_glue_count(),
		"air_tiles": _loaded_air_unit_count(),
		"air_pockets": _loaded_piece_count(),
		"chamber_carve_air": _loaded_special_piece_count(),
		"chamber_carve_open": _loaded_chamber_piece_count(),
		"connectivity_path_tiles": _loaded_open_socket_count(),
		"connected_open_sides": current_chunk.connected_open_sides if current_chunk != null else 0,
		"current_chamber": _current_chamber_debug(current_chunk),
		"connectivity_adjusted": _loaded_connectivity_adjusted_count(),
		"special_info": special_info,
		"structure_tags": current_chunk.structure_tag_string() if current_chunk != null else (world_structure.tag_string_for(center) if world_structure != null else "fallback"),
		"structure_source": current_chunk.structure_source if current_chunk != null else ("structure_v1" if world_structure != null and world_structure.has_node(center) else "fallback"),
		"intended_connections": current_chunk.intended_connection_count if current_chunk != null else 0,
		"piece_count": current_chunk.piece_count if current_chunk != null else 0,
		"glue_count": current_chunk.used_glue_count if current_chunk != null else 0,
	}

func biome_map_name(coord: Vector2i) -> StringName:
	# Avoid touching the background worker's generator/biome map from the main
	# thread. This lightweight temporary map only performs read-only lookups for HUD
	# fallback text when the current chunk has not arrived yet.
	if active_config == null:
		return &"unknown"
	var map: BiomeMap = BiomeMap.new(world_seed, active_config)
	map.world_structure = world_structure
	map.special_chunk_planner = special_chunk_planner
	return map.get_biome(coord)

func _regenerate_world(advance_seed: bool) -> void:
	_stop_workers()
	if advance_seed:
		world_seed += 1
		if active_config != null:
			active_config.world_seed = world_seed
	for coord: Vector2i in chunk_renderers.keys():
		var renderer: Node = chunk_renderers.get(coord, null) as Node
		if renderer != null:
			renderer.queue_free()
	for pooled: PieceChunkRenderer in chunk_renderer_pool:
		if pooled != null and is_instance_valid(pooled):
			pooled.queue_free()
	for deferred: PieceChunkRenderer in deferred_renderer_recycle_queue:
		if deferred != null and is_instance_valid(deferred):
			deferred.queue_free()
	chunk_renderer_pool.clear()
	deferred_renderer_recycle_queue.clear()
	loaded_chunks.clear()
	chunk_renderers.clear()
	pending_chunks.clear()
	wanted_chunks.clear()
	ready_chunk_queue.clear()
	_last_stream_center = Vector2i(2147483647, 2147483647)
	_activity_dirty = true
	_simulation_round_robin_cursor = 0
	_last_prewarm_direction = Vector2i.ZERO
	if special_chunks_parent != null:
		for child: Node in special_chunks_parent.get_children():
			child.queue_free()
	runtime_profile = _resolve_runtime_profile()
	_apply_runtime_profile()
	_apply_runtime_profile_to_debug_nodes()
	if library != null:
		library.prepare()
	_build_world_runtime()
	seam_debug_dirty = true
	debug_update_accum = debug_update_interval
	_border_exchange_accumulator = 0.0
	_border_exchange_phase = 0
	_update_loaded_chunks(true)

func world_pos_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK_SIZE)), floori(pos.y / float(CHUNK_SIZE)))

func _update_loaded_chunks(force: bool) -> void:
	if generator == null:
		return
	var center: Vector2i = world_pos_to_chunk(player.global_position if player != null else Vector2.ZERO)
	current_player_chunk = center
	if not force and center == _last_stream_center:
		return
	_last_stream_center = center
	_activity_dirty = true
	var needed: Dictionary = {}
	var normal_candidates: Array[Vector2i] = []
	for y: int in range(center.y - load_radius, center.y + load_radius + 1):
		for x: int in range(center.x - load_radius, center.x + load_radius + 1):
			var coord: Vector2i = Vector2i(x, y)
			needed[coord] = true
			if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
				if not loaded_chunks.has(coord):
					loaded_chunks[coord] = null
				continue
			if force or (not loaded_chunks.has(coord) and not pending_chunks.has(coord)):
				normal_candidates.append(coord)
	normal_candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center)
	)
	for coord: Vector2i in normal_candidates:
		if not loaded_chunks.has(coord) and not pending_chunks.has(coord):
			_request_chunk(coord)
	wanted_chunks = needed
	_prune_ready_chunk_queue(needed)
	if chunk_worker != null:
		chunk_worker.prune_requests(needed)
		chunk_worker.prioritize_requests(center)
	if special_chunk_manager != null:
		special_chunk_manager.update_loaded_chunks(needed)
	var existing: Array = loaded_chunks.keys()
	for coord_to_check: Vector2i in existing:
		if not needed.has(coord_to_check):
			_unload_chunk(coord_to_check)
	var pending_existing: Array = pending_chunks.keys()
	for pending_coord: Vector2i in pending_existing:
		if not needed.has(pending_coord):
			pending_chunks.erase(pending_coord)

func _prune_ready_chunk_queue(allowed_coords: Dictionary) -> void:
	if ready_chunk_queue.is_empty():
		return
	var kept: Array[PieceChunkData] = []
	for data: PieceChunkData in ready_chunk_queue:
		if data != null and allowed_coords.has(data.coord):
			kept.append(data)
	ready_chunk_queue = kept

func _request_chunk(coord: Vector2i) -> void:
	if loaded_chunks.has(coord) or pending_chunks.has(coord):
		return
	if use_threaded_chunk_generation and chunk_worker != null:
		pending_chunks[coord] = true
		chunk_worker.enqueue(coord)
	else:
		_load_chunk_sync(coord)

func _collect_chunk_results(collect_budget: int) -> int:
	if chunk_worker == null or collect_budget <= 0:
		return 0
	var collected: int = 0
	var results: Array[Dictionary] = chunk_worker.collect_results(collect_budget)
	for result: Dictionary in results:
		var coord: Vector2i = result.get("coord", Vector2i.ZERO)
		pending_chunks.erase(coord)
		last_chunk_generation_ms = int(result.get("elapsed_ms", 0))
		var data: PieceChunkData = result.get("data", null) as PieceChunkData
		if data == null:
			push_warning("WorldManager: async chunk %s failed: %s" % [str(coord), str(result.get("error", "unknown"))])
			continue
		if not _chunk_is_currently_needed(coord):
			continue
		ready_chunk_queue.append(data)
		collected += 1
	return collected

func _attach_ready_chunks(max_count: int, deadline_usec: int) -> int:
	var attached: int = 0
	while attached < maxi(1, max_count) and not ready_chunk_queue.is_empty():
		if Time.get_ticks_usec() >= deadline_usec:
			break
		var data: PieceChunkData = ready_chunk_queue.pop_front()
		if data == null or not _chunk_is_currently_needed(data.coord) or loaded_chunks.has(data.coord):
			continue
		_attach_chunk_renderer(data)
		attached += 1
	return attached

func _chunk_is_currently_needed(coord: Vector2i) -> bool:
	if not wanted_chunks.has(coord):
		return false
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		return false
	return true

func _load_chunk_sync(coord: Vector2i) -> void:
	if loaded_chunks.has(coord):
		return
	if special_chunk_planner != null and special_chunk_planner.is_chunk_inside_special_chunk(coord):
		loaded_chunks[coord] = null
		return
	var data: PieceChunkData = generator.generate_chunk(coord, false)
	_attach_chunk_renderer(data)

func _obtain_chunk_renderer() -> PieceChunkRenderer:
	var renderer: PieceChunkRenderer = null
	while not chunk_renderer_pool.is_empty() and renderer == null:
		renderer = chunk_renderer_pool.pop_back() as PieceChunkRenderer
		if renderer == null or not is_instance_valid(renderer):
			renderer = null
	if renderer == null:
		renderer = PieceChunkRenderer.new()
		chunk_renderers_parent.add_child(renderer)
	renderer.visible = true
	return renderer

func _attach_chunk_renderer(data: PieceChunkData) -> void:
	if data == null or loaded_chunks.has(data.coord):
		return
	var renderer: PieceChunkRenderer = _obtain_chunk_renderer()
	var active: bool = simulation_enabled and _chunk_distance(data.coord, current_player_chunk) <= simulation_radius
	renderer.setup(
		data,
		material_palette,
		active,
		generate_static_collision,
		simulation_iterations,
		simulation_hz if data.coord == current_player_chunk else background_simulation_hz,
		minf(simulation_repaint_hz, simulation_hz if data.coord == current_player_chunk else background_simulation_hz),
		maximum_collision_triangles,
		collision_cell_size,
		not keep_cpu_visual_images
	)
	chunk_renderers[data.coord] = renderer
	loaded_chunks[data.coord] = data
	_activity_dirty = true
	seam_debug_dirty = true
	if world_debug_drawer != null and world_debug_drawer.visible:
		world_debug_drawer.queue_redraw()

func _unload_chunk(coord: Vector2i) -> void:
	var renderer: PieceChunkRenderer = chunk_renderers.get(coord, null) as PieceChunkRenderer
	if renderer != null:
		renderer.visible = false
		deferred_renderer_recycle_queue.append(renderer)
	chunk_renderers.erase(coord)
	loaded_chunks.erase(coord)
	pending_chunks.erase(coord)
	_activity_dirty = true
	seam_debug_dirty = true
	if world_debug_drawer != null and world_debug_drawer.visible:
		world_debug_drawer.queue_redraw()

func _update_simulation_activity() -> void:
	var predictive_coords: Dictionary = _predictive_prewarm_coords()
	for coord: Vector2i in chunk_renderers.keys():
		var renderer: PieceChunkRenderer = chunk_renderers.get(coord, null) as PieceChunkRenderer
		if renderer != null:
			var distance: int = _chunk_distance(coord, current_player_chunk)
			var active_nearby: bool = simulation_enabled and distance <= simulation_radius
			var target_hz: float = simulation_hz if distance == 0 else background_simulation_hz
			renderer.set_simulation_timing(target_hz, minf(simulation_repaint_hz, target_hz))
			renderer.set_simulation_active(active_nearby)
			renderer.set_warmup_requested(active_nearby or predictive_coords.has(coord))
			renderer.set_collision_active(generate_static_collision and _chunk_distance(coord, current_player_chunk) <= collision_radius)
	if special_chunk_manager != null:
		special_chunk_manager.set_simulation_activity(
			current_player_chunk, simulation_radius, simulation_enabled,
			simulation_hz, background_simulation_hz, simulation_repaint_hz
		)
		special_chunk_manager.set_warmup_activity(
			current_player_chunk, simulation_radius, simulation_enabled, predictive_coords
		)
		special_chunk_manager.set_collision_activity(current_player_chunk, collision_radius, generate_static_collision)

func _current_prewarm_direction() -> Vector2i:
	if predictive_prewarm_chunks <= 0 or player == null:
		return Vector2i.ZERO
	var body: CharacterBody2D = player as CharacterBody2D
	if body == null:
		return Vector2i.ZERO
	var velocity: Vector2 = body.velocity
	if velocity.length_squared() < 400.0:
		return Vector2i.ZERO
	var direction := Vector2i.ZERO
	if velocity.x > 0.0:
		direction.x = 1
	elif velocity.x < 0.0:
		direction.x = -1
	if velocity.y > 0.0:
		direction.y = 1
	elif velocity.y < 0.0:
		direction.y = -1
	return direction

func _predictive_prewarm_coords() -> Dictionary:
	var result: Dictionary = {}
	if not simulation_enabled or predictive_prewarm_chunks <= 0:
		return result
	var direction: Vector2i = _last_prewarm_direction
	if direction == Vector2i.ZERO:
		return result
	var candidates: Array[Vector2i] = []
	candidates.append(current_player_chunk + direction)
	if predictive_prewarm_chunks > 1:
		if direction.x != 0:
			candidates.append(current_player_chunk + Vector2i(direction.x, 0))
		if direction.y != 0:
			candidates.append(current_player_chunk + Vector2i(0, direction.y))
	for coord: Vector2i in candidates:
		if result.size() >= predictive_prewarm_chunks:
			break
		if wanted_chunks.has(coord) and _canvas_for_chunk(coord) != null:
			result[coord] = true
	return result

func _process_warmup_budget() -> void:
	_last_warmup_count = 0
	if not simulation_enabled or Time.get_ticks_usec() >= _pipeline_deadline_usec:
		return
	var deadline_usec: int = mini(
		_pipeline_deadline_usec, Time.get_ticks_usec() + int(simulation_warmup_budget_ms * 1000.0)
	)
	for coord: Vector2i in _ordered_canvas_coords(load_radius):
		var canvas: PixelChunkCanvas = _canvas_for_chunk(coord)
		if canvas == null or not canvas.is_warmup_requested():
			continue
		if not canvas.needs_initialization() and not canvas.is_initializing():
			continue
		if canvas.needs_initialization():
			canvas.begin_initialization()
		if canvas.advance_initialization(simulation_warmup_pixels_per_slice, deadline_usec):
			_last_warmup_count += 1
		if Time.get_ticks_usec() >= deadline_usec:
			break

func _process_texture_activation_budget() -> void:
	_last_activation_count = 0
	if not simulation_enabled or Time.get_ticks_usec() >= _pipeline_deadline_usec:
		return
	var deadline_usec: int = mini(
		_pipeline_deadline_usec, Time.get_ticks_usec() + int(simulation_texture_activation_budget_ms * 1000.0)
	)
	for coord: Vector2i in _ordered_canvas_coords(load_radius):
		if _last_activation_count >= maxi(1, simulation_texture_activations_per_frame):
			break
		var canvas: PixelChunkCanvas = _canvas_for_chunk(coord)
		if canvas == null or not canvas.needs_texture_activation():
			continue
		if canvas.activate_simulation_texture():
			_last_activation_count += 1
		if Time.get_ticks_usec() >= deadline_usec:
			break

func _process_collision_budget() -> void:
	_last_collision_shape_count = 0
	if not generate_static_collision or Time.get_ticks_usec() >= _pipeline_deadline_usec:
		return
	var deadline_usec: int = mini(
		_pipeline_deadline_usec, Time.get_ticks_usec() + int(collision_build_budget_ms * 1000.0)
	)
	for coord: Vector2i in _ordered_canvas_coords(collision_radius):
		var canvas: PixelChunkCanvas = _canvas_for_chunk(coord)
		if canvas == null or not canvas.needs_collision_work():
			continue
		canvas.advance_collision(collision_shapes_per_slice, deadline_usec)
		_last_collision_shape_count += 1
		if Time.get_ticks_usec() >= deadline_usec:
			break

func _process_simulation_budget() -> void:
	_last_simulation_tick_count = 0
	if not simulation_enabled or Time.get_ticks_usec() >= _pipeline_deadline_usec:
		return
	var coords: Array[Vector2i] = _ordered_canvas_coords(simulation_radius)
	if coords.is_empty():
		_simulation_round_robin_cursor = 0
		return
	var deadline_usec: int = mini(
		_pipeline_deadline_usec, Time.get_ticks_usec() + int(simulation_update_budget_ms * 1000.0)
	)
	# The player's current chunk is latency-sensitive and must not be diluted by the
	# neighbor round-robin. It gets first chance every rendered frame.
	var foreground: PixelChunkCanvas = _canvas_for_chunk(current_player_chunk)
	var now_usec: int = Time.get_ticks_usec()
	if foreground != null and foreground.simulation_due(now_usec):
		foreground.run_simulation_tick(now_usec)
		_last_simulation_tick_count += 1
	if Time.get_ticks_usec() >= deadline_usec:
		return
	var background_coords: Array[Vector2i] = []
	for coord: Vector2i in coords:
		if coord != current_player_chunk:
			background_coords.append(coord)
	if background_coords.is_empty():
		_simulation_round_robin_cursor = 0
		return
	_simulation_round_robin_cursor %= background_coords.size()
	var scanned: int = 0
	while scanned < background_coords.size():
		var index: int = (_simulation_round_robin_cursor + scanned) % background_coords.size()
		var canvas: PixelChunkCanvas = _canvas_for_chunk(background_coords[index])
		now_usec = Time.get_ticks_usec()
		if canvas != null and canvas.simulation_due(now_usec):
			canvas.run_simulation_tick(now_usec)
			_last_simulation_tick_count += 1
			_simulation_round_robin_cursor = (index + 1) % background_coords.size()
			if Time.get_ticks_usec() >= deadline_usec:
				break
		scanned += 1

func _ordered_canvas_coords(max_radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord_value in wanted_chunks.keys():
		var coord: Vector2i = coord_value
		if _chunk_distance(coord, current_player_chunk) > max_radius:
			continue
		if _canvas_for_chunk(coord) != null:
			coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = a.distance_squared_to(current_player_chunk)
		var db: int = b.distance_squared_to(current_player_chunk)
		if da == db:
			return a.y < b.y if a.y != b.y else a.x < b.x
		return da < db
	)
	return coords

func _process_recycle_budget() -> void:
	if Time.get_ticks_usec() >= _pipeline_deadline_usec:
		return
	var deadline_usec: int = mini(
		_pipeline_deadline_usec, Time.get_ticks_usec() + int(recycle_budget_ms * 1000.0)
	)
	var recycled: int = 0
	while not deferred_renderer_recycle_queue.is_empty():
		if recycled > 0 and Time.get_ticks_usec() >= deadline_usec:
			break
		var renderer: PieceChunkRenderer = deferred_renderer_recycle_queue.pop_front()
		if renderer == null or not is_instance_valid(renderer):
			continue
		if chunk_renderer_pool.size() < chunk_renderer_pool_limit:
			renderer.recycle_for_pool()
			chunk_renderer_pool.append(renderer)
		else:
			renderer.queue_free()
		recycled += 1
	if special_chunk_manager != null and Time.get_ticks_usec() < deadline_usec:
		special_chunk_manager.process_recycle(1)

func _canvas_for_chunk(coord: Vector2i) -> PixelChunkCanvas:
	var renderer: PieceChunkRenderer = chunk_renderers.get(coord, null) as PieceChunkRenderer
	if renderer != null:
		return renderer.pixel_canvas
	if special_chunk_manager != null:
		return special_chunk_manager.get_chunk_canvas(coord)
	return null

func is_motion_collision_ready(
	world_position: Vector2,
	motion: Vector2,
	half_extents: Vector2
) -> bool:
	## CharacterBody2D can only collide with shapes that already exist in the physics
	## server. Streaming chunks are therefore treated as temporarily blocked until a
	## complete collision snapshot has been atomically committed.
	if not generate_static_collision or motion.is_zero_approx():
		return true

	var end_position: Vector2 = world_position + motion
	var margin: Vector2 = Vector2.ONE * 2.0
	var min_position := Vector2(
		minf(world_position.x, end_position.x),
		minf(world_position.y, end_position.y)
	) - half_extents - margin
	var max_position := Vector2(
		maxf(world_position.x, end_position.x),
		maxf(world_position.y, end_position.y)
	) + half_extents + margin
	var min_chunk: Vector2i = world_pos_to_chunk(min_position)
	var max_chunk: Vector2i = world_pos_to_chunk(max_position)

	for chunk_y: int in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x: int in range(min_chunk.x, max_chunk.x + 1):
			var coord := Vector2i(chunk_x, chunk_y)
			var canvas: PixelChunkCanvas = _canvas_for_chunk(coord)
			if canvas == null:
				return false
			# The swept player bounds may touch a neighboring chunk before the player's
			# center changes chunk. Activate that complete snapshot preemptively.
			canvas.set_collision_active(true)
			if not canvas.has_committed_collision_snapshot():
				return false
	return true

func _exchange_chunk_borders() -> void:
	var seams: Array[Dictionary] = []
	for coord_value in wanted_chunks.keys():
		var coord: Vector2i = coord_value
		var current: PixelChunkCanvas = _canvas_for_chunk(coord)
		if current == null or not current.is_simulation_active():
			continue
		var below: PixelChunkCanvas = _canvas_for_chunk(coord + Vector2i.DOWN)
		if below != null and below.is_simulation_active():
			seams.append({"kind": 0, "coord": coord})
		var right: PixelChunkCanvas = _canvas_for_chunk(coord + Vector2i.RIGHT)
		if right != null and right.is_simulation_active():
			seams.append({"kind": 1, "coord": coord})
	if seams.is_empty():
		return
	seams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: Vector2i = a.get("coord", Vector2i.ZERO)
		var bc: Vector2i = b.get("coord", Vector2i.ZERO)
		if ac.y != bc.y:
			return ac.y < bc.y
		if ac.x != bc.x:
			return ac.x < bc.x
		return int(a.get("kind", 0)) < int(b.get("kind", 0))
	)
	var count: int = mini(border_seams_per_tick, seams.size())
	var start_index: int = _border_exchange_phase % seams.size()
	for offset: int in range(count):
		var seam: Dictionary = seams[(start_index + offset) % seams.size()]
		var coord: Vector2i = seam.get("coord", Vector2i.ZERO)
		var current: PixelChunkCanvas = _canvas_for_chunk(coord)
		if current == null:
			continue
		if int(seam.get("kind", 0)) == 0:
			var below: PixelChunkCanvas = _canvas_for_chunk(coord + Vector2i.DOWN)
			if below != null:
				_exchange_vertical_seam(current, below)
		else:
			var right: PixelChunkCanvas = _canvas_for_chunk(coord + Vector2i.RIGHT)
			if right != null:
				_exchange_horizontal_liquid_seam(current, right, coord)
	_border_exchange_phase = (start_index + count) % seams.size()

func _exchange_vertical_seam(top: PixelChunkCanvas, bottom: PixelChunkCanvas) -> void:
	var changed: bool = false
	var edge: int = CHUNK_SIZE - 1
	for x: int in range(CHUNK_SIZE):
		var top_id: int = top.get_cell(x, edge)
		var bottom_id: int = bottom.get_cell(x, 0)
		if bottom_id == 0 and _material_moves_down(top_id):
			top.set_cell(x, edge, 0)
			bottom.set_cell(x, 0, top_id)
			changed = true
		elif top_id == 0 and _material_moves_up(bottom_id):
			bottom.set_cell(x, 0, 0)
			top.set_cell(x, edge, bottom_id)
			changed = true
	if changed:
		top.request_repaint()
		bottom.request_repaint()

func _exchange_horizontal_liquid_seam(left: PixelChunkCanvas, right: PixelChunkCanvas, left_coord: Vector2i) -> void:
	var changed: bool = false
	var edge: int = CHUNK_SIZE - 1
	for y: int in range(CHUNK_SIZE):
		var prefer_right: bool = ((y + left_coord.x + left_coord.y + _border_exchange_phase) & 1) == 0
		var left_id: int = left.get_cell(edge, y)
		var right_id: int = right.get_cell(0, y)
		if prefer_right and right_id == 0 and _material_is_liquid(left_id):
			left.set_cell(edge, y, 0)
			right.set_cell(0, y, left_id)
			changed = true
		elif not prefer_right and left_id == 0 and _material_is_liquid(right_id):
			right.set_cell(0, y, 0)
			left.set_cell(edge, y, right_id)
			changed = true
	if changed:
		left.request_repaint()
		right.request_repaint()

func _material_moves_down(element_id: int) -> bool:
	if element_id == 0:
		return false
	var entry: MaterialEntry = material_palette.entry_for_element_id(element_id) if material_palette != null else null
	if entry == null:
		return false
	var state: int = entry.effective_state()
	return state == 0 or state == 2

func _material_moves_up(element_id: int) -> bool:
	if element_id == 0:
		return false
	var entry: MaterialEntry = material_palette.entry_for_element_id(element_id) if material_palette != null else null
	return entry != null and entry.effective_state() == 3

func _material_is_liquid(element_id: int) -> bool:
	if element_id == 0:
		return false
	var entry: MaterialEntry = material_palette.entry_for_element_id(element_id) if material_palette != null else null
	return entry != null and entry.effective_state() == 2

func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _loaded_air_unit_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.air_tile_count
	return total

func _loaded_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.piece_count
	return total

func _loaded_regular_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.regular_piece_count
	return total

func _loaded_glue_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.used_glue_count
	return total

func _loaded_open_socket_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null:
			total += chunk_data.compatible_match_tiles
	return total

func _loaded_special_piece_count() -> int:
	if special_chunk_manager == null:
		return 0
	return special_chunk_manager.loaded_chunks.size()

func _loaded_chamber_piece_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null and chunk_data.chunk_type == BiomeMap.ChunkType.CHAMBER:
			total += 1
	return total

func _current_chamber_debug(chunk_data: PieceChunkData) -> String:
	if chunk_data == null or chunk_data.chamber_id == &"":
		return ""
	return "%s %s@%s pieces %d/glue %d" % [
		str(chunk_data.chamber_id),
		str(chunk_data.chamber_size),
		str(chunk_data.chamber_origin),
		chunk_data.piece_count,
		chunk_data.used_glue_count,
	]

func _loaded_connectivity_adjusted_count() -> int:
	var total: int = 0
	for item in loaded_chunks.values():
		var chunk_data: PieceChunkData = item as PieceChunkData
		if chunk_data != null and chunk_data.connectivity_adjusted:
			total += 1
	return total

func _profile_to_string(profile: Array[PieceSocket.Socket]) -> String:
	var result: String = ""
	for socket: PieceSocket.Socket in profile:
		result += PieceSocket.to_debug_char(PieceSocket.from_value(socket))
	return result
