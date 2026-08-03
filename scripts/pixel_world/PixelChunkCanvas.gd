class_name PixelChunkCanvas
extends Node2D

## A staged chunk renderer. Loading a chunk only uploads a cheap static preview.
## Native simulation allocation, element transfer, first full-resolution texture
## upload, collision shapes and repainting are all advanced later by WorldManager
## under independent frame-time budgets.
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE
const TOTAL_PIXELS: int = CHUNK_SIZE * CHUNK_SIZE
static var _warned_missing_native_dirty: bool = false

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
var repaint_interval_usec: int = 66667
var used_bulk_upload: bool = false
var used_ranged_bulk_upload: bool = false
var fallback_loaded_cells: int = 0
var warm_state: WarmState = WarmState.COLD
var next_simulation_due_usec: int = 0

var _sprite: Sprite2D
var _static_texture: ImageTexture
var _simulation_texture: ImageTexture
var _collision_root: StaticBody2D
var _collision_shape_rids: Array[RID] = []
var _element_ids: PackedInt32Array = PackedInt32Array()
var _collision_rects: PackedInt32Array = PackedInt32Array()
var _load_cursor: int = 0
var _collision_cursor: int = 0
var _collision_cell_size: int = 8
var _repaint_requested: bool = false
var _native_dirty_supported: bool = false
var _native_collision_dirty_supported: bool = false
var _native_collision_rects_supported: bool = false

func _ready() -> void:
	_ensure_nodes()
	set_process(false)

func setup(
	data: PieceChunkData,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	iterations: int = 1,
	repaint_hz: float = 15.0,
	_max_collision_triangles: int = 6000,
	collision_cell_size: int = 8
) -> void:
	recycle_for_pool()
	chunk_data = data
	material_palette = palette
	simulation_requested = enable_simulation
	warmup_requested = enable_simulation
	collision_requested = enable_collision
	simulation_iterations = maxi(1, iterations)
	repaint_interval_usec = maxi(1000, int(1000000.0 / maxf(repaint_hz, 1.0)))
	_collision_cell_size = maxi(1, collision_cell_size)
	visible = true
	_ensure_nodes()
	_element_ids = data.element_ids if data != null else PackedInt32Array()
	_collision_rects = data.collision_rects if data != null else PackedInt32Array()
	if _element_ids.size() != TOTAL_PIXELS and data != null and data.material_image != null and palette != null:
		# Compatibility for hand-created/demo data. Runtime worker-generated chunks do
		# not take this main-thread path.
		_element_ids = palette.image_to_element_ids(data.material_image)
	_upload_static_preview()
	var coord_hash: int = abs((data.coord.x * 73856093) ^ (data.coord.y * 19349663)) if data != null else 0
	next_simulation_due_usec = Time.get_ticks_usec() + (coord_hash % maxi(1, repaint_interval_usec))

func set_simulation_active(active: bool) -> void:
	# A warmed simulation is retained while the chunk remains loaded, so walking back
	# never pays the initialization cost twice.
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
	collision_requested = active
	_ensure_nodes()
	# Keep already-built shapes cached, but remove distant chunks from broad-phase
	# collision queries until they re-enter the configured physics radius.
	_collision_root.collision_layer = 1 if active else 0
	_collision_root.collision_mask = 1 if active else 0

func is_simulation_active() -> bool:
	return simulation_requested and warm_state == WarmState.READY and simulation != null

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
	if not _native_dirty_supported and not _warned_missing_native_dirty:
		_warned_missing_native_dirty = true
		push_warning("SandSimulation DLL has no is_dirty()/clear_dirty(); using legacy full repaint mode. Rebuild extensions/sand-slide to enable native dirty rendering.")
	fallback_loaded_cells = 0
	_load_cursor = 0
	warm_state = WarmState.LOADING
	if used_bulk_upload and not used_ranged_bulk_upload:
		simulation.call("set_cells_bulk", _element_ids)
		_finish_element_transfer()

func advance_initialization(pixel_budget: int, deadline_usec: int) -> bool:
	## Returns true when native element transfer completed this call. The first
	## full-resolution visual upload is deliberately handled by a separate budget.
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
	## Returns true when the static preview was replaced by the live texture.
	if not needs_texture_activation():
		return false
	_repaint()
	warm_state = WarmState.READY
	# The first live texture and the worker-baked collision snapshot now represent
	# the native grid. Subsequent updates are driven only by real native changes.
	if _native_dirty_supported:
		simulation.call("clear_dirty")
	if _native_collision_dirty_supported:
		simulation.call("clear_collision_dirty")
	# A full-size static preview is no longer useful after activation. Downscaled
	# previews that never warm remain the cheap representation of distant chunks.
	_static_texture = null
	next_simulation_due_usec = Time.get_ticks_usec() + repaint_interval_usec
	return true

func collision_is_ready() -> bool:
	return _collision_rects.is_empty() or _collision_cursor * 4 >= _collision_rects.size()

func needs_collision_work() -> bool:
	if not collision_requested:
		return false
	return not collision_is_ready() or _native_collision_is_dirty()

func advance_collision(shape_budget: int, deadline_usec: int) -> bool:
	if not collision_requested:
		return true
	_ensure_nodes()
	# Do not interrupt an in-progress snapshot. If the simulation changes again while
	# shapes are being created, the native flag remains set and another snapshot is
	# queued immediately after this one completes.
	if collision_is_ready() and _native_collision_is_dirty():
		_begin_native_collision_rebuild()
	if _collision_rects.is_empty():
		return not _native_collision_is_dirty()
	var count: int = 0
	while _collision_cursor * 4 + 3 < _collision_rects.size() and count < maxi(1, shape_budget):
		var base: int = _collision_cursor * 4
		var x: float = float(_collision_rects[base])
		var y: float = float(_collision_rects[base + 1])
		var width: float = float(_collision_rects[base + 2])
		var height: float = float(_collision_rects[base + 3])
		var shape_rid: RID = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(shape_rid, Vector2(width * 0.5, height * 0.5))
		PhysicsServer2D.body_add_shape(
			_collision_root.get_rid(),
			shape_rid,
			Transform2D(0.0, Vector2(x + width * 0.5, y + height * 0.5))
		)
		_collision_shape_rids.append(shape_rid)
		_collision_cursor += 1
		count += 1
		if (count & 7) == 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	return collision_is_ready() and not _native_collision_is_dirty()

func simulation_due(now_usec: int) -> bool:
	return is_simulation_active() and now_usec >= next_simulation_due_usec

func run_simulation_tick(now_usec: int) -> void:
	if not is_simulation_active():
		return
	simulation.step(simulation_iterations)
	var changed: bool = bool(simulation.call("is_dirty")) if _native_dirty_supported else true
	if changed or _repaint_requested:
		_repaint()
		if _native_dirty_supported:
			simulation.call("clear_dirty")
	_repaint_requested = false
	next_simulation_due_usec = now_usec + repaint_interval_usec

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
	next_simulation_due_usec = mini(next_simulation_due_usec, Time.get_ticks_usec())

func request_repaint() -> void:
	if not _native_dirty_supported:
		_repaint_requested = true
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
	_collision_cursor = 0
	_collision_cell_size = 8
	_repaint_requested = false
	_native_dirty_supported = false
	_native_collision_dirty_supported = false
	_native_collision_rects_supported = false
	_element_ids = PackedInt32Array()
	_collision_rects = PackedInt32Array()
	_clear_collision()
	if _collision_root != null:
		_collision_root.collision_layer = 0
		_collision_root.collision_mask = 0
	# Keep a same-sized static ImageTexture as a tiny renderer-pool cache. Live
	# 512x512 simulation textures are released to avoid pool memory ballooning.
	_simulation_texture = null
	if _sprite != null:
		_sprite.texture = null
		_sprite.scale = Vector2.ONE
	visible = false

func _finish_element_transfer() -> void:
	warm_state = WarmState.READY_TO_UPLOAD
	_load_cursor = _element_ids.size()
	# Native ownership is established; release the 1 MiB PackedInt32Array before the
	# texture upload phase. Collision rectangles are tiny and remain for physics.
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

func _begin_native_collision_rebuild() -> void:
	if simulation == null or not _native_collision_rects_supported:
		return
	_collision_rects = simulation.call("get_collision_rects", _collision_cell_size)
	_collision_cursor = 0
	_clear_collision()
	if _native_collision_dirty_supported:
		simulation.call("clear_collision_dirty")

func _clear_collision() -> void:
	if _collision_root != null and is_instance_valid(_collision_root):
		PhysicsServer2D.body_clear_shapes(_collision_root.get_rid())
	for shape_rid: RID in _collision_shape_rids:
		if shape_rid.is_valid():
			PhysicsServer2D.free_rid(shape_rid)
	_collision_shape_rids.clear()

func _ensure_nodes() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "PixelTexture"
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	if _collision_root == null:
		_collision_root = StaticBody2D.new()
		_collision_root.name = "GeneratedCollision"
		add_child(_collision_root)
