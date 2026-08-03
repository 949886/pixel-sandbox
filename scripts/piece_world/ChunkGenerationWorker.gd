class_name ChunkGenerationWorker
extends RefCounted

# Single background worker for normal piece chunks. CPU-heavy piece selection,
# image composition, material conversion and collision meshing stay off the main
# thread. The queue is cancellable/prioritized so fast player movement does not
# waste time generating chunks that have already left the streaming window.

var generator: PieceChunkGenerator
var thread: Thread
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var stop_requested: bool = false
var running: bool = false
var requests: Array[Vector2i] = []
var request_lookup: Dictionary = {}
var results: Array[Dictionary] = []
var completed_count: int = 0
var failed_count: int = 0
var last_error: String = ""
var max_result_backlog: int = 4
var inter_job_yield_ms: int = 0

func start(
	p_generator: PieceChunkGenerator,
	p_max_result_backlog: int = 4,
	p_inter_job_yield_ms: int = 0
) -> bool:
	stop()
	generator = p_generator
	max_result_backlog = maxi(1, p_max_result_backlog)
	inter_job_yield_ms = maxi(0, p_inter_job_yield_ms)
	stop_requested = false
	requests.clear()
	request_lookup.clear()
	results.clear()
	completed_count = 0
	failed_count = 0
	last_error = ""
	thread = Thread.new()
	var err: Error = thread.start(Callable(self, "_thread_loop"))
	running = err == OK
	if not running:
		last_error = "Thread.start failed: %s" % str(err)
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

func enqueue(coord: Vector2i) -> bool:
	if not running or generator == null:
		return false
	var should_post: bool = false
	mutex.lock()
	if not request_lookup.has(coord):
		request_lookup[coord] = true
		requests.append(coord)
		should_post = true
	mutex.unlock()
	if should_post:
		semaphore.post()
	return should_post

func clear_pending() -> void:
	mutex.lock()
	requests.clear()
	request_lookup.clear()
	results.clear()
	mutex.unlock()

func prune_requests(allowed_coords: Dictionary) -> void:
	## Drops queued and completed-but-not-attached chunks outside the current window.
	## A request already executing cannot be interrupted, but its result will be
	## discarded by WorldManager if it became obsolete during generation.
	mutex.lock()
	var kept_requests: Array[Vector2i] = []
	request_lookup.clear()
	for coord: Vector2i in requests:
		if allowed_coords.has(coord):
			kept_requests.append(coord)
			request_lookup[coord] = true
	requests = kept_requests
	var kept_results: Array[Dictionary] = []
	for result: Dictionary in results:
		var coord: Vector2i = result.get("coord", Vector2i.ZERO)
		if allowed_coords.has(coord):
			kept_results.append(result)
	results = kept_results
	mutex.unlock()

func prioritize_requests(center: Vector2i) -> void:
	mutex.lock()
	requests.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = a.distance_squared_to(center)
		var db: int = b.distance_squared_to(center)
		if da == db:
			return a.y < b.y if a.y != b.y else a.x < b.x
		return da < db
	)
	mutex.unlock()

func collect_results(max_results: int = 2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var should_wake: bool = false
	mutex.lock()
	var count: int = maxi(1, max_results)
	while count > 0 and not results.is_empty():
		out.append(results.pop_front())
		count -= 1
	should_wake = not requests.is_empty() and results.size() < max_result_backlog
	mutex.unlock()
	# Wake a producer blocked by the bounded result queue. This replaces the old
	# 1ms self-poll loop, eliminating background busy-wait CPU usage on mobile.
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

func is_queued(coord: Vector2i) -> bool:
	mutex.lock()
	var found: bool = request_lookup.has(coord)
	mutex.unlock()
	return found

func _thread_loop() -> void:
	while true:
		semaphore.wait()
		var coord: Vector2i = Vector2i.ZERO
		var has_request: bool = false
		mutex.lock()
		if stop_requested:
			mutex.unlock()
			break
		if results.size() < max_result_backlog and not requests.is_empty():
			coord = requests.pop_front()
			request_lookup.erase(coord)
			has_request = true
		mutex.unlock()
		if not has_request:
			# The bounded result queue is full, or a stale semaphore token was
			# consumed. collect_results()/enqueue() will wake us again.
			continue
		var data: PieceChunkData = null
		var ok: bool = false
		var error_text: String = ""
		var started_ms: int = Time.get_ticks_msec()
		if generator == null:
			error_text = "generator missing"
		else:
			data = generator.generate_chunk(coord, false)
			ok = data != null
			if not ok:
				error_text = "generate_chunk returned null"
		var elapsed_ms: int = Time.get_ticks_msec() - started_ms
		var should_continue: bool = false
		mutex.lock()
		if ok:
			completed_count += 1
			results.append({
				"coord": coord,
				"data": data,
				"elapsed_ms": elapsed_ms,
			})
		else:
			failed_count += 1
			last_error = error_text
			results.append({
				"coord": coord,
				"data": null,
				"elapsed_ms": elapsed_ms,
				"error": error_text,
			})
		should_continue = not requests.is_empty() and results.size() < max_result_backlog
		mutex.unlock()
		if inter_job_yield_ms > 0:
			OS.delay_msec(inter_job_yield_ms)
		if should_continue:
			semaphore.post()
