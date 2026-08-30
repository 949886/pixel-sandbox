class_name SpecialPieceImageBuilder
extends RefCounted

# Thread-safe image builder for image-based special chunks. It mirrors
# SpecialPieceRenderer's old CPU image construction without touching the scene tree
# or creating ImageTexture objects.

const UNIT_SIZE: int = PieceWorldConstants.UNIT_SIZE
const UNITS_PER_CHUNK: int = PieceWorldConstants.CHUNK_UNITS
const CHUNK_SIZE: int = PieceWorldConstants.CHUNK_SIZE

static func build(placement: SpecialChunkPlacement) -> Image:
	if placement == null or placement.chunk_def == null:
		return Image.create_empty(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	var size_px: Vector2i = placement.size_in_chunks * CHUNK_SIZE
	var img: Image = Image.create_empty(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var def: SpecialChunkDef = placement.chunk_def
	var rock: Color = def.generated_rock_color
	var dark: Color = def.generated_dark_color
	var accent: Color = def.generated_accent_color
	match def.layout_style:
		SpecialChunkDef.LayoutStyle.SURFACE_GROUND:
			_build_surface_ground(img, def, placement, rock, dark)
		SpecialChunkDef.LayoutStyle.SURFACE_ENTRANCE:
			_build_surface_entrance(img, def, placement, rock, dark)
		_:
			_fill_noise(img, rock, dark, placement)
			_carve_room(img, def)
			_draw_structure_details(img, def, accent, dark)
	return img


static func _build_surface_ground(
	img: Image, def: SpecialChunkDef, placement: SpecialChunkPlacement, rock: Color, dark: Color
) -> void:
	img.fill(Color.TRANSPARENT)
	var rng: RandomNumberGenerator = SeedUtil.rng(
		placement.seed,
		"surface_ground_%s_%s" % [str(def.id), str(placement.origin_chunk)]
	)
	var origin_world := placement.origin_chunk * CHUNK_SIZE
	var width: int = img.get_width()
	var height: int = img.get_height()
	for x: int in range(width):
		var world_x: int = origin_world.x + x
		var surface_world_y: int = _surface_world_y(def, placement.origin_chunk.y, world_x)
		var surface_y: int = clampi(surface_world_y - origin_world.y, 0, height)
		for y: int in range(surface_y, height):
			var color: Color = dark if rng.randf() < 0.035 else rock
			img.set_pixel(x, y, color)
		for grass_y: int in range(surface_y, mini(surface_y + 3, height)):
			img.set_pixel(x, grass_y, def.generated_feature_color)


static func _build_surface_entrance(
	img: Image, def: SpecialChunkDef, placement: SpecialChunkPlacement, rock: Color, dark: Color
) -> void:
	_fill_noise(img, rock, dark, placement)
	var origin_world := placement.origin_chunk * CHUNK_SIZE
	var width: int = img.get_width()
	var height: int = img.get_height()
	# Carve the same globally sampled surface profile as neighboring ground chunks,
	# so authored surface pieces do not produce visible height seams at chunk edges.
	for x: int in range(width):
		var world_x: int = origin_world.x + x
		var surface_world_y: int = _surface_world_y(def, placement.origin_chunk.y, world_x)
		var surface_y: int = clampi(surface_world_y - origin_world.y, 0, height)
		_carve_rect(img, Rect2i(Vector2i(x, 0), Vector2i(1, surface_y)))
		for grass_y: int in range(surface_y, mini(surface_y + 3, height)):
			img.set_pixel(x, grass_y, def.generated_feature_color)

	var opening: int = maxi(72, int(round(float(CHUNK_SIZE) * def.entrance_opening_ratio)))
	var slope_width: int = maxi(96, int(round(float(CHUNK_SIZE) * def.entrance_slope_width_ratio)))
	var start_x: int = maxi(24, width - slope_width - 48)
	var start_world_x: int = origin_world.x + start_x
	var start_surface_y: int = _surface_world_y(def, placement.origin_chunk.y, start_world_x) - origin_world.y
	var target_center_y: int = maxi(start_surface_y + 48, height - int(CHUNK_SIZE * 0.42))
	# A broad right/down passage communicates the intended direction immediately.
	for x: int in range(start_x, width):
		var t: float = clampf(float(x - start_x) / float(maxi(1, width - start_x - 1)), 0.0, 1.0)
		var center_y: int = int(round(lerpf(float(start_surface_y + 24), float(target_center_y), t)))
		var half_height: int = int(round(float(opening) * (0.18 + t * 0.12)))
		_carve_rect(
			img,
			Rect2i(
				Vector2i(x, maxi(0, center_y - half_height)),
				Vector2i(1, mini(height, half_height * 2 + 1))
			)
		)

	# Continue the passage through the lower entrance chunk and all the way to its
	# bottom socket. The runtime normal chunk below then receives the socket profile
	# from SpecialChunkPlanner and generates a matching opening.
	var shaft_width: int = clampi(int(round(float(opening) * 0.62)), 72, CHUNK_SIZE - 48)
	var shaft_half_width: int = int(shaft_width / 2)
	var shaft_center_x: int = clampi(
		width - int(round(float(opening) * 0.52)),
		shaft_half_width,
		width - shaft_half_width
	)
	var shaft_top: int = maxi(CHUNK_SIZE, target_center_y - int(opening * 0.16))
	_carve_rect(
		img,
		Rect2i(
			Vector2i(shaft_center_x - shaft_half_width, shaft_top),
			Vector2i(shaft_width, height - shaft_top)
		)
	)


static func _surface_world_y(def: SpecialChunkDef, surface_chunk_y: int, world_x: int) -> int:
	var base_world_y: float = float(surface_chunk_y * CHUNK_SIZE) + float(CHUNK_SIZE) * def.surface_ground_ratio
	var variation: float = float(CHUNK_SIZE) * def.surface_height_variation
	var x: float = float(world_x)
	var wave: float = sin(x * 0.012) * variation * 0.55 + sin(x * 0.031 + 1.7) * variation * 0.25
	return int(round(base_world_y + wave))


static func _fill_noise(img: Image, rock: Color, dark: Color, placement: SpecialChunkPlacement) -> void:
	img.fill(rock)
	var rng: RandomNumberGenerator = SeedUtil.rng(placement.seed, "special_piece_%s" % str(placement.id))
	var pixel_count: int = int(float(img.get_width() * img.get_height()) * 0.018)
	for i: int in range(pixel_count):
		var p: Vector2i = Vector2i(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1))
		img.set_pixelv(p, dark)

static func _carve_room(img: Image, def: SpecialChunkDef) -> void:
	var margin: int = int(UNIT_SIZE / 2)
	var room_rect := Rect2i(Vector2i(margin, margin), img.get_size() - Vector2i(margin * 2, margin * 2))
	_carve_rect(img, room_rect)
	for local_x: int in range(def.size_in_chunks.x):
		var profile: Array[PieceSocket.Socket] = def.socket_profile(&"top", Vector2i(local_x, 0), UNITS_PER_CHUNK)
		_carve_horizontal_profile(img, profile, local_x * CHUNK_SIZE, 0, true)
		profile = def.socket_profile(&"bottom", Vector2i(local_x, 0), UNITS_PER_CHUNK)
		_carve_horizontal_profile(img, profile, local_x * CHUNK_SIZE, img.get_height() - 1, false)
	for local_y: int in range(def.size_in_chunks.y):
		var profile: Array[PieceSocket.Socket] = def.socket_profile(&"left", Vector2i(0, local_y), UNITS_PER_CHUNK)
		_carve_vertical_profile(img, profile, 0, local_y * CHUNK_SIZE, true)
		profile = def.socket_profile(&"right", Vector2i(0, local_y), UNITS_PER_CHUNK)
		_carve_vertical_profile(img, profile, img.get_width() - 1, local_y * CHUNK_SIZE, false)

static func _carve_horizontal_profile(img: Image, profile: Array[PieceSocket.Socket], offset_x: int, edge_y: int, from_top: bool) -> void:
	for i: int in range(profile.size()):
		var socket: PieceSocket.Socket = PieceSocket.from_value(profile[i])
		if not PieceSocket.is_open(socket):
			continue
		for pattern: Vector2i in PieceSocket.open_patterns(socket, UNIT_SIZE):
			var center_x: int = offset_x + i * UNIT_SIZE + pattern.x
			var width: int = pattern.y
			var y: int = 0 if from_top else img.get_height() - UNIT_SIZE
			_carve_rect(img, Rect2i(Vector2i(center_x - int(width / 2), y), Vector2i(width, UNIT_SIZE)))

static func _carve_vertical_profile(img: Image, profile: Array[PieceSocket.Socket], edge_x: int, offset_y: int, from_left: bool) -> void:
	for i: int in range(profile.size()):
		var socket: PieceSocket.Socket = PieceSocket.from_value(profile[i])
		if not PieceSocket.is_open(socket):
			continue
		for pattern: Vector2i in PieceSocket.open_patterns(socket, UNIT_SIZE):
			var center_y: int = offset_y + i * UNIT_SIZE + pattern.x
			var width: int = pattern.y
			var x: int = 0 if from_left else img.get_width() - UNIT_SIZE
			_carve_rect(img, Rect2i(Vector2i(x, center_y - int(width / 2)), Vector2i(UNIT_SIZE, width)))

static func _draw_structure_details(img: Image, def: SpecialChunkDef, accent: Color, dark: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	_draw_rect(img, Rect2i(Vector2i(int(w / 4), int(h * 0.72)), Vector2i(int(w / 2), 18)), accent)
	_draw_rect(img, Rect2i(Vector2i(int(w / 3), int(h / 2)), Vector2i(18, int(h / 4))), dark)
	_draw_rect(img, Rect2i(Vector2i(int(w * 2.0 / 3.0), int(h / 2)), Vector2i(18, int(h / 4))), dark)
	match def.chunk_kind:
		SpecialChunkDef.ChunkKind.TREASURE:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 28, int(h / 2) - 18), Vector2i(56, 36)), def.generated_feature_color)
		SpecialChunkDef.ChunkKind.SHRINE:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 34, int(h / 2) - 48), Vector2i(68, 96)), def.generated_feature_color)
		SpecialChunkDef.ChunkKind.HALL:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 90, int(h / 2) - 12), Vector2i(180, 24)), def.generated_feature_color)
		_:
			_draw_rect(img, Rect2i(Vector2i(int(w / 2) - 24, int(h / 2) - 24), Vector2i(48, 48)), accent)

static func _carve_rect(img: Image, rect: Rect2i) -> void:
	var start_x: int = maxi(rect.position.x, 0)
	var start_y: int = maxi(rect.position.y, 0)
	var end_x: int = mini(rect.end.x, img.get_width())
	var end_y: int = mini(rect.end.y, img.get_height())
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			img.set_pixel(x, y, Color.TRANSPARENT)

static func _draw_rect(img: Image, rect: Rect2i, color: Color) -> void:
	var start_x: int = maxi(rect.position.x, 0)
	var start_y: int = maxi(rect.position.y, 0)
	var end_x: int = mini(rect.end.x, img.get_width())
	var end_y: int = mini(rect.end.y, img.get_height())
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			img.set_pixel(x, y, color)
