class_name SpecialPieceRenderer
extends Node2D

## Staged renderer for a multi-chunk special structure.
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

var placement: SpecialChunkPlacement
var chunk_canvases: Dictionary = {}
var _canvas_pool: Array[PixelChunkCanvas] = []
var debug_label: Label
var collision_debug_visible: bool = false

func setup(
	p_placement: SpecialChunkPlacement,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	simulation_iterations: int = 1,
	simulation_hz: float = 60.0,
	repaint_hz: float = 60.0,
	maximum_collision_triangles: int = 6000,
	collision_cell_size: int = 1,
	collision_sector_size: int = 64,
	collision_dynamic_rebuild_hz: float = 20.0,
	preview_downscale_factor: int = 1,
	keep_cpu_visual_images: bool = false
) -> void:
	var chunks: Array[PieceChunkData] = SpecialChunkImageWorker.bake_placement(
		p_placement,
		palette,
		collision_cell_size,
		preview_downscale_factor,
		enable_collision
	)
	setup_with_chunk_data(
		p_placement, chunks, palette, enable_simulation, enable_collision,
		simulation_iterations, simulation_hz, repaint_hz, maximum_collision_triangles,
		collision_cell_size, collision_sector_size, collision_dynamic_rebuild_hz, keep_cpu_visual_images
	)

func setup_with_chunk_data(
	p_placement: SpecialChunkPlacement,
	chunks: Array[PieceChunkData],
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	simulation_iterations: int = 1,
	simulation_hz: float = 60.0,
	repaint_hz: float = 60.0,
	maximum_collision_triangles: int = 6000,
	collision_cell_size: int = 1,
	collision_sector_size: int = 64,
	collision_dynamic_rebuild_hz: float = 20.0,
	keep_cpu_visual_images: bool = false
) -> void:
	placement = p_placement
	visible = true
	chunk_canvases.clear()
	position = Vector2(placement.origin_chunk * CHUNK_SIZE)
	var used_count: int = 0
	for data: PieceChunkData in chunks:
		if data == null:
			continue
		var canvas: PixelChunkCanvas = _obtain_canvas(used_count)
		used_count += 1
		var local_coord: Vector2i = data.coord - placement.origin_chunk
		canvas.name = "PixelChunk_%d_%d" % [data.coord.x, data.coord.y]
		canvas.position = Vector2(local_coord * CHUNK_SIZE)
		canvas.visible = true
		canvas.setup(
			data,
			palette,
			enable_simulation,
			enable_collision,
			simulation_iterations,
			simulation_hz,
			repaint_hz,
			maximum_collision_triangles,
			collision_cell_size,
			collision_sector_size,
			collision_dynamic_rebuild_hz
		)
		canvas.set_collision_debug_visible(collision_debug_visible)
		if not keep_cpu_visual_images:
			data.visual_image = null
			data.preview_image = null
		data.material_image = null
		data.element_ids = PackedInt32Array()
		data.collision_rects = PackedInt32Array()
		chunk_canvases[data.coord] = canvas
	for index: int in range(used_count, _canvas_pool.size()):
		_canvas_pool[index].recycle_for_pool()
	_ensure_debug_label()


func set_collision_debug_visible(enabled: bool) -> void:
	collision_debug_visible = enabled
	for canvas: PixelChunkCanvas in _canvas_pool:
		if canvas != null:
			canvas.set_collision_debug_visible(enabled)

func get_chunk_canvas(world_coord: Vector2i) -> PixelChunkCanvas:
	return chunk_canvases.get(world_coord, null) as PixelChunkCanvas

func recycle_for_pool() -> void:
	placement = null
	chunk_canvases.clear()
	visible = false
	for canvas: PixelChunkCanvas in _canvas_pool:
		if canvas != null:
			canvas.recycle_for_pool()
	if debug_label != null:
		debug_label.visible = false
		debug_label.text = ""

func _obtain_canvas(index: int) -> PixelChunkCanvas:
	while _canvas_pool.size() <= index:
		var canvas := PixelChunkCanvas.new()
		canvas.show_behind_parent = true
		add_child(canvas)
		_canvas_pool.append(canvas)
	return _canvas_pool[index]

func _ensure_debug_label() -> void:
	if debug_label == null:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.position = Vector2(12, 12)
		debug_label.add_theme_font_size_override("font_size", 12)
		debug_label.add_theme_color_override("font_color", Color(1.0, 0.9, 1.0, 0.92))
		add_child(debug_label)
	# Labels are opt-in through the debug system; keeping one visible on every special
	# structure adds unnecessary canvas-item work in release gameplay.
	debug_label.visible = false
	if placement != null and placement.chunk_def != null:
		debug_label.text = "%s\nPixel special %s" % [placement.chunk_def.display_name, str(placement.size_in_chunks)]
