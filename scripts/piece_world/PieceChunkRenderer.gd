class_name PieceChunkRenderer
extends Node2D

## Runtime renderer for one generated chunk. The original Sprite2D upload path has
## been replaced by exactly one PixelChunkCanvas/SandSimulation per chunk.
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
		maximum_collision_triangles
	)
	# The native simulation owns material state after upload. The authored visual
	# image is optional CPU-side debug data controlled by the runtime profile.
	data.texture = null
	data.material_image = null
	if release_visual_image_after_upload:
		data.visual_image = null
	queue_redraw()

func set_simulation_active(active: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_simulation_active(active)

func is_simulation_active() -> bool:
	return pixel_canvas != null and pixel_canvas.is_simulation_active()

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
