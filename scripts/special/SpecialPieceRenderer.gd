class_name SpecialPieceRenderer
extends Node2D

## Pixel-engine renderer for a multi-chunk special structure. The structure image is
## split into 512x512 regions; every occupied world chunk owns one PixelChunkCanvas.
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

var placement: SpecialChunkPlacement
var chunk_canvases: Dictionary = {}
var _canvas_pool: Array[PixelChunkCanvas] = []
var debug_label: Label

func setup(
	p_placement: SpecialChunkPlacement,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	simulation_iterations: int = 1,
	repaint_hz: float = 15.0,
	maximum_collision_triangles: int = 6000
) -> void:
	setup_with_image(
		p_placement,
		SpecialPieceImageBuilder.build(p_placement),
		palette,
		enable_simulation,
		enable_collision,
		simulation_iterations,
		repaint_hz,
		maximum_collision_triangles
	)

func setup_with_image(
	p_placement: SpecialChunkPlacement,
	img: Image,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	simulation_iterations: int = 1,
	repaint_hz: float = 15.0,
	maximum_collision_triangles: int = 6000
) -> void:
	placement = p_placement
	visible = true
	chunk_canvases.clear()
	position = Vector2(placement.origin_chunk * CHUNK_SIZE)

	var expected_size: Vector2i = placement.size_in_chunks * CHUNK_SIZE
	var source: Image = img
	if source == null or source.is_empty():
		source = Image.create_empty(expected_size.x, expected_size.y, false, Image.FORMAT_RGBA8)
		source.fill(Color.TRANSPARENT)
	elif source.get_size() != expected_size:
		source = source.duplicate()
		source.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_NEAREST)
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source.duplicate()
		source.convert(Image.FORMAT_RGBA8)

	var used_count: int = 0
	for local_y: int in range(placement.size_in_chunks.y):
		for local_x: int in range(placement.size_in_chunks.x):
			var canvas: PixelChunkCanvas = _obtain_canvas(used_count)
			used_count += 1
			var world_coord: Vector2i = placement.origin_chunk + Vector2i(local_x, local_y)
			canvas.name = "PixelChunk_%d_%d" % [world_coord.x, world_coord.y]
			canvas.position = Vector2(local_x * CHUNK_SIZE, local_y * CHUNK_SIZE)
			canvas.visible = true

			var crop: Image = Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
			crop.fill(Color.TRANSPARENT)
			crop.blit_rect(
				source,
				Rect2i(Vector2i(local_x * CHUNK_SIZE, local_y * CHUNK_SIZE), Vector2i(CHUNK_SIZE, CHUNK_SIZE)),
				Vector2i.ZERO
			)
			var data := PieceChunkData.new(world_coord)
			data.biome_id = placement.biome_id
			data.special_chunk_id = placement.chunk_def.id if placement.chunk_def != null else placement.id
			data.special_chunk_origin = placement.origin_chunk
			data.special_chunk_size = placement.size_in_chunks
			data.visual_image = crop
			data.material_image = crop.duplicate()
			canvas.setup(
				data,
				palette,
				enable_simulation,
				enable_collision,
				simulation_iterations,
				repaint_hz,
				maximum_collision_triangles
			)
			# The native simulation now owns the material state.
			data.visual_image = null
			data.material_image = null
			chunk_canvases[world_coord] = canvas

	for index: int in range(used_count, _canvas_pool.size()):
		_canvas_pool[index].recycle_for_pool()
	_ensure_debug_label()

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
	debug_label.visible = true
	if placement != null and placement.chunk_def != null:
		debug_label.text = "%s\nPixel special %s" % [placement.chunk_def.display_name, str(placement.size_in_chunks)]
