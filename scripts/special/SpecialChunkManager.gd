class_name SpecialChunkManager
extends RefCounted

## Streams special structures and splits every structure into one PixelChunkCanvas per
## occupied world chunk. CPU image construction may stay on a background worker.
var planner: SpecialChunkPlanner
var parent_node: Node2D
var material_palette: MaterialPalette
var loaded_chunks: Dictionary = {}
var pending_chunks: Dictionary = {}
var needed_special_chunks: Dictionary = {}
var chunk_canvas_by_coord: Dictionary = {}
var use_threaded_generation: bool = true
var image_worker: SpecialChunkImageWorker
var last_result_ms: int = 0
var renderer_pool: Array[SpecialPieceRenderer] = []
var renderer_pool_limit: int = 32
var simulation_enabled: bool = true
var generate_static_collision: bool = true
var simulation_iterations: int = 1
var simulation_hz: float = 60.0
var simulation_repaint_hz: float = 60.0
var maximum_collision_triangles: int = 6000
var collision_cell_size: int = 8
var preview_downscale_factor: int = 1
var keep_cpu_visual_images: bool = false
var deferred_recycle_queue: Array[SpecialPieceRenderer] = []
var worker_yield_ms: int = 0

func _init(
	p_planner: SpecialChunkPlanner,
	p_parent_node: Node2D,
	p_material_palette: MaterialPalette,
	p_use_threaded_generation: bool = true,
	p_renderer_pool_limit: int = 32,
	p_simulation_enabled: bool = true,
	p_generate_static_collision: bool = true,
	p_simulation_iterations: int = 1,
	p_simulation_hz: float = 60.0,
	p_simulation_repaint_hz: float = 60.0,
	p_maximum_collision_triangles: int = 6000,
	p_collision_cell_size: int = 8,
	p_preview_downscale_factor: int = 1,
	p_keep_cpu_visual_images: bool = false,
	p_worker_yield_ms: int = 0
) -> void:
	planner = p_planner
	parent_node = p_parent_node
	material_palette = p_material_palette
	use_threaded_generation = p_use_threaded_generation
	renderer_pool_limit = maxi(0, p_renderer_pool_limit)
	simulation_enabled = p_simulation_enabled
	generate_static_collision = p_generate_static_collision
	simulation_iterations = maxi(1, p_simulation_iterations)
	simulation_hz = maxf(1.0, p_simulation_hz)
	simulation_repaint_hz = maxf(1.0, p_simulation_repaint_hz)
	maximum_collision_triangles = maxi(0, p_maximum_collision_triangles)
	collision_cell_size = maxi(1, p_collision_cell_size)
	preview_downscale_factor = maxi(1, p_preview_downscale_factor)
	keep_cpu_visual_images = p_keep_cpu_visual_images
	worker_yield_ms = maxi(0, p_worker_yield_ms)
	if use_threaded_generation:
		image_worker = SpecialChunkImageWorker.new()
		if not image_worker.start(
			material_palette, collision_cell_size, preview_downscale_factor,
			generate_static_collision, 2, worker_yield_ms
		):
			push_warning("SpecialChunkManager: special image worker failed to start; falling back to synchronous rendering.")
			image_worker = null
			use_threaded_generation = false

func stop() -> void:
	if image_worker != null:
		image_worker.stop()
		image_worker = null
	pending_chunks.clear()
	needed_special_chunks.clear()
	chunk_canvas_by_coord.clear()
	for item in renderer_pool:
		var renderer: Node = item as Node
		if renderer != null and is_instance_valid(renderer):
			renderer.queue_free()
	for deferred: SpecialPieceRenderer in deferred_recycle_queue:
		if deferred != null and is_instance_valid(deferred):
			deferred.queue_free()
	renderer_pool.clear()
	deferred_recycle_queue.clear()

func update_loaded_chunks(needed_chunks: Dictionary) -> void:
	if planner == null or parent_node == null:
		return
	needed_special_chunks.clear()
	for chunk_coord: Vector2i in needed_chunks.keys():
		var placement: SpecialChunkPlacement = planner.get_chunk_at(chunk_coord)
		if placement != null:
			needed_special_chunks[placement.id] = placement
	for key in needed_special_chunks.keys():
		var chunk_id: StringName = StringName(str(key))
		if loaded_chunks.has(chunk_id) or pending_chunks.has(chunk_id):
			continue
		var placement: SpecialChunkPlacement = needed_special_chunks[chunk_id] as SpecialChunkPlacement
		if use_threaded_generation and image_worker != null:
			pending_chunks[chunk_id] = placement
			image_worker.enqueue(placement)
		else:
			_load_chunk_sync(placement)
	var existing: Array = loaded_chunks.keys()
	for key in existing:
		var existing_id: StringName = StringName(str(key))
		if not needed_special_chunks.has(existing_id):
			_unload_chunk(existing_id)
	var pending_existing: Array = pending_chunks.keys()
	for key in pending_existing:
		var pending_id: StringName = StringName(str(key))
		if not needed_special_chunks.has(pending_id):
			pending_chunks.erase(pending_id)
	if image_worker != null:
		image_worker.prune_requests(needed_special_chunks)

func process_ready(upload_budget: int = 1) -> int:
	if image_worker == null or upload_budget <= 0:
		return 0
	var attached: int = 0
	var results: Array[Dictionary] = image_worker.collect_results(upload_budget)
	for result: Dictionary in results:
		var id: StringName = StringName(str(result.get("id", &"")))
		if not pending_chunks.has(id) or not needed_special_chunks.has(id):
			pending_chunks.erase(id)
			continue
		var placement: SpecialChunkPlacement = result.get("placement", null) as SpecialChunkPlacement
		var chunks: Array[PieceChunkData] = []
		var chunk_variant: Variant = result.get("chunks", [])
		if chunk_variant is Array:
			for item in chunk_variant:
				var data: PieceChunkData = item as PieceChunkData
				if data != null:
					chunks.append(data)
		last_result_ms = int(result.get("elapsed_ms", 0))
		if placement != null and not chunks.is_empty() and parent_node != null:
			_load_chunk_from_data(placement, chunks)
			attached += 1
		pending_chunks.erase(id)
	return attached

func get_chunk_canvas(coord: Vector2i) -> PixelChunkCanvas:
	return chunk_canvas_by_coord.get(coord, null) as PixelChunkCanvas

func set_simulation_activity(
	center: Vector2i, radius: int, enabled: bool,
	foreground_hz: float, background_hz: float, repaint_hz: float
) -> void:
	for coord: Vector2i in chunk_canvas_by_coord.keys():
		var canvas: PixelChunkCanvas = chunk_canvas_by_coord.get(coord, null) as PixelChunkCanvas
		if canvas != null:
			var distance: int = _chunk_distance(coord, center)
			var active: bool = enabled and distance <= radius
			var target_hz: float = foreground_hz if distance == 0 else background_hz
			canvas.set_simulation_timing(target_hz, minf(repaint_hz, target_hz))
			canvas.set_simulation_active(active)

func set_warmup_activity(center: Vector2i, radius: int, enabled: bool, predictive_coords: Dictionary) -> void:
	for coord: Vector2i in chunk_canvas_by_coord.keys():
		var canvas: PixelChunkCanvas = chunk_canvas_by_coord.get(coord, null) as PixelChunkCanvas
		if canvas != null:
			var active_nearby: bool = enabled and _chunk_distance(coord, center) <= radius
			canvas.set_warmup_requested(active_nearby or predictive_coords.has(coord))

func set_collision_activity(center: Vector2i, radius: int, enabled: bool) -> void:
	for coord: Vector2i in chunk_canvas_by_coord.keys():
		var canvas: PixelChunkCanvas = chunk_canvas_by_coord.get(coord, null) as PixelChunkCanvas
		if canvas != null:
			canvas.set_collision_active(enabled and _chunk_distance(coord, center) <= radius)

func loaded_canvas_count() -> int:
	return chunk_canvas_by_coord.size()

func _load_chunk_sync(placement: SpecialChunkPlacement) -> void:
	var instance: SpecialPieceRenderer = _obtain_renderer()
	instance.name = str(placement.id)
	instance.setup(
		placement,
		material_palette,
		simulation_enabled,
		generate_static_collision,
		simulation_iterations,
		simulation_hz,
		simulation_repaint_hz,
		maximum_collision_triangles,
		collision_cell_size,
		preview_downscale_factor,
		keep_cpu_visual_images
	)
	loaded_chunks[placement.id] = instance
	_register_renderer(instance)

func _load_chunk_from_data(placement: SpecialChunkPlacement, chunks: Array[PieceChunkData]) -> void:
	var instance: SpecialPieceRenderer = _obtain_renderer()
	instance.name = str(placement.id)
	instance.setup_with_chunk_data(
		placement,
		chunks,
		material_palette,
		simulation_enabled,
		generate_static_collision,
		simulation_iterations,
		simulation_hz,
		simulation_repaint_hz,
		maximum_collision_triangles,
		collision_cell_size,
		keep_cpu_visual_images
	)
	loaded_chunks[placement.id] = instance
	_register_renderer(instance)

func _obtain_renderer() -> SpecialPieceRenderer:
	var instance: SpecialPieceRenderer = null
	while not renderer_pool.is_empty() and instance == null:
		instance = renderer_pool.pop_back() as SpecialPieceRenderer
		if instance == null or not is_instance_valid(instance):
			instance = null
	if instance == null:
		instance = SpecialPieceRenderer.new()
		parent_node.add_child(instance)
	else:
		instance.visible = true
	return instance

func _register_renderer(instance: SpecialPieceRenderer) -> void:
	if instance == null:
		return
	for coord: Vector2i in instance.chunk_canvases.keys():
		chunk_canvas_by_coord[coord] = instance.chunk_canvases[coord]

func _unregister_renderer(instance: SpecialPieceRenderer) -> void:
	if instance == null:
		return
	for coord: Vector2i in instance.chunk_canvases.keys():
		chunk_canvas_by_coord.erase(coord)

func _unload_chunk(chunk_id: StringName) -> void:
	var instance: SpecialPieceRenderer = loaded_chunks.get(chunk_id, null) as SpecialPieceRenderer
	if instance != null:
		_unregister_renderer(instance)
		instance.visible = false
		deferred_recycle_queue.append(instance)
	loaded_chunks.erase(chunk_id)

func process_recycle(max_count: int = 1) -> int:
	var recycled: int = 0
	while recycled < maxi(1, max_count) and not deferred_recycle_queue.is_empty():
		var instance: SpecialPieceRenderer = deferred_recycle_queue.pop_front()
		if instance == null or not is_instance_valid(instance):
			continue
		if renderer_pool.size() < renderer_pool_limit:
			instance.recycle_for_pool()
			renderer_pool.append(instance)
		else:
			instance.queue_free()
		recycled += 1
	return recycled

func queued_count() -> int:
	return pending_chunks.size()

func worker_queue_count() -> int:
	return image_worker.queued_count() if image_worker != null else 0

func worker_result_count() -> int:
	return image_worker.result_count() if image_worker != null else 0

func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
