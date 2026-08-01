class_name PixelChunkCanvas
extends Node2D

## Owns exactly one 512x512 sand-slide simulation and its displayed texture.
var simulation: SandSimulation
var chunk_data: PieceChunkData
var material_palette: MaterialPalette
var simulation_active: bool = true
var simulation_iterations: int = 1
var repaint_interval: float = 1.0 / 15.0
var build_static_collision: bool = true
var maximum_collision_triangles: int = 6000
var used_bulk_upload: bool = false
var fallback_loaded_cells: int = 0

var _sprite: Sprite2D
var _texture: ImageTexture
var _collision_root: StaticBody2D
var _repaint_accumulator: float = 0.0

func _ready() -> void:
	_ensure_nodes()
	set_process(simulation_active and simulation != null)

func setup(
	data: PieceChunkData,
	palette: MaterialPalette,
	enable_simulation: bool,
	enable_collision: bool,
	iterations: int = 1,
	repaint_hz: float = 15.0,
	max_collision_triangles: int = 6000
) -> void:
	chunk_data = data
	material_palette = palette
	simulation_active = enable_simulation
	build_static_collision = enable_collision
	simulation_iterations = maxi(1, iterations)
	repaint_interval = 1.0 / maxf(repaint_hz, 1.0)
	maximum_collision_triangles = maxi(0, max_collision_triangles)
	_repaint_accumulator = 0.0
	visible = true
	_ensure_nodes()
	_clear_collision()

	if chunk_data == null or chunk_data.material_image == null or chunk_data.material_image.is_empty():
		push_error("PixelChunkCanvas received no material image.")
		return
	if material_palette == null:
		push_error("PixelChunkCanvas received no MaterialPalette.")
		return

	simulation = SandSimulation.new()
	simulation.set_chunk_size(16)
	simulation.resize(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE)
	SandSimulationConfigurator.configure(simulation, material_palette)

	var element_ids: PackedInt32Array = material_palette.image_to_element_ids(chunk_data.material_image)
	_load_element_ids(element_ids)
	_repaint()
	if build_static_collision:
		_build_collision(element_ids)
	set_process(simulation_active)

func set_simulation_active(active: bool) -> void:
	simulation_active = active
	set_process(active and simulation != null)

func is_simulation_active() -> bool:
	return simulation_active and simulation != null

func get_cell(local_x: int, local_y: int) -> int:
	if simulation == null or local_x < 0 or local_y < 0:
		return 0
	if local_x >= PieceWorldConstants.CHUNK_SIZE or local_y >= PieceWorldConstants.CHUNK_SIZE:
		return 0
	return simulation.get_cell(local_y, local_x)

func set_cell(local_x: int, local_y: int, element_id: int) -> void:
	if simulation == null or local_x < 0 or local_y < 0:
		return
	if local_x >= PieceWorldConstants.CHUNK_SIZE or local_y >= PieceWorldConstants.CHUNK_SIZE:
		return
	simulation.draw_cell(local_y, local_x, clampi(element_id, 0, 4096))

func request_repaint() -> void:
	_repaint()

func upload_mode_name() -> String:
	if used_bulk_upload:
		return "native bulk"
	return "GDScript fallback (%d non-air cells)" % fallback_loaded_cells

func recycle_for_pool() -> void:
	set_process(false)
	simulation_active = false
	simulation = null
	chunk_data = null
	material_palette = null
	used_bulk_upload = false
	fallback_loaded_cells = 0
	_repaint_accumulator = 0.0
	_clear_collision()
	_texture = null
	if _sprite != null:
		_sprite.texture = null
	visible = false

func _process(delta: float) -> void:
	if not simulation_active or simulation == null:
		return
	_repaint_accumulator += delta
	if _repaint_accumulator < repaint_interval:
		return
	_repaint_accumulator = fmod(_repaint_accumulator, repaint_interval)
	simulation.step(simulation_iterations)
	_repaint()

func _load_element_ids(element_ids: PackedInt32Array) -> void:
	var expected: int = PieceWorldConstants.CHUNK_SIZE * PieceWorldConstants.CHUNK_SIZE
	if element_ids.size() != expected:
		push_error("Chunk material image produced %d IDs; expected %d." % [element_ids.size(), expected])
		return
	used_bulk_upload = simulation.has_method("set_cells_bulk")
	fallback_loaded_cells = 0
	if used_bulk_upload:
		simulation.call("set_cells_bulk", element_ids)
		return
	# Compatibility path for the checked-in Windows DLL, which predates set_cells_bulk.
	var width: int = PieceWorldConstants.CHUNK_SIZE
	for index: int in range(element_ids.size()):
		var element_id: int = element_ids[index]
		if element_id == 0:
			continue
		fallback_loaded_cells += 1
		simulation.draw_cell(floori(float(index) / float(width)), index % width, element_id)

func _repaint() -> void:
	if simulation == null:
		return
	var width: int = simulation.get_width()
	var height: int = simulation.get_height()
	var rgba: PackedByteArray = simulation.get_color_image(true)
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
		_sprite.texture = _texture
	else:
		_texture.update(image)

func _build_collision(element_ids: PackedInt32Array) -> void:
	_clear_collision()
	if maximum_collision_triangles <= 0:
		return
	var width: int = PieceWorldConstants.CHUNK_SIZE
	var height: int = PieceWorldConstants.CHUNK_SIZE
	var mask_bytes := PackedByteArray()
	mask_bytes.resize(width * height * 4)
	for index: int in range(element_ids.size()):
		if not material_palette.is_solid_element_id(element_ids[index]):
			continue
		var byte_index: int = index * 4
		mask_bytes[byte_index] = 255
		mask_bytes[byte_index + 1] = 255
		mask_bytes[byte_index + 2] = 255
		mask_bytes[byte_index + 3] = 255
	var mask_image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, mask_bytes)
	var builder := HoledCollisionBuilder2D.new()
	builder.alpha_threshold = 0.1
	builder.outline_epsilon = 1.5
	builder.min_island_area = 8.0
	builder.min_hole_area = 8.0
	var triangles: Array[PackedVector2Array] = builder.build_triangles_from_image(mask_image)
	if builder.last_failed_island_count > 0:
		push_warning("Skipped incomplete collision for chunk %s." % str(chunk_data.coord if chunk_data != null else Vector2i.ZERO))
		return
	if triangles.size() > maximum_collision_triangles:
		push_warning("Chunk %s collision has %d triangles; collision was skipped." % [str(chunk_data.coord if chunk_data != null else Vector2i.ZERO), triangles.size()])
		return
	for triangle: PackedVector2Array in triangles:
		if triangle.size() < 3:
			continue
		var polygon := CollisionPolygon2D.new()
		polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		polygon.polygon = triangle
		_collision_root.add_child(polygon)

func _clear_collision() -> void:
	if _collision_root == null:
		return
	for child: Node in _collision_root.get_children():
		child.free()

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
