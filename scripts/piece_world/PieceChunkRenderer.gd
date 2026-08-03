class_name PieceChunkRenderer
extends Node2D

## One streamed chunk. The PixelChunkCanvas starts as a static preview and is
## upgraded to a native simulation only when WorldManager schedules it.
var pixel_canvas: PixelChunkCanvas
var data: PieceChunkData
var show_debug: bool = false

func _ready() -> void:
	_ensure_canvas()
	z_index = 0

func setup(
	p_data: PieceChunkData,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	simulation_iterations: int = 1,
	repaint_hz: float = 15.0,
	maximum_collision_triangles: int = 6000,
	collision_cell_size: int = 8,
	release_visual_image_after_upload: bool = false
) -> void:
	data = p_data
	visible = true
	_ensure_canvas()
	position = Vector2(data.coord * PieceWorldConstants.CHUNK_SIZE).round()
	pixel_canvas.position = Vector2.ZERO
	pixel_canvas.setup(
		data,
		palette,
		enable_simulation,
		enable_collision,
		simulation_iterations,
		repaint_hz,
		maximum_collision_triangles,
		collision_cell_size
	)
	data.texture = null
	data.material_image = null
	# PixelChunkCanvas keeps copy-on-write references until native warmup/collision
	# completes, so the metadata object does not need duplicate large arrays.
	data.element_ids = PackedInt32Array()
	data.collision_rects = PackedInt32Array()
	if release_visual_image_after_upload:
		data.visual_image = null
		data.preview_image = null
	queue_redraw()

func set_simulation_active(active: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_simulation_active(active)

func set_warmup_requested(active: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_warmup_requested(active)

func set_collision_active(active: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_collision_active(active)

func is_simulation_active() -> bool:
	return pixel_canvas != null and pixel_canvas.is_simulation_active()

func needs_initialization() -> bool:
	return pixel_canvas != null and pixel_canvas.needs_initialization()

func is_initializing() -> bool:
	return pixel_canvas != null and pixel_canvas.is_initializing()

func begin_initialization() -> void:
	if pixel_canvas != null:
		pixel_canvas.begin_initialization()

func advance_initialization(pixel_budget: int, deadline_usec: int) -> bool:
	return pixel_canvas.advance_initialization(pixel_budget, deadline_usec) if pixel_canvas != null else true

func needs_texture_activation() -> bool:
	return pixel_canvas != null and pixel_canvas.needs_texture_activation()

func activate_simulation_texture() -> bool:
	return pixel_canvas.activate_simulation_texture() if pixel_canvas != null else false

func needs_collision_work() -> bool:
	return pixel_canvas != null and pixel_canvas.needs_collision_work()

func advance_collision(shape_budget: int, deadline_usec: int) -> bool:
	return pixel_canvas.advance_collision(shape_budget, deadline_usec) if pixel_canvas != null else true

func simulation_due(now_usec: int) -> bool:
	return pixel_canvas != null and pixel_canvas.simulation_due(now_usec)

func run_simulation_tick(now_usec: int) -> void:
	if pixel_canvas != null:
		pixel_canvas.run_simulation_tick(now_usec)

func get_cell(local_x: int, local_y: int) -> int:
	return pixel_canvas.get_cell(local_x, local_y) if pixel_canvas != null else 0

func set_cell(local_x: int, local_y: int, element_id: int) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_cell(local_x, local_y, element_id)

func request_repaint() -> void:
	if pixel_canvas != null:
		pixel_canvas.request_repaint()

func upload_mode_name() -> String:
	return pixel_canvas.upload_mode_name() if pixel_canvas != null else "not initialized"

func recycle_for_pool() -> void:
	data = null
	show_debug = false
	visible = false
	if pixel_canvas != null:
		pixel_canvas.recycle_for_pool()
	queue_redraw()

func _draw() -> void:
	if not show_debug or data == null:
		return
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE)),
		Color(0.1, 0.9, 1.0, 0.95), false, 2.0
	)
	for placement: PiecePlacement in data.placements:
		var rect: Rect2i = placement.pixel_rect(PieceWorldConstants.UNIT_SIZE)
		draw_rect(Rect2(Vector2(rect.position), Vector2(rect.size)), _phase_color(placement.phase), false, 2.0)

func _phase_color(phase: StringName) -> Color:
	match phase:
		&"anchor":
			return Color(1.0, 0.25, 0.25, 1.0)
		&"regular":
			return Color(0.2, 1.0, 0.35, 1.0)
		&"glue":
			return Color(1.0, 0.65, 0.1, 1.0)
		_:
			return Color(0.9, 0.9, 0.9, 1.0)

func _ensure_canvas() -> void:
	if pixel_canvas == null:
		pixel_canvas = PixelChunkCanvas.new()
		pixel_canvas.name = "PixelChunkCanvas"
		pixel_canvas.show_behind_parent = true
		add_child(pixel_canvas)
