class_name WorldStructureBuilder
extends RefCounted

# Builds a deterministic chunk-level plan: a continuous main path, side branches,
# and natural chamber regions. This layer gives the local Wang generator a goal
# instead of letting every chunk decide its role independently.


var world_seed: int = 12345
var config: WorldGenConfig
var rng: RandomNumberGenerator
var structure: WorldStructure
var profile: WorldStructureProfile
var chamber_counter: int = 0

func _init(p_world_seed: int, p_config: WorldGenConfig = null) -> void:
	world_seed = p_world_seed
	config = p_config
	profile = config.structure_profile if config != null else null
	if profile == null:
		profile = WorldStructureProfile.new()
	rng = SeedUtil.rng(world_seed, "world_structure_v1")

func build() -> WorldStructure:
	structure = WorldStructure.new()
	structure.min_x = profile.min_x
	structure.max_x = profile.max_x
	structure.min_y = profile.min_y
	structure.max_y = profile.max_y
	_fill_default_nodes()
	_build_main_path()
	_build_side_branches()
	_place_chambers()
	return structure

func _fill_default_nodes() -> void:
	for y: int in range(profile.min_y, profile.max_y + 1):
		for x: int in range(profile.min_x, profile.max_x + 1):
			var coord := Vector2i(x, y)
			var node := WorldStructureNode.new(coord, _biome_for_y(y), BiomeMap.ChunkType.SOLID)
			node.add_tag(&"structure_v1")
			structure.set_node(node)

func _build_main_path() -> void:
	var x: int = 0
	var previous_coord := Vector2i(x, profile.min_y)
	_mark_main_path(previous_coord)
	structure.set_main_path_x(profile.min_y, x)
	for y: int in range(profile.min_y + 1, profile.max_y + 1):
		# Move vertically first, then optionally carve a same-row horizontal kink.
		var vertical_coord := Vector2i(x, y)
		_mark_main_path(vertical_coord)
		_connect(previous_coord, vertical_coord)
		previous_coord = vertical_coord
		if rng.randf() < _main_path_wander_chance(y):
			var old_x: int = x
			x = clampi(x + rng.randi_range(-1, 1), profile.main_path_min_x, profile.main_path_max_x)
			if x != old_x:
				var kink_coord := Vector2i(x, y)
				_mark_main_path(kink_coord)
				_connect(previous_coord, kink_coord)
				previous_coord = kink_coord
		structure.set_main_path_x(y, x)
		_mark_path_shoulders(Vector2i(x, y))

func _main_path_wander_chance(y: int) -> float:
	var biome_config := _biome_config_for_y(y)
	return biome_config.structure_main_path_wander_chance if biome_config != null else 0.0

func _mark_main_path(coord: Vector2i) -> void:
	var node := _node(coord)
	if node == null:
		return
	node.chunk_type = BiomeMap.ChunkType.MAIN_PATH
	node.add_tag(&"main_path")
	node.add_tag(&"path_core")

func _mark_path_shoulders(coord: Vector2i) -> void:
	for dx: int in [-1, 1]:
		if rng.randf() > profile.shoulder_chance:
			continue
		var shoulder_coord := coord + Vector2i(dx, 0)
		var node := _node(shoulder_coord)
		if node == null or node.chunk_type == BiomeMap.ChunkType.MAIN_PATH:
			continue
		node.chunk_type = BiomeMap.ChunkType.CAVE
		node.add_tag(&"path_shoulder")
		_connect(coord, shoulder_coord)

func _build_side_branches() -> void:
	var y: int = profile.min_y + profile.branch_start_offset_y
	while y <= profile.max_y - profile.branch_end_margin_y:
		var biome_config := _biome_config_for_y(y)
		if biome_config != null and rng.randf() < biome_config.structure_branch_chance:
			var start := Vector2i(structure.get_main_path_x(y), y)
			var dir: int = -1 if rng.randf() < 0.5 else 1
			var length: int = rng.randi_range(2, maxi(2, biome_config.structure_branch_max_length))
			_build_branch(start, dir, length, rng.randf() < biome_config.structure_loop_chance)
		y += rng.randi_range(profile.branch_row_advance_min, profile.branch_row_advance_max)

func _build_branch(start: Vector2i, dir: int, length: int, make_loop: bool) -> void:
	var current := start
	var previous := start
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
		previous = current
		current = next
	if make_loop:
		var target_y: int = clampi(current.y + rng.randi_range(profile.loop_target_depth_min, profile.loop_target_depth_max), profile.min_y, profile.max_y)
		var target := Vector2i(structure.get_main_path_x(target_y), target_y)
		_carve_corridor(current, target, &"loop_branch")
	else:
		var end_node := _node(current)
		if end_node != null and current != start:
			end_node.add_tag(&"branch_end")

func _place_chambers() -> void:
	for y: int in range(profile.min_y + profile.chamber_start_offset_y, profile.max_y - profile.chamber_end_margin_y, profile.chamber_row_step):
		var biome_id: StringName = _biome_for_y(y)
		var biome_config := _biome_config_for_y(y)
		if biome_config == null or rng.randf() > biome_config.structure_chamber_chance:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var offset: int = rng.randi_range(profile.chamber_horizontal_offset_min, profile.chamber_horizontal_offset_max)
		var size := _pick_chamber_size(biome_id)
		var main := Vector2i(structure.get_main_path_x(y), y)
		var origin := main + Vector2i(side * offset, rng.randi_range(-profile.chamber_vertical_jitter, profile.chamber_vertical_jitter))
		origin.x = clampi(origin.x, profile.min_x + 1, profile.max_x - size.x - 1)
		origin.y = clampi(origin.y, profile.min_y + 1, profile.max_y - size.y - 1)
		if not _can_place_chamber(origin, size):
			continue
		_mark_chamber(origin, size)
		var entrance := Vector2i(origin.x if side > 0 else origin.x + size.x - 1, origin.y + int(size.y / 2))
		_carve_corridor(main, entrance, &"chamber_connector")

func _pick_chamber_size(biome_id: StringName) -> Vector2i:
	var biome_config: BiomeConfig = config.get_biome_config(biome_id) if config != null else null
	if biome_config == null or biome_config.structure_chamber_sizes.is_empty():
		return Vector2i.ONE
	return biome_config.structure_chamber_sizes[rng.randi_range(0, biome_config.structure_chamber_sizes.size() - 1)]

func _can_place_chamber(origin: Vector2i, size: Vector2i) -> bool:
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			var node := _node(Vector2i(x, y))
			if node == null:
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
				# Current demo chambers are small; every occupied chunk is useful as a visible edge anchor.
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
	var current := from_coord
	while current.x != to_coord.x:
		var next := current + Vector2i(1 if to_coord.x > current.x else -1, 0)
		_mark_corridor_node(next, tag)
		_connect(current, next)
		current = next
	while current.y != to_coord.y:
		var next := current + Vector2i(0, 1 if to_coord.y > current.y else -1)
		_mark_corridor_node(next, tag)
		_connect(current, next)
		current = next

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
	return coord.x >= profile.min_x and coord.x <= profile.max_x and coord.y >= profile.min_y and coord.y <= profile.max_y

func _biome_for_y(y: int) -> StringName:
	var biome_config := _biome_config_for_y(y)
	return biome_config.id if biome_config != null else &""

func _biome_config_for_y(y: int) -> BiomeConfig:
	if config == null:
		return null
	for biome_config: BiomeConfig in config.biome_configs:
		if biome_config != null and y >= biome_config.depth_min and y <= biome_config.depth_max:
			return biome_config
	return null
