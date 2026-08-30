class_name WorldStructureBuilder
extends RefCounted

# Builds a deterministic chunk-level plan inside the authored WorldLayout. The
# layout decides which cells exist and which biome owns them; this builder only
# decides topology (main path, branches and chambers) for those cells.

var world_seed: int = 12345
var config: WorldGenConfig
var world_layout: WorldLayoutSnapshot
var rng: RandomNumberGenerator
var structure: WorldStructure
var profile: WorldStructureProfile
var chamber_counter: int = 0
var layout_bounds: Rect2i = Rect2i()


func _init(
	p_world_seed: int,
	p_config: WorldGenConfig = null,
	p_world_layout: WorldLayoutSnapshot = null
) -> void:
	world_seed = p_world_seed
	config = p_config
	world_layout = p_world_layout
	profile = config.structure_profile if config != null else null
	if profile == null:
		profile = WorldStructureProfile.new()
	layout_bounds = world_layout.used_rect if world_layout != null else Rect2i()
	rng = SeedUtil.rng(world_seed, "world_structure_v3_layout_bounds")


func build() -> WorldStructure:
	structure = WorldStructure.new()
	if world_layout == null or not world_layout.is_valid() or layout_bounds.size.x <= 0 or layout_bounds.size.y <= 0:
		push_error("WorldStructureBuilder: WorldLayoutSnapshot is missing or empty.")
		return structure
	_apply_layout_bounds()
	_fill_default_nodes()
	_build_main_path()
	_build_side_branches()
	_place_chambers()
	return structure


func _apply_layout_bounds() -> void:
	structure.min_x = layout_bounds.position.x
	structure.min_y = layout_bounds.position.y
	structure.max_x = layout_bounds.end.x - 1
	structure.max_y = layout_bounds.end.y - 1


func _fill_default_nodes() -> void:
	# Iterate the authored cells directly. The bounding rectangle is only an A* /
	# debug convenience and must never create world cells inside VOID holes.
	var coords: Array = world_layout.biome_by_cell.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	for coord_value: Variant in coords:
		var coord: Vector2i = coord_value
		var biome_id: StringName = _biome_for_coord(coord)
		if biome_id == &"":
			continue
		var node := WorldStructureNode.new(coord, biome_id, BiomeMap.ChunkType.SOLID)
		node.add_tag(&"structure_v3")
		structure.set_node(node)


func _build_main_path() -> void:
	var start: Variant = _main_path_anchor_cell(true)
	var finish: Variant = _main_path_anchor_cell(false)
	if not start is Vector2i:
		start = _extreme_valid_cell(true)
	if not finish is Vector2i:
		finish = _extreme_valid_cell(false)
	if not start is Vector2i or not finish is Vector2i:
		return
	var path: Array[Vector2i] = _find_layout_path(start, finish)
	if path.is_empty():
		push_warning("WorldStructureBuilder: Could not find an authored-layout main path.")
		return
	var previous: Variant = null
	for coord: Vector2i in path:
		_mark_main_path(coord)
		structure.set_main_path_x(coord.y, coord.x)
		if previous is Vector2i:
			_connect(previous, coord)
		previous = coord
	for coord: Vector2i in path:
		_mark_path_shoulders(coord)


func _main_path_anchor_cell(start_anchor: bool) -> Variant:
	if config == null or config.world_definition == null or world_layout == null:
		return null
	var anchor_id: StringName = config.world_definition.main_path_start_anchor_id \
		if start_anchor else config.world_definition.main_path_end_anchor_id
	if anchor_id == &"":
		return null
	var cell: Variant = world_layout.get_anchor_cell(anchor_id)
	if cell is Vector2i and structure.has_node(cell):
		return cell
	return null


func _extreme_valid_cell(top: bool) -> Variant:
	var best: Variant = null
	for coord_value: Variant in structure.nodes.keys():
		var coord: Vector2i = coord_value
		if best == null:
			best = coord
			continue
		var current: Vector2i = best
		if top:
			if coord.y < current.y or (coord.y == current.y and absi(coord.x) < absi(current.x)):
				best = coord
		else:
			if coord.y > current.y or (coord.y == current.y and absi(coord.x) < absi(current.x)):
				best = coord
	return best


func _find_layout_path(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not structure.has_node(start) or not structure.has_node(finish):
		return result
	if layout_bounds.size.x <= 0 or layout_bounds.size.y <= 0:
		return result
	var grid := AStarGrid2D.new()
	grid.region = layout_bounds
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var weight_rng: RandomNumberGenerator = SeedUtil.rng(world_seed, "world_structure_main_path_weights")
	for y: int in range(layout_bounds.position.y, layout_bounds.end.y):
		for x: int in range(layout_bounds.position.x, layout_bounds.end.x):
			var coord := Vector2i(x, y)
			if not structure.has_node(coord):
				grid.set_point_solid(coord, true)
				continue
			var biome_config: BiomeConfig = _biome_config_for_coord(coord)
			var wander: float = biome_config.structure_main_path_wander_chance if biome_config != null else 0.0
			grid.set_point_weight_scale(coord, 1.0 + weight_rng.randf() * (0.15 + wander * 1.25))
	var raw_path: Array[Vector2i] = grid.get_id_path(start, finish)
	for coord: Vector2i in raw_path:
		result.append(coord)
	return result


func _mark_main_path(coord: Vector2i) -> void:
	var node := _node(coord)
	if node == null:
		return
	node.chunk_type = BiomeMap.ChunkType.MAIN_PATH
	node.add_tag(&"main_path")
	node.add_tag(&"path_core")


func _mark_path_shoulders(coord: Vector2i) -> void:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		if rng.randf() > profile.shoulder_chance:
			continue
		var shoulder_coord: Vector2i = coord + direction
		var node := _node(shoulder_coord)
		if node == null or node.chunk_type == BiomeMap.ChunkType.MAIN_PATH:
			continue
		node.chunk_type = BiomeMap.ChunkType.CAVE
		node.add_tag(&"path_shoulder")
		_connect(coord, shoulder_coord)


func _build_side_branches() -> void:
	var min_y: int = layout_bounds.position.y + profile.branch_start_offset_y
	var max_y: int = layout_bounds.end.y - 1 - profile.branch_end_margin_y
	var y: int = min_y
	while y <= max_y:
		if not structure.main_path_x_by_y.has(y):
			y += 1
			continue
		var start := Vector2i(structure.get_main_path_x(y), y)
		var biome_config: BiomeConfig = _biome_config_for_coord(start)
		if biome_config != null and rng.randf() < biome_config.structure_branch_chance:
			var dir: int = -1 if rng.randf() < 0.5 else 1
			var length: int = rng.randi_range(2, maxi(2, biome_config.structure_branch_max_length))
			_build_branch(start, dir, length, rng.randf() < biome_config.structure_loop_chance)
		y += rng.randi_range(profile.branch_row_advance_min, profile.branch_row_advance_max)


func _build_branch(start: Vector2i, dir: int, length: int, make_loop: bool) -> void:
	var current := start
	for i: int in range(1, length + 1):
		var step_y: int = 1 if i > 1 and rng.randf() < profile.branch_vertical_step_chance else 0
		var next := current + Vector2i(dir, step_y)
		if not _inside(next):
			break
		var node := _node(next)
		if node == null:
			break
		if node.chunk_type != BiomeMap.ChunkType.MAIN_PATH and node.chunk_type != BiomeMap.ChunkType.CHAMBER:
			node.chunk_type = BiomeMap.ChunkType.BRANCH
			node.add_tag(&"branch")
		if make_loop:
			node.add_tag(&"loop_branch")
		_connect(current, next)
		current = next
	if make_loop:
		var target: Variant = _nearest_main_path_cell(current)
		if target is Vector2i:
			_carve_corridor(current, target, &"loop_branch")
	else:
		var end_node := _node(current)
		if end_node != null and current != start:
			end_node.add_tag(&"branch_end")


func _nearest_main_path_cell(from_coord: Vector2i) -> Variant:
	var best: Variant = null
	var best_distance: int = 2147483647
	for y_value: Variant in structure.main_path_x_by_y.keys():
		var y: int = int(y_value)
		if absi(y - from_coord.y) > profile.loop_target_depth_max + 2:
			continue
		var coord := Vector2i(structure.get_main_path_x(y), y)
		var distance: int = int(from_coord.distance_squared_to(coord))
		if distance < best_distance:
			best_distance = distance
			best = coord
	return best


func _place_chambers() -> void:
	var start_y: int = layout_bounds.position.y + profile.chamber_start_offset_y
	var end_y: int = layout_bounds.end.y - profile.chamber_end_margin_y
	for y: int in range(start_y, end_y, profile.chamber_row_step):
		if not structure.main_path_x_by_y.has(y):
			continue
		var main := Vector2i(structure.get_main_path_x(y), y)
		var biome_id: StringName = _biome_for_coord(main)
		var biome_config: BiomeConfig = _biome_config_for_coord(main)
		if biome_config == null or rng.randf() > biome_config.structure_chamber_chance:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var offset: int = rng.randi_range(profile.chamber_horizontal_offset_min, profile.chamber_horizontal_offset_max)
		var size := _pick_chamber_size(biome_id)
		var origin := main + Vector2i(side * offset, rng.randi_range(-profile.chamber_vertical_jitter, profile.chamber_vertical_jitter))
		origin.x = clampi(origin.x, layout_bounds.position.x, layout_bounds.end.x - size.x)
		origin.y = clampi(origin.y, layout_bounds.position.y, layout_bounds.end.y - size.y)
		if not _can_place_chamber(origin, size, biome_id):
			continue
		_mark_chamber(origin, size)
		var entrance := Vector2i(origin.x if side > 0 else origin.x + size.x - 1, origin.y + int(size.y / 2))
		_carve_corridor(main, entrance, &"chamber_connector")


func _pick_chamber_size(biome_id: StringName) -> Vector2i:
	var biome_config: BiomeConfig = config.get_biome_config(biome_id) if config != null else null
	if biome_config == null or biome_config.structure_chamber_sizes.is_empty():
		return Vector2i.ONE
	return biome_config.structure_chamber_sizes[rng.randi_range(0, biome_config.structure_chamber_sizes.size() - 1)]


func _can_place_chamber(origin: Vector2i, size: Vector2i, biome_id: StringName) -> bool:
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			var node := _node(Vector2i(x, y))
			if node == null or node.biome_id != biome_id:
				return false
			if node.chunk_type == BiomeMap.ChunkType.MAIN_PATH or node.chunk_type == BiomeMap.ChunkType.CHAMBER:
				return false
	return true


func _mark_chamber(origin: Vector2i, size: Vector2i) -> void:
	chamber_counter += 1
	var chamber_id: StringName = StringName("chamber_%03d" % chamber_counter)
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			var coord := Vector2i(x, y)
			var node := _node(coord)
			if node == null:
				continue
			node.chunk_type = BiomeMap.ChunkType.CHAMBER
			node.chamber_id = chamber_id
			node.chamber_origin = origin
			node.chamber_size = size
			node.add_tag(&"chamber")
			if size.x <= 2 and size.y <= 2:
				node.add_tag(&"chamber_edge")
			else:
				var is_edge: bool = x == origin.x or y == origin.y or x == origin.x + size.x - 1 or y == origin.y + size.y - 1
				node.add_tag(&"chamber_edge" if is_edge else &"chamber_interior")
			node.add_tag(StringName("chamber_%dx%d" % [size.x, size.y]))
			var right := coord + Vector2i.RIGHT
			var bottom := coord + Vector2i.DOWN
			if right.x < origin.x + size.x:
				_connect(coord, right)
			if bottom.y < origin.y + size.y:
				_connect(coord, bottom)


func _carve_corridor(from_coord: Vector2i, to_coord: Vector2i, tag: StringName) -> void:
	# Corridor routing uses the authored-layout graph. A greedy x/y walk can get
	# trapped by VOID holes or irregular biome boundaries.
	var path: Array[Vector2i] = _find_layout_path(from_coord, to_coord)
	if path.size() < 2:
		return
	var previous: Vector2i = path[0]
	for index: int in range(1, path.size()):
		var coord: Vector2i = path[index]
		_mark_corridor_node(coord, tag)
		_connect(previous, coord)
		previous = coord


func _mark_corridor_node(coord: Vector2i, tag: StringName) -> void:
	var node := _node(coord)
	if node == null:
		return
	if node.chunk_type == BiomeMap.ChunkType.SOLID:
		node.chunk_type = BiomeMap.ChunkType.BRANCH
	node.add_tag(tag)
	if tag == &"chamber_connector":
		node.add_tag(&"branch")


func _connect(a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	var delta := b - a
	if absi(delta.x) + absi(delta.y) != 1:
		return
	var node_a := _node(a)
	var node_b := _node(b)
	if node_a == null or node_b == null:
		return
	if delta == Vector2i.RIGHT:
		node_a.set_connection(&"right")
		node_b.set_connection(&"left")
	elif delta == Vector2i.LEFT:
		node_a.set_connection(&"left")
		node_b.set_connection(&"right")
	elif delta == Vector2i.DOWN:
		node_a.set_connection(&"bottom")
		node_b.set_connection(&"top")
	elif delta == Vector2i.UP:
		node_a.set_connection(&"top")
		node_b.set_connection(&"bottom")


func _node(coord: Vector2i) -> WorldStructureNode:
	return structure.get_node(coord)


func _inside(coord: Vector2i) -> bool:
	return structure.has_node(coord)


func _biome_for_coord(coord: Vector2i) -> StringName:
	if world_layout != null:
		return world_layout.get_biome_id(coord)
	return &""


func _biome_config_for_coord(coord: Vector2i) -> BiomeConfig:
	if config == null:
		return null
	return config.get_biome_config(_biome_for_coord(coord))
