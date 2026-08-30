extends Node


func _ready() -> void:
	var config := load("res://resources/world_gen/default_world_gen_config.tres") as WorldGenConfig
	assert(config != null)
	assert(config.is_valid())
	assert(config.world_definition != null)

	var snapshot: WorldLayoutSnapshot = WorldLayout.compile_snapshot(config)
	assert(snapshot != null)
	assert(snapshot.is_valid())
	assert(snapshot.chunk_size == PieceWorldConstants.CHUNK_SIZE)

	_test_biome_layout(snapshot)
	_test_fixed_chunks(config, snapshot)
	_test_anchors(config, snapshot)
	_test_structure(config, snapshot)
	_test_biome_map(config, snapshot)

	print("World Layout Smoke Test: PASS")
	get_tree().quit()


func _test_biome_layout(snapshot: WorldLayoutSnapshot) -> void:
	assert(snapshot.get_biome_id(Vector2i(-1, -1)) == &"surface")
	assert(snapshot.get_biome_id(Vector2i(0, 0)) == &"mine")
	assert(snapshot.get_biome_id(Vector2i(5, 14)) == &"snow")
	assert(snapshot.get_biome_id(Vector2i(-6, 26)) == &"deep")
	assert(snapshot.get_biome_id(Vector2i(0, 40)) == &"deep")

	# Empty BiomeLayer cells are authoritative VOID, even when they are inside the
	# rectangular used bounds of the macro map.
	assert(not snapshot.has_world_cell(Vector2i(-11, 0)))
	assert(not snapshot.has_world_cell(Vector2i(12, 20)))
	assert(snapshot.has_world_cell(Vector2i(-10, 6)))


func _test_fixed_chunks(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-1, -1)) == &"surface_spawn_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(1, -1)) == &"surface_entrance_chunk")
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, -1)) == Vector2i(1, -1))
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, 0)) == Vector2i(1, -1))

	var entrance := config.get_special_chunk_def(&"surface_entrance_chunk")
	assert(entrance != null)
	assert(entrance.size_in_chunks == Vector2i(1, 2))
	assert(not entrance.allow_random_placement)
	assert(entrance.allowed_biomes.has(&"surface"))
	assert(entrance.allowed_biomes.has(&"mine"))

	var structure := WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
	var planning_map := BiomeMap.new(config.world_seed, config, snapshot)
	planning_map.world_structure = structure
	var planner := SpecialChunkPlanner.new(config.world_seed, config, planning_map, structure)
	var placement: SpecialChunkPlacement = planner.get_chunk_at(Vector2i(1, 0))
	assert(placement != null)
	assert(placement.authored)
	assert(placement.origin_chunk == Vector2i(1, -1))
	assert(placement.chunk_def == entrance)


func _test_anchors(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var definition := config.world_definition
	var spawn_position: Variant = snapshot.get_anchor_position(definition.player_spawn_anchor_id)
	assert(spawn_position is Vector2)
	assert(snapshot.get_anchor_cell(definition.player_spawn_anchor_id) == Vector2i(-1, -1))
	assert(snapshot.get_anchor_clearance_radius(definition.player_spawn_anchor_id) > 0.0)
	assert(snapshot.get_anchor_cell(definition.main_entrance_anchor_id) == Vector2i(1, -1))
	assert(snapshot.get_anchor_cell(definition.main_path_start_anchor_id) == Vector2i(1, 1))
	assert(snapshot.get_anchor_cell(definition.main_path_end_anchor_id) == Vector2i(0, 48))


func _test_structure(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var structure := WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
	assert(structure != null)
	assert(structure.nodes.size() == snapshot.biome_by_cell.size())
	assert(structure.has_node(Vector2i(-1, -1)))
	assert(not structure.has_node(Vector2i(-11, 0)))
	assert(structure.has_node(Vector2i(1, 1)))
	assert(structure.has_node(Vector2i(0, 48)))
	assert(structure.get_node(Vector2i(1, 1)).has_tag(&"main_path"))
	assert(structure.get_node(Vector2i(0, 48)).has_tag(&"main_path"))

	# Bounds are derived from the actual authored layout rather than a duplicate
	# rectangle in WorldStructureProfile.
	assert(structure.min_x == snapshot.used_rect.position.x)
	assert(structure.min_y == snapshot.used_rect.position.y)
	assert(structure.max_x == snapshot.used_rect.end.x - 1)
	assert(structure.max_y == snapshot.used_rect.end.y - 1)


func _test_biome_map(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var map := BiomeMap.new(config.world_seed, config, snapshot)
	assert(map.get_biome(Vector2i(0, 0)) == &"mine")
	assert(map.get_biome(Vector2i(5, 14)) == &"snow")
	assert(map.get_biome(Vector2i(0, 40)) == &"deep")
	assert(map.get_biome(Vector2i(-11, 0)) == &"")
	assert(not map.has_world_cell(Vector2i(-11, 0)))
