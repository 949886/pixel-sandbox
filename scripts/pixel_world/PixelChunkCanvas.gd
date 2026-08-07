class_name PixelChunkCanvas
extends Node2D

## Staged pixel chunk renderer with native dirty rendering and independently
## replaceable collision sectors. Solid visual changes are not uploaded until the
## matching PhysicsServer2D sectors have committed, preventing invisible walls.
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE
const TOTAL_PIXELS: int = CHUNK_SIZE * CHUNK_SIZE
const DEFAULT_COLLISION_SECTOR_SIZE: int = 64
const COLLISION_CHANGE_REMOVED: int = 1
const COLLISION_CHANGE_ADDED: int = 2
const COLLISION_CHANGE_BOTH: int = COLLISION_CHANGE_REMOVED | COLLISION_CHANGE_ADDED
static var _warned_missing_native_dirty: bool = false
static var _warned_missing_native_sector_api: bool = false


enum WarmState {
	COLD,
	LOADING,
	READY_TO_UPLOAD,
	READY,
}


var simulation: SandSimulation
var chunk_data: PieceChunkData
var material_palette: MaterialPalette
var simulation_requested: bool = false
var warmup_requested: bool = false
var collision_requested: bool = false
var simulation_iterations: int = 1
var simulation_interval_usec: int = 16667
var repaint_interval_usec: int = 16667
var used_bulk_upload: bool = false
var used_ranged_bulk_upload: bool = false
var fallback_loaded_cells: int = 0
var warm_state: WarmState = WarmState.COLD
var next_simulation_due_usec: int = 0
var next_repaint_due_usec: int = 0

var _sprite: Sprite2D
var _static_texture: ImageTexture
var _simulation_texture: ImageTexture
var _collision_debug_drawer: PixelCollisionDebugDrawer
var _collision_debug_visible: bool = false
var _element_ids: PackedInt32Array = PackedInt32Array()
var _initial_collision_rects: PackedInt32Array = PackedInt32Array()
var _load_cursor: int = 0
var _collision_cell_size: int = 1
var _collision_sector_size: int = DEFAULT_COLLISION_SECTOR_SIZE
var _collision_sector_width: int = 8
var _collision_sector_height: int = 8
var _collision_rebuild_interval_usec: int = 50000
var _collision_sectors: Array[PixelCollisionSectorState] = []
var _collision_work_queue: Array[int] = []
var _initial_collision_queued: bool = false
var _collision_snapshot_committed: bool = false
var _repaint_requested: bool = false
var _visual_dirty_pending: bool = false
var _native_dirty_supported: bool = false
var _native_collision_dirty_supported: bool = false
var _native_collision_rects_supported: bool = false
var _native_collision_sector_supported: bool = false
var _native_erase_circle_supported: bool = false
var _native_api_version: int = 0


func _ready() -> void:
	_ensure_nodes()
	set_notify_transform(true)
	set_process(false)


func _exit_tree() -> void:
	_free_collision_sector_bodies()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_collision_body_transforms()


func setup(
	data: PieceChunkData,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	iterations: int = 1,
	simulation_hz: float = 60.0,
	repaint_hz: float = 60.0,
	_max_collision_triangles: int = 6000,
	collision_cell_size: int = 1,
	collision_sector_size: int = DEFAULT_COLLISION_SECTOR_SIZE,
	collision_dynamic_rebuild_hz: float = 20.0
) -> void:
	recycle_for_pool()
	chunk_data = data
	material_palette = palette
	simulation_requested = enable_simulation
	warmup_requested = enable_simulation
	collision_requested = enable_collision
	simulation_iterations = maxi(1, iterations)
	set_simulation_timing(simulation_hz, repaint_hz)
	_collision_cell_size = maxi(1, collision_cell_size)
	_collision_sector_size = maxi(16, collision_sector_size)
	_collision_sector_width = ceili(float(CHUNK_SIZE) / float(_collision_sector_size))
	_collision_sector_height = ceili(float(CHUNK_SIZE) / float(_collision_sector_size))
	_collision_rebuild_interval_usec = maxi(1000, int(1000000.0 / maxf(collision_dynamic_rebuild_hz, 1.0)))
	visible = true
	_ensure_nodes()
	_reset_collision_sector_states()
	_element_ids = data.element_ids if data != null else PackedInt32Array()
	_initial_collision_rects = data.collision_rects if data != null else PackedInt32Array()
	if _element_ids.size() != TOTAL_PIXELS and data != null and data.material_image != null and palette != null:
		_element_ids = palette.image_to_element_ids(data.material_image)
	_upload_static_preview()
	var coord_hash: int = abs((data.coord.x * 73856093) ^ (data.coord.y * 19349663)) if data != null else 0
	var now_usec: int = Time.get_ticks_usec()
	next_simulation_due_usec = now_usec + (coord_hash % maxi(1, simulation_interval_usec))
	next_repaint_due_usec = now_usec + (coord_hash % maxi(1, repaint_interval_usec))


func set_simulation_timing(simulation_hz: float, repaint_hz: float) -> void:
	var new_simulation_interval: int = maxi(1000, int(1000000.0 / maxf(simulation_hz, 1.0)))
	var new_repaint_interval: int = maxi(1000, int(1000000.0 / maxf(repaint_hz, 1.0)))
	var now_usec: int = Time.get_ticks_usec()
	var simulation_rate_increased: bool = new_simulation_interval < simulation_interval_usec
	var repaint_rate_increased: bool = new_repaint_interval < repaint_interval_usec
	simulation_interval_usec = new_simulation_interval
	repaint_interval_usec = new_repaint_interval
	if next_simulation_due_usec <= 0 or simulation_rate_increased:
		next_simulation_due_usec = mini(next_simulation_due_usec if next_simulation_due_usec > 0 else now_usec, now_usec + simulation_interval_usec)
	if next_repaint_due_usec <= 0 or repaint_rate_increased:
		next_repaint_due_usec = mini(next_repaint_due_usec if next_repaint_due_usec > 0 else now_usec, now_usec + repaint_interval_usec)


func set_simulation_active(active: bool) -> void:
	simulation_requested = active
	if active:
		warmup_requested = true
	if active and warm_state == WarmState.READY:
		next_simulation_due_usec = mini(next_simulation_due_usec, Time.get_ticks_usec())


func set_warmup_requested(active: bool) -> void:
	warmup_requested = active or simulation_requested


func is_warmup_requested() -> bool:
	return warmup_requested


func set_collision_active(active: bool) -> void:
	if collision_requested == active:
		return
	collision_requested = active
	_apply_collision_activation()
	_refresh_collision_debug()


func set_collision_debug_visible(enabled: bool) -> void:
	if _collision_debug_visible == enabled:
		return
	_collision_debug_visible = enabled
	_ensure_nodes()
	_refresh_collision_debug()


func is_collision_debug_visible() -> bool:
	return _collision_debug_visible


func get_committed_collision_rect_count() -> int:
	var count: int = 0
	for state: PixelCollisionSectorState in _collision_sectors:
		count += int(state.active_rects.size() / 4)
	return count


func get_collision_debug_stats() -> Dictionary:
	var dirty_count: int = 0
	var building_count: int = 0
	var pending_count: int = 0
	var unsafe_count: int = 0
	for state: PixelCollisionSectorState in _collision_sectors:
		if state.dirty:
			dirty_count += 1
		if state.build_in_progress:
			building_count += 1
		if state.commit_pending:
			pending_count += 1
		if _sector_requires_collision_first(state):
			unsafe_count += 1
	return {
		"sector_size": _collision_sector_size,
		"sector_count": _collision_sectors.size(),
		"dirty": dirty_count,
		"building": building_count,
		"pending": pending_count,
		"unsafe": unsafe_count,
		"committed": _collision_snapshot_committed,
		"native_sector_api": _native_collision_sector_supported,
		"native_api_version": _native_api_version,
	}


func has_committed_collision_snapshot() -> bool:
	return _collision_snapshot_committed


func has_pending_collision_sync(unsafe_only: bool = false) -> bool:
	if not collision_requested:
		return false
	if not _collision_snapshot_committed:
		return true
	if _native_collision_sector_supported:
		_poll_native_dirty_sectors()
	for state: PixelCollisionSectorState in _collision_sectors:
		var pending: bool = state.dirty or state.build_in_progress or state.commit_pending
		if not pending:
			continue
		if not unsafe_only or _sector_requires_collision_first(state):
			return true
	if not _native_collision_sector_supported:
		return _native_collision_is_dirty()
	return false


func has_pending_unsafe_collision_sync() -> bool:
	return has_pending_collision_sync(true)


func is_collision_region_committed(local_rect: Rect2) -> bool:
	if not collision_requested or not _collision_snapshot_committed:
		return false
	if _native_collision_sector_supported:
		_poll_native_dirty_sectors()
	var clipped := local_rect.intersection(Rect2(Vector2.ZERO, Vector2.ONE * float(CHUNK_SIZE)))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return true
	var pixel_start := Vector2i(floori(clipped.position.x), floori(clipped.position.y))
	var pixel_end := Vector2i(ceili(clipped.end.x), ceili(clipped.end.y))
	_prioritize_collision_bounds(Rect2i(pixel_start, pixel_end - pixel_start))
	var min_sector := Vector2i(
		clampi(floori(clipped.position.x / float(_collision_sector_size)), 0, _collision_sector_width - 1),
		clampi(floori(clipped.position.y / float(_collision_sector_size)), 0, _collision_sector_height - 1)
	)
	var last_point := clipped.end - Vector2(0.001, 0.001)
	var max_sector := Vector2i(
		clampi(floori(last_point.x / float(_collision_sector_size)), 0, _collision_sector_width - 1),
		clampi(floori(last_point.y / float(_collision_sector_size)), 0, _collision_sector_height - 1)
	)
	for sector_y: int in range(min_sector.y, max_sector.y + 1):
		for sector_x: int in range(min_sector.x, max_sector.x + 1):
			var state: PixelCollisionSectorState = _collision_sectors[_sector_index(sector_x, sector_y)]
			if not state.initial_committed:
				return false
			# Removal-only edits keep a conservative old collision snapshot. They may
			# temporarily block empty pixels, but cannot let the player enter new solids.
			if (state.dirty or state.build_in_progress or state.commit_pending) and _sector_requires_collision_first(state):
				return false
	return true


func is_collision_active() -> bool:
	return collision_requested and _collision_snapshot_committed


func is_simulation_active() -> bool:
	# Do not let the native grid advance past the worker-baked initial collision.
	return (
		simulation_requested
		and warm_state == WarmState.READY
		and simulation != null
		and (not collision_requested or _collision_snapshot_committed)
	)


func is_warm() -> bool:
	return warm_state == WarmState.READY_TO_UPLOAD or warm_state == WarmState.READY


func needs_initialization() -> bool:
	return warmup_requested and warm_state == WarmState.COLD and _element_ids.size() == TOTAL_PIXELS


func is_initializing() -> bool:
	return warm_state == WarmState.LOADING


func needs_texture_activation() -> bool:
	return warmup_requested and warm_state == WarmState.READY_TO_UPLOAD and simulation != null


func begin_initialization() -> void:
	if not needs_initialization():
		return
	simulation = SandSimulation.new()
	if simulation.has_method("reset_grid"):
		simulation.call("reset_grid", CHUNK_SIZE, CHUNK_SIZE, 16)
	else:
		simulation.set_chunk_size(16)
		simulation.resize(CHUNK_SIZE, CHUNK_SIZE)
	SandSimulationConfigurator.configure(simulation, material_palette)
	used_ranged_bulk_upload = simulation.has_method("set_cells_bulk_range")
	used_bulk_upload = simulation.has_method("set_cells_bulk")
	_native_dirty_supported = simulation.has_method("is_dirty") and simulation.has_method("clear_dirty")
	_native_collision_dirty_supported = simulation.has_method("is_collision_dirty") and simulation.has_method("clear_collision_dirty")
	_native_collision_rects_supported = simulation.has_method("get_collision_rects")
	_native_collision_sector_supported = (
		simulation.has_method("configure_collision_sectors")
		and simulation.has_method("get_dirty_collision_sectors")
		and simulation.has_method("get_collision_sector_snapshot")
		and simulation.has_method("classify_collision_sector_snapshot")
		and simulation.has_method("acknowledge_collision_sector")
		and simulation.has_method("get_collision_sector_revision")
		and simulation.has_method("has_dirty_collision_sectors")
	)
	_native_erase_circle_supported = simulation.has_method("erase_circle")
	_native_api_version = int(simulation.call("get_native_api_version")) if simulation.has_method("get_native_api_version") else 0
	_native_collision_sector_supported = _native_collision_sector_supported and _native_api_version >= 8
	_native_erase_circle_supported = _native_erase_circle_supported and _native_api_version >= 6
	if _native_collision_sector_supported:
		simulation.call("configure_collision_sectors", _collision_sector_size)
	elif not _warned_missing_native_sector_api:
		_warned_missing_native_sector_api = true
		push_warning("SandSimulation collision-sector API is missing or older than API 8; terrain edits fall back to full-chunk collision scans until the GDExtension is rebuilt.")
	if not _native_dirty_supported and not _warned_missing_native_dirty:
		_warned_missing_native_dirty = true
		push_warning("SandSimulation DLL has no is_dirty()/clear_dirty(); using legacy full repaint mode.")
	fallback_loaded_cells = 0
	_load_cursor = 0
	warm_state = WarmState.LOADING
	if used_bulk_upload and not used_ranged_bulk_upload:
		simulation.call("set_cells_bulk", _element_ids)
		_finish_element_transfer()


func advance_initialization(pixel_budget: int, deadline_usec: int) -> bool:
	if warm_state == WarmState.COLD:
		begin_initialization()
	if warm_state != WarmState.LOADING or simulation == null:
		return warm_state == WarmState.READY_TO_UPLOAD or warm_state == WarmState.READY
	var processed: int = 0
	var budget: int = maxi(1, pixel_budget)
	if used_ranged_bulk_upload:
		var transfer_count: int = mini(budget, _element_ids.size() - _load_cursor)
		simulation.call("set_cells_bulk_range", _element_ids, _load_cursor, transfer_count)
		_load_cursor += transfer_count
		if _load_cursor >= _element_ids.size():
			_finish_element_transfer()
			return true
		return false
	while _load_cursor < _element_ids.size() and processed < budget:
		var element_id: int = _element_ids[_load_cursor]
		if element_id != 0:
			fallback_loaded_cells += 1
			simulation.draw_cell(
				floori(float(_load_cursor) / float(CHUNK_SIZE)),
				_load_cursor % CHUNK_SIZE,
				element_id
			)
		_load_cursor += 1
		processed += 1
		if (processed & 255) == 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	if _load_cursor >= _element_ids.size():
		_finish_element_transfer()
		return true
	return false


func activate_simulation_texture() -> bool:
	if not needs_texture_activation():
		return false
	_repaint()
	warm_state = WarmState.READY
	if _native_dirty_supported:
		simulation.call("clear_dirty")
	# Sector dirty flags are acknowledged per committed revision. The legacy global
	# flag may still be cleared because it has no region/revision semantics.
	if _native_collision_dirty_supported and not _native_collision_sector_supported:
		simulation.call("clear_collision_dirty")
	_acknowledge_committed_initial_sectors()
	_static_texture = null
	var now_usec: int = Time.get_ticks_usec()
	next_simulation_due_usec = now_usec + simulation_interval_usec
	next_repaint_due_usec = now_usec + repaint_interval_usec
	_visual_dirty_pending = false
	return true


func collision_is_ready() -> bool:
	if not _collision_snapshot_committed:
		return false
	for state: PixelCollisionSectorState in _collision_sectors:
		if state.build_in_progress or state.commit_pending:
			return false
	return _collision_work_queue.is_empty()


func needs_collision_work() -> bool:
	if not collision_requested:
		return false
	if not _initial_collision_queued or not _collision_work_queue.is_empty():
		return true
	for state: PixelCollisionSectorState in _collision_sectors:
		if state.build_in_progress:
			return true
	if _native_collision_sector_supported and simulation != null and warm_state == WarmState.READY:
		return bool(simulation.call("has_dirty_collision_sectors"))
	return _native_collision_is_dirty()


func advance_collision(shape_budget: int, deadline_usec: int) -> bool:
	if not collision_requested:
		return _collision_snapshot_committed
	_ensure_nodes()
	if not _initial_collision_queued:
		_queue_initial_collision_sectors()
	elif _collision_snapshot_committed:
		if _native_collision_sector_supported:
			_poll_native_dirty_sectors()
		elif _native_collision_is_dirty() and _collision_work_queue.is_empty() and not _has_sector_build_in_progress():
			_queue_legacy_full_collision_rebuild()

	var remaining_shapes: int = maxi(1, shape_budget)
	while remaining_shapes > 0 and not _collision_work_queue.is_empty():
		var sector_index: int = _collision_work_queue[0]
		if sector_index < 0 or sector_index >= _collision_sectors.size():
			_collision_work_queue.pop_front()
			continue
		var state: PixelCollisionSectorState = _collision_sectors[sector_index]
		if state.commit_pending:
			_collision_work_queue.pop_front()
			continue
		if not state.build_in_progress:
			if not _prepare_sector_snapshot(state):
				_collision_work_queue.pop_front()
				continue
		if state.staging_rects.is_empty():
			state.build_in_progress = false
			state.commit_pending = true
			state.snapshot_prepared = false
			_collision_work_queue.pop_front()
			continue

		_ensure_staging_body(state)
		var built_this_sector: int = 0
		while state.staging_cursor * 4 + 3 < state.staging_rects.size() and remaining_shapes > 0:
			var base: int = state.staging_cursor * 4
			var x: float = float(state.staging_rects[base])
			var y: float = float(state.staging_rects[base + 1])
			var width: float = float(state.staging_rects[base + 2])
			var height: float = float(state.staging_rects[base + 3])
			var shape_rid: RID = PhysicsServer2D.rectangle_shape_create()
			PhysicsServer2D.shape_set_data(shape_rid, Vector2(width * 0.5, height * 0.5))
			PhysicsServer2D.body_add_shape(
				state.staging_body,
				shape_rid,
				Transform2D(0.0, Vector2(x + width * 0.5, y + height * 0.5))
			)
			state.staging_shape_rids.append(shape_rid)
			state.staging_cursor += 1
			remaining_shapes -= 1
			built_this_sector += 1
			if (built_this_sector & 7) == 0 and Time.get_ticks_usec() >= deadline_usec:
				break
		if state.staging_cursor * 4 >= state.staging_rects.size():
			state.build_in_progress = false
			state.commit_pending = true
			state.snapshot_prepared = false
			_collision_work_queue.pop_front()
		if Time.get_ticks_usec() >= deadline_usec:
			break
	_refresh_collision_debug()
	return collision_is_ready() and not has_pending_collision_sync()


func commit_ready_collision_sectors(max_count: int = 64) -> int:
	## Called by WorldManager._physics_process() before Player.move_and_slide().
	var committed: int = 0
	for state: PixelCollisionSectorState in _collision_sectors:
		if committed >= maxi(1, max_count):
			break
		if not state.commit_pending:
			continue
		if _commit_collision_sector(state):
			committed += 1
	_update_collision_snapshot_committed()
	if committed > 0:
		if not has_pending_unsafe_collision_sync():
			next_repaint_due_usec = mini(next_repaint_due_usec, Time.get_ticks_usec())
		_refresh_collision_debug()
	return committed


func simulation_due(now_usec: int) -> bool:
	return is_simulation_active() and now_usec >= next_simulation_due_usec


func run_simulation_tick(now_usec: int) -> void:
	if not is_simulation_active():
		return
	simulation.step(simulation_iterations)
	var changed: bool = bool(simulation.call("is_dirty")) if _native_dirty_supported else true
	_visual_dirty_pending = _visual_dirty_pending or changed or _repaint_requested
	flush_visual_update(now_usec)
	next_simulation_due_usec = now_usec + simulation_interval_usec


func visual_update_due(now_usec: int) -> bool:
	return (
		simulation != null
		and warm_state == WarmState.READY
		and _visual_dirty_pending
		and now_usec >= next_repaint_due_usec
	)


func flush_visual_update(now_usec: int) -> bool:
	## Added solids must commit first. Removal-only changes may render immediately:
	## the previous collision remains conservative while its throttled rebuild catches up.
	if not visual_update_due(now_usec) or has_pending_unsafe_collision_sync():
		return false
	_repaint()
	if _native_dirty_supported:
		simulation.call("clear_dirty")
	_visual_dirty_pending = false
	_repaint_requested = false
	next_repaint_due_usec = now_usec + repaint_interval_usec
	return true


func get_cell(local_x: int, local_y: int) -> int:
	if simulation == null or warm_state != WarmState.READY or local_x < 0 or local_y < 0:
		return 0
	if local_x >= CHUNK_SIZE or local_y >= CHUNK_SIZE:
		return 0
	return simulation.get_cell(local_y, local_x)


func set_cell(local_x: int, local_y: int, element_id: int) -> void:
	if simulation == null or warm_state != WarmState.READY or local_x < 0 or local_y < 0:
		return
	if local_x >= CHUNK_SIZE or local_y >= CHUNK_SIZE:
		return
	simulation.draw_cell(local_y, local_x, clampi(element_id, 0, 4096))
	if not _native_dirty_supported:
		_repaint_requested = true
	_visual_dirty_pending = true
	next_simulation_due_usec = mini(next_simulation_due_usec, Time.get_ticks_usec())


func erase_circle_local(local_center: Vector2, radius: float, replacement_element: int = 0) -> int:
	if simulation == null or warm_state != WarmState.READY:
		return 0
	var changed: int = 0
	var native_result: PackedInt32Array = PackedInt32Array()
	if _native_erase_circle_supported:
		native_result = simulation.call(
			"erase_circle", local_center.x, local_center.y, radius, replacement_element
		)
		if not native_result.is_empty():
			changed = native_result[0]
	else:
		var safe_radius: float = clampf(radius, 0.5, 256.0)
		var min_pixel := Vector2i((local_center - Vector2.ONE * safe_radius).floor())
		var max_pixel := Vector2i((local_center + Vector2.ONE * safe_radius).ceil())
		var radius_squared: float = safe_radius * safe_radius
		for local_y: int in range(maxi(0, min_pixel.y), mini(CHUNK_SIZE - 1, max_pixel.y) + 1):
			for local_x: int in range(maxi(0, min_pixel.x), mini(CHUNK_SIZE - 1, max_pixel.x) + 1):
				var pixel_center := Vector2(local_x + 0.5, local_y + 0.5)
				if pixel_center.distance_squared_to(local_center) > radius_squared:
					continue
				if get_cell(local_x, local_y) == replacement_element:
					continue
				set_cell(local_x, local_y, replacement_element)
				changed += 1
	if changed > 0:
		_visual_dirty_pending = true
		_repaint_requested = not _native_dirty_supported
		next_simulation_due_usec = mini(next_simulation_due_usec, Time.get_ticks_usec())
		if _native_collision_sector_supported:
			_poll_native_dirty_sectors()
			if native_result.size() >= 5 and native_result[1] >= 0:
				_prioritize_collision_bounds(Rect2i(
					native_result[1], native_result[2],
					native_result[3] - native_result[1] + 1, native_result[4] - native_result[2] + 1
				))
	return changed


func request_repaint() -> void:
	if not _native_dirty_supported:
		_repaint_requested = true
	_visual_dirty_pending = true
	next_simulation_due_usec = mini(next_simulation_due_usec, Time.get_ticks_usec())


func upload_mode_name() -> String:
	match warm_state:
		WarmState.COLD:
			return "static preview"
		WarmState.LOADING:
			return "warming %d%%" % int(100.0 * float(_load_cursor) / float(TOTAL_PIXELS))
		WarmState.READY_TO_UPLOAD:
			return "native ready / texture queued"
		_:
			if used_ranged_bulk_upload:
				return "native ranged bulk"
			if used_bulk_upload:
				return "native bulk"
			return "budgeted fallback (%d cells)" % fallback_loaded_cells


func recycle_for_pool() -> void:
	simulation_requested = false
	warmup_requested = false
	collision_requested = false
	simulation = null
	chunk_data = null
	material_palette = null
	used_bulk_upload = false
	used_ranged_bulk_upload = false
	fallback_loaded_cells = 0
	warm_state = WarmState.COLD
	_load_cursor = 0
	_collision_cell_size = 1
	_collision_sector_size = DEFAULT_COLLISION_SECTOR_SIZE
	_collision_rebuild_interval_usec = 50000
	_initial_collision_queued = false
	_collision_snapshot_committed = false
	_collision_work_queue.clear()
	_collision_debug_visible = false
	_repaint_requested = false
	_visual_dirty_pending = false
	next_simulation_due_usec = 0
	next_repaint_due_usec = 0
	_native_dirty_supported = false
	_native_collision_dirty_supported = false
	_native_collision_rects_supported = false
	_native_collision_sector_supported = false
	_native_erase_circle_supported = false
	_native_api_version = 0
	_element_ids = PackedInt32Array()
	_initial_collision_rects = PackedInt32Array()
	_free_collision_sector_bodies()
	_simulation_texture = null
	if _sprite != null:
		_sprite.texture = null
		_sprite.scale = Vector2.ONE
	visible = false


func _finish_element_transfer() -> void:
	warm_state = WarmState.READY_TO_UPLOAD
	_load_cursor = _element_ids.size()
	_element_ids = PackedInt32Array()


func _upload_static_preview() -> void:
	if chunk_data == null:
		return
	var preview: Image = chunk_data.preview_image
	if preview == null or preview.is_empty():
		preview = chunk_data.visual_image
	if preview == null or preview.is_empty():
		return
	if (
		_static_texture != null
		and _static_texture.get_width() == preview.get_width()
		and _static_texture.get_height() == preview.get_height()
	):
		_static_texture.update(preview)
	else:
		_static_texture = ImageTexture.create_from_image(preview)
	_sprite.texture = _static_texture
	_sprite.scale = Vector2(float(CHUNK_SIZE) / float(preview.get_width()), float(CHUNK_SIZE) / float(preview.get_height()))


func _repaint() -> void:
	if simulation == null:
		return
	var rgba: PackedByteArray = simulation.get_color_image(true)
	var image: Image = Image.create_from_data(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8, rgba)
	if _simulation_texture == null:
		_simulation_texture = ImageTexture.create_from_image(image)
	else:
		_simulation_texture.update(image)
	_sprite.texture = _simulation_texture
	_sprite.scale = Vector2.ONE


func _native_collision_is_dirty() -> bool:
	return (
		simulation != null
		and warm_state == WarmState.READY
		and _native_collision_dirty_supported
		and bool(simulation.call("is_collision_dirty"))
	)


func _queue_initial_collision_sectors() -> void:
	_reset_collision_sector_states()
	var sector_rects: Array = []
	sector_rects.resize(_collision_sectors.size())
	for index: int in range(sector_rects.size()):
		sector_rects[index] = PackedInt32Array()
	_partition_rects_into_sectors(_initial_collision_rects, sector_rects)
	for index: int in range(_collision_sectors.size()):
		var state: PixelCollisionSectorState = _collision_sectors[index]
		state.staging_rects = sector_rects[index]
		state.building_revision = -1
		state.queued_revision = -1
		state.snapshot_prepared = true
		state.dirty = true
		state.change_flags = COLLISION_CHANGE_BOTH
		_collision_work_queue.append(index)
	_initial_collision_queued = true
	_initial_collision_rects = PackedInt32Array()


func _queue_legacy_full_collision_rebuild() -> void:
	if simulation == null or not _native_collision_rects_supported:
		return
	var full_rects: PackedInt32Array = simulation.call("get_collision_rects", _collision_cell_size)
	var sector_rects: Array = []
	sector_rects.resize(_collision_sectors.size())
	for index: int in range(sector_rects.size()):
		sector_rects[index] = PackedInt32Array()
	_partition_rects_into_sectors(full_rects, sector_rects)
	for index: int in range(_collision_sectors.size()):
		var state: PixelCollisionSectorState = _collision_sectors[index]
		if state.build_in_progress or state.commit_pending:
			continue
		state.staging_rects = sector_rects[index]
		state.building_revision = state.active_revision + 1
		state.queued_revision = state.building_revision
		state.snapshot_prepared = true
		state.dirty = true
		state.change_flags = COLLISION_CHANGE_BOTH
		if not _collision_work_queue.has(index):
			_collision_work_queue.append(index)
	if _native_collision_dirty_supported:
		simulation.call("clear_collision_dirty")


func _poll_native_dirty_sectors() -> void:
	if not _native_collision_sector_supported or simulation == null or warm_state != WarmState.READY:
		return
	var dirty_data: PackedInt32Array = simulation.call("get_dirty_collision_sectors", _collision_sectors.size())
	var entry_count: int = int(dirty_data.size() / 4)
	var seen: Dictionary = {}
	var now_usec: int = Time.get_ticks_usec()
	for entry: int in range(entry_count):
		var base: int = entry * 4
		var sector_coord := Vector2i(dirty_data[base], dirty_data[base + 1])
		var revision: int = dirty_data[base + 2]
		var change_flags: int = dirty_data[base + 3]
		var index: int = _sector_index(sector_coord.x, sector_coord.y)
		if index < 0:
			continue
		seen[index] = true
		var state: PixelCollisionSectorState = _collision_sectors[index]
		state.dirty = true
		state.change_flags = change_flags if change_flags != 0 else COLLISION_CHANGE_BOTH
		state.queued_revision = maxi(state.queued_revision, revision)
		if state.build_in_progress or state.commit_pending or _collision_work_queue.has(index):
			continue
		var urgent: bool = _sector_requires_collision_first(state)
		if urgent or now_usec >= state.next_rebuild_usec:
			state.snapshot_prepared = false
			_collision_work_queue.append(index)
			# Advance the throttle when the task is queued, not only after commit.
			# A continuously changing removal-only sector may invalidate staging
			# before the physics frame; without this, it would retry every frame.
			if not urgent:
				state.next_rebuild_usec = now_usec + _collision_rebuild_interval_usec

	# A sector can return to the committed occupancy before a pending snapshot is
	# built. Native API 8 removes it from the dirty list; cancel the queued no-op.
	for index: int in range(_collision_sectors.size()):
		var state: PixelCollisionSectorState = _collision_sectors[index]
		if seen.has(index) or state.build_in_progress or state.commit_pending:
			continue
		if state.dirty:
			state.dirty = false
			state.change_flags = 0
			state.queued_revision = -1
			state.snapshot_prepared = false
			_collision_work_queue.erase(index)
	_refresh_collision_debug()


func _prioritize_collision_bounds(bounds: Rect2i) -> void:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var first_x: int = clampi(floori(float(bounds.position.x) / float(_collision_sector_size)), 0, _collision_sector_width - 1)
	var first_y: int = clampi(floori(float(bounds.position.y) / float(_collision_sector_size)), 0, _collision_sector_height - 1)
	var last_pixel: Vector2i = bounds.end - Vector2i.ONE
	var last_x: int = clampi(floori(float(last_pixel.x) / float(_collision_sector_size)), 0, _collision_sector_width - 1)
	var last_y: int = clampi(floori(float(last_pixel.y) / float(_collision_sector_size)), 0, _collision_sector_height - 1)
	var priority_indices: Array[int] = []
	for sector_y: int in range(first_y, last_y + 1):
		for sector_x: int in range(first_x, last_x + 1):
			var index: int = _sector_index(sector_x, sector_y)
			if index >= 0 and _collision_work_queue.has(index):
				priority_indices.append(index)
	for position: int in range(priority_indices.size() - 1, -1, -1):
		var index: int = priority_indices[position]
		_collision_work_queue.erase(index)
		_collision_work_queue.push_front(index)


func _prepare_sector_snapshot(state: PixelCollisionSectorState) -> bool:
	if not state.snapshot_prepared:
		if not _native_collision_sector_supported or simulation == null:
			return false
		var snapshot: PackedInt32Array = simulation.call(
			"get_collision_sector_snapshot", state.coord.x, state.coord.y, _collision_cell_size
		)
		if snapshot.is_empty() or snapshot[0] < 0:
			return false
		state.building_revision = snapshot[0]
		state.staging_rects = PackedInt32Array()
		for index: int in range(1, snapshot.size()):
			state.staging_rects.append(snapshot[index])
		state.snapshot_prepared = true
	_clear_sector_staging(state)
	state.staging_cursor = 0
	state.build_in_progress = true
	state.commit_pending = false
	state.dirty = true
	return true


func _commit_collision_sector(state: PixelCollisionSectorState) -> bool:
	# Reject a snapshot that became stale before the physics frame. Swapping it in
	# would briefly roll collision backwards and create extra RID churn.
	if _native_collision_sector_supported and simulation != null and state.building_revision >= 0:
		var current_revision: int = int(simulation.call(
			"get_collision_sector_revision", state.coord.x, state.coord.y
		))
		if current_revision != state.building_revision:
			var snapshot_status: int = int(simulation.call(
				"classify_collision_sector_snapshot",
				state.coord.x,
				state.coord.y,
				state.building_revision
			))
			# API 8 may commit a stale snapshot only when it still contains every
			# currently solid pixel. This is the common continuous-burning case:
			# the snapshot has a few extra old solids, never a dangerous hole.
			if snapshot_status < 0 or snapshot_status == 2:
				_discard_sector_staging(state)
				state.dirty = true
				state.queued_revision = current_revision
				return false

	var new_active_body: RID = state.staging_body
	var old_active_body: RID = state.active_body
	var new_active_shapes: Array[RID] = state.staging_shape_rids
	var old_active_shapes: Array[RID] = state.active_shape_rids

	_set_body_enabled(new_active_body, collision_requested)
	_set_body_enabled(old_active_body, false)

	state.active_body = new_active_body
	state.staging_body = RID()
	state.active_shape_rids = new_active_shapes
	state.staging_shape_rids = []
	state.active_rects = state.staging_rects.duplicate()
	state.staging_rects = PackedInt32Array()
	state.staging_cursor = 0
	state.initial_committed = true
	state.commit_pending = false
	state.build_in_progress = false
	state.snapshot_prepared = false

	var committed_revision: int = state.building_revision
	if _native_collision_sector_supported and simulation != null:
		if committed_revision < 0:
			committed_revision = int(simulation.call(
				"get_collision_sector_revision", state.coord.x, state.coord.y
			))
		state.active_revision = committed_revision
		var acknowledged: bool = bool(simulation.call(
			"acknowledge_collision_sector", state.coord.x, state.coord.y, committed_revision
		))
		state.dirty = not acknowledged
		if acknowledged:
			state.change_flags = 0
	else:
		state.active_revision = committed_revision
		state.dirty = false
		state.change_flags = 0
	state.next_rebuild_usec = Time.get_ticks_usec() + _collision_rebuild_interval_usec
	state.building_revision = -1
	state.queued_revision = -1
	_clear_body_shapes(old_active_body, old_active_shapes)
	if old_active_body.is_valid():
		PhysicsServer2D.free_rid(old_active_body)
	return true


func _discard_sector_staging(state: PixelCollisionSectorState) -> void:
	_clear_sector_staging(state)
	if state.staging_body.is_valid():
		PhysicsServer2D.free_rid(state.staging_body)
	state.staging_body = RID()
	state.staging_rects = PackedInt32Array()
	state.staging_cursor = 0
	state.build_in_progress = false
	state.commit_pending = false
	state.snapshot_prepared = false
	state.building_revision = -1


func _acknowledge_committed_initial_sectors() -> void:
	if not _native_collision_sector_supported or simulation == null:
		return
	for state: PixelCollisionSectorState in _collision_sectors:
		if not state.initial_committed or state.active_revision >= 0:
			continue
		var revision: int = int(simulation.call(
			"get_collision_sector_revision", state.coord.x, state.coord.y
		))
		state.active_revision = revision
		state.dirty = not bool(simulation.call(
			"acknowledge_collision_sector", state.coord.x, state.coord.y, revision
		))
		if not state.dirty:
			state.change_flags = 0
			state.next_rebuild_usec = Time.get_ticks_usec() + _collision_rebuild_interval_usec


func _partition_rects_into_sectors(rects: PackedInt32Array, output: Array) -> void:
	var rect_count: int = int(rects.size() / 4)
	for rect_index: int in range(rect_count):
		var base: int = rect_index * 4
		var rect_x: int = rects[base]
		var rect_y: int = rects[base + 1]
		var rect_w: int = rects[base + 2]
		var rect_h: int = rects[base + 3]
		if rect_w <= 0 or rect_h <= 0:
			continue
		var first_x: int = clampi(floori(float(rect_x) / float(_collision_sector_size)), 0, _collision_sector_width - 1)
		var first_y: int = clampi(floori(float(rect_y) / float(_collision_sector_size)), 0, _collision_sector_height - 1)
		var last_x: int = clampi(floori(float(rect_x + rect_w - 1) / float(_collision_sector_size)), 0, _collision_sector_width - 1)
		var last_y: int = clampi(floori(float(rect_y + rect_h - 1) / float(_collision_sector_size)), 0, _collision_sector_height - 1)
		for sector_y: int in range(first_y, last_y + 1):
			for sector_x: int in range(first_x, last_x + 1):
				var sector_left: int = sector_x * _collision_sector_size
				var sector_top: int = sector_y * _collision_sector_size
				var sector_right: int = mini(CHUNK_SIZE, sector_left + _collision_sector_size)
				var sector_bottom: int = mini(CHUNK_SIZE, sector_top + _collision_sector_size)
				var clipped_left: int = maxi(rect_x, sector_left)
				var clipped_top: int = maxi(rect_y, sector_top)
				var clipped_right: int = mini(rect_x + rect_w, sector_right)
				var clipped_bottom: int = mini(rect_y + rect_h, sector_bottom)
				if clipped_left >= clipped_right or clipped_top >= clipped_bottom:
					continue
				var index: int = _sector_index(sector_x, sector_y)
				var sector_array: PackedInt32Array = output[index]
				sector_array.append(clipped_left)
				sector_array.append(clipped_top)
				sector_array.append(clipped_right - clipped_left)
				sector_array.append(clipped_bottom - clipped_top)
				output[index] = sector_array


func _reset_collision_sector_states() -> void:
	var expected_count: int = _collision_sector_width * _collision_sector_height
	if _collision_sectors.size() != expected_count:
		_free_collision_sector_bodies()
		for sector_y: int in range(_collision_sector_height):
			for sector_x: int in range(_collision_sector_width):
				var state := PixelCollisionSectorState.new()
				state.coord = Vector2i(sector_x, sector_y)
				_collision_sectors.append(state)
	else:
		_clear_collision_sectors()
		for index: int in range(_collision_sectors.size()):
			_collision_sectors[index].coord = Vector2i(
				index % _collision_sector_width,
				floori(float(index) / float(_collision_sector_width))
			)
	_collision_work_queue.clear()
	_initial_collision_queued = false
	_collision_snapshot_committed = false

func _clear_collision_sectors() -> void:
	for state: PixelCollisionSectorState in _collision_sectors:
		_clear_body_shapes(state.active_body, state.active_shape_rids)
		_clear_body_shapes(state.staging_body, state.staging_shape_rids)
		state.active_rects = PackedInt32Array()
		state.staging_rects = PackedInt32Array()
		state.initial_committed = false
		state.build_in_progress = false
		state.commit_pending = false
		state.dirty = false
		state.snapshot_prepared = false
		state.staging_cursor = 0
		state.active_revision = -1
		state.building_revision = -1
		state.queued_revision = -1
		state.change_flags = COLLISION_CHANGE_BOTH
		state.next_rebuild_usec = 0
	_collision_work_queue.clear()
	_collision_snapshot_committed = false
	_refresh_collision_debug()


func _free_collision_sector_bodies() -> void:
	for state: PixelCollisionSectorState in _collision_sectors:
		_clear_body_shapes(state.active_body, state.active_shape_rids)
		_clear_body_shapes(state.staging_body, state.staging_shape_rids)
		if state.active_body.is_valid():
			PhysicsServer2D.free_rid(state.active_body)
		if state.staging_body.is_valid():
			PhysicsServer2D.free_rid(state.staging_body)
		state.active_body = RID()
		state.staging_body = RID()
	_collision_sectors.clear()


func _ensure_staging_body(state: PixelCollisionSectorState) -> void:
	if not state.staging_body.is_valid():
		state.staging_body = _create_collision_body()


func _create_collision_body() -> RID:
	var body: RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_space(body, get_world_2d().space)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	_set_body_enabled(body, false)
	return body


func _clear_sector_staging(state: PixelCollisionSectorState) -> void:
	_set_body_enabled(state.staging_body, false)
	_clear_body_shapes(state.staging_body, state.staging_shape_rids)


func _clear_body_shapes(body: RID, shape_rids: Array[RID]) -> void:
	if body.is_valid():
		PhysicsServer2D.body_clear_shapes(body)
	for shape_rid: RID in shape_rids:
		if shape_rid.is_valid():
			PhysicsServer2D.free_rid(shape_rid)
	shape_rids.clear()


func _set_body_enabled(body: RID, enabled: bool) -> void:
	if not body.is_valid():
		return
	var layer: int = 1 if enabled else 0
	PhysicsServer2D.body_set_collision_layer(body, layer)
	PhysicsServer2D.body_set_collision_mask(body, layer)


func _apply_collision_activation() -> void:
	for state: PixelCollisionSectorState in _collision_sectors:
		_set_body_enabled(
			state.active_body,
			collision_requested and state.initial_committed
		)
		_set_body_enabled(state.staging_body, false)


func _update_collision_body_transforms() -> void:
	if not is_inside_tree():
		return
	for state: PixelCollisionSectorState in _collision_sectors:
		if state.active_body.is_valid():
			PhysicsServer2D.body_set_state(state.active_body, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
		if state.staging_body.is_valid():
			PhysicsServer2D.body_set_state(state.staging_body, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)


func _update_collision_snapshot_committed() -> void:
	if _collision_sectors.is_empty():
		_collision_snapshot_committed = false
		return
	for state: PixelCollisionSectorState in _collision_sectors:
		if not state.initial_committed:
			_collision_snapshot_committed = false
			return
	_collision_snapshot_committed = true
	_apply_collision_activation()


func _has_sector_build_in_progress() -> bool:
	for state: PixelCollisionSectorState in _collision_sectors:
		if state.build_in_progress or state.commit_pending:
			return true
	return false


func _sector_index(sector_x: int, sector_y: int) -> int:
	if sector_x < 0 or sector_y < 0 or sector_x >= _collision_sector_width or sector_y >= _collision_sector_height:
		return -1
	return sector_y * _collision_sector_width + sector_x


func _sector_requires_collision_first(state: PixelCollisionSectorState) -> bool:
	return (state.change_flags & COLLISION_CHANGE_ADDED) != 0


func _refresh_collision_debug() -> void:
	if _collision_debug_drawer == null or not is_instance_valid(_collision_debug_drawer):
		return
	var should_show: bool = _collision_debug_visible and collision_requested
	if not should_show:
		if _collision_debug_drawer.visible:
			_collision_debug_drawer.visible = false
			_collision_debug_drawer.clear_collision_rects()
		return
	_collision_debug_drawer.visible = true
	var active_rects := PackedInt32Array()
	var dirty_sectors: Array[Vector2i] = []
	var building_sectors: Array[Vector2i] = []
	var pending_sectors: Array[Vector2i] = []
	for state: PixelCollisionSectorState in _collision_sectors:
		active_rects.append_array(state.active_rects)
		if state.dirty:
			dirty_sectors.append(state.coord)
		if state.build_in_progress:
			building_sectors.append(state.coord)
		if state.commit_pending:
			pending_sectors.append(state.coord)
	_collision_debug_drawer.set_collision_debug_state(
		active_rects,
		_collision_sector_size,
		dirty_sectors,
		building_sectors,
		pending_sectors
	)


func _ensure_nodes() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "PixelTexture"
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	if _collision_debug_drawer == null:
		_collision_debug_drawer = PixelCollisionDebugDrawer.new()
		_collision_debug_drawer.name = "CollisionDebugLayer"
		add_child(_collision_debug_drawer)
