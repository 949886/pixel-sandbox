class_name SpecialChunkImageWorker
extends RefCounted

# Background worker for special structure composition, per-chunk cropping, material
# conversion, preview downscaling and collision greedy meshing.
var thread: Thread
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var stop_requested: bool = false
var running: bool = false
var requests: Array[SpecialChunkPlacement] = []
var request_lookup: Dictionary = {}
var results: Array[Dictionary] = []
var completed_count: int = 0
var material_palette: MaterialPalette
var collision_cell_size: int = 1
var preview_downscale_factor: int = 1
var bake_collision_data: bool = true
var max_result_backlog: int = 2
var inter_job_yield_ms: int = 0

func start(
	palette: MaterialPalette,
	p_collision_cell_size: int = 1,
	p_preview_downscale_factor: int = 1,
	p_bake_collision_data: bool = true,
	p_max_result_backlog: int = 2,
	p_inter_job_yield_ms: int = 0
) -> bool:
	stop()
	material_palette = palette
	collision_cell_size = maxi(1, p_collision_cell_size)
	preview_downscale_factor = maxi(1, p_preview_downscale_factor)
	bake_collision_data = p_bake_collision_data
	max_result_backlog = maxi(1, p_max_result_backlog)
	inter_job_yield_ms = maxi(0, p_inter_job_yield_ms)
	stop_requested = false
	requests.clear()
	request_lookup.clear()
	results.clear()
	completed_count = 0
	thread = Thread.new()
	var err: Error = thread.start(Callable(self, "_thread_loop"))
	running = err == OK
	if not running:
		thread = null
	return running

func stop() -> void:
	if thread == null:
		running = false
		return
	mutex.lock()
	stop_requested = true
	requests.clear()
	request_lookup.clear()
	mutex.unlock()
	semaphore.post()
	thread.wait_to_finish()
	thread = null
	running = false
	stop_requested = false

func enqueue(placement: SpecialChunkPlacement) -> bool:
	if not running or placement == null:
		return false
	var id: StringName = placement.id
	var should_post: bool = false
	mutex.lock()
	if not request_lookup.has(id):
		request_lookup[id] = true
		requests.append(placement)
		should_post = true
	mutex.unlock()
	if should_post:
		semaphore.post()
	return should_post

func prune_requests(allowed_ids: Dictionary) -> void:
	mutex.lock()
	var kept: Array[SpecialChunkPlacement] = []
	request_lookup.clear()
	for placement: SpecialChunkPlacement in requests:
		if placement != null and allowed_ids.has(placement.id):
			kept.append(placement)
			request_lookup[placement.id] = true
	requests = kept
	var kept_results: Array[Dictionary] = []
	for result: Dictionary in results:
		var result_id: StringName = StringName(str(result.get("id", &"")))
		if allowed_ids.has(result_id):
			kept_results.append(result)
	results = kept_results
	mutex.unlock()

func collect_results(max_results: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var should_wake: bool = false
	mutex.lock()
	var count: int = maxi(1, max_results)
	while count > 0 and not results.is_empty():
		out.append(results.pop_front())
		count -= 1
	should_wake = not requests.is_empty() and results.size() < max_result_backlog
	mutex.unlock()
	if should_wake:
		semaphore.post()
	return out

func queued_count() -> int:
	mutex.lock()
	var count: int = requests.size()
	mutex.unlock()
	return count

func result_count() -> int:
	mutex.lock()
	var count: int = results.size()
	mutex.unlock()
	return count

func clear_pending() -> void:
	mutex.lock()
	requests.clear()
	request_lookup.clear()
	results.clear()
	mutex.unlock()

func _thread_loop() -> void:
	while true:
		semaphore.wait()
		var placement: SpecialChunkPlacement = null
		var has_request: bool = false
		mutex.lock()
		if stop_requested:
			mutex.unlock()
			break
		if results.size() < max_result_backlog and not requests.is_empty():
			placement = requests.pop_front()
			request_lookup.erase(placement.id)
			has_request = true
		mutex.unlock()
		if not has_request or placement == null:
			continue
		var started_ms: int = Time.get_ticks_msec()
		var chunks: Array[PieceChunkData] = bake_placement(
			placement,
			material_palette,
			collision_cell_size,
			preview_downscale_factor,
			bake_collision_data
		)
		var elapsed_ms: int = Time.get_ticks_msec() - started_ms
		var should_continue: bool = false
		mutex.lock()
		completed_count += 1
		results.append({
			"id": placement.id,
			"placement": placement,
			"chunks": chunks,
			"elapsed_ms": elapsed_ms,
		})
		should_continue = not requests.is_empty() and results.size() < max_result_backlog
		mutex.unlock()
		if inter_job_yield_ms > 0:
			OS.delay_msec(inter_job_yield_ms)
		if should_continue:
			semaphore.post()

static func bake_placement(
	placement: SpecialChunkPlacement,
	palette: MaterialPalette,
	p_collision_cell_size: int,
	p_preview_downscale_factor: int,
	p_bake_collision_data: bool
) -> Array[PieceChunkData]:
	var output: Array[PieceChunkData] = []
	if placement == null:
		return output
	var source: Image = SpecialPieceImageBuilder.build(placement)
	var expected_size: Vector2i = placement.size_in_chunks * PieceWorldConstants.CHUNK_SIZE
	if source == null or source.is_empty():
		source = Image.create_empty(expected_size.x, expected_size.y, false, Image.FORMAT_RGBA8)
		source.fill(Color.TRANSPARENT)
	elif source.get_size() != expected_size:
		source = source.duplicate()
		source.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_NEAREST)
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var chunk_size: int = PieceWorldConstants.CHUNK_SIZE
	for local_y: int in range(placement.size_in_chunks.y):
		for local_x: int in range(placement.size_in_chunks.x):
			var world_coord: Vector2i = placement.origin_chunk + Vector2i(local_x, local_y)
			var crop: Image = Image.create_empty(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
			crop.blit_rect(
				source,
				Rect2i(Vector2i(local_x * chunk_size, local_y * chunk_size), Vector2i(chunk_size, chunk_size)),
				Vector2i.ZERO
			)
			var data := PieceChunkData.new(world_coord)
			data.biome_id = placement.biome_id
			data.special_chunk_id = placement.chunk_def.id if placement.chunk_def != null else placement.id
			data.special_chunk_origin = placement.origin_chunk
			data.special_chunk_size = placement.size_in_chunks
			data.visual_image = crop
			data.preview_image = crop
			if p_preview_downscale_factor > 1:
				data.preview_image = crop.duplicate()
				data.preview_image.resize(
					maxi(1, chunk_size / p_preview_downscale_factor),
					maxi(1, chunk_size / p_preview_downscale_factor),
					Image.INTERPOLATE_NEAREST
				)
				data.visual_image = null
			if palette != null:
				data.element_ids = palette.image_to_element_ids(crop)
				if p_bake_collision_data:
					data.collision_rects = palette.build_collision_rects(
						data.element_ids, chunk_size, chunk_size, p_collision_cell_size
					)
			output.append(data)
	return output
