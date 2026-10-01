extends Node


func _ready() -> void:
	var config: WorldGenConfig = load("res://resources/world_gen/default_world_gen_config.tres") as WorldGenConfig
	assert(config != null)
	assert(config.is_valid())
	assert(config.world_definition != null)
	_test_editor_tool_dependency_closure(config)

	var snapshot: WorldLayoutSnapshot = WorldLayout.compile_snapshot(config)
	assert(snapshot != null)
	assert(snapshot.is_valid())
	assert(snapshot.chunk_size == PieceWorldConstants.CHUNK_SIZE)

	_test_serialized_authoring_data(config)
	_test_biome_layout(snapshot)
	_test_chunk_layer_authoring_model(config)
	_test_fixed_chunks(config, snapshot)
	_test_anchors(config, snapshot)
	_test_structure(config, snapshot)
	_test_biome_map(config, snapshot)

	print("World Layout Smoke Test: PASS")
	get_tree().quit()


func _test_editor_tool_dependency_closure(config: WorldGenConfig) -> void:
	# Every scripted object called from an @tool authoring script must itself be
	# tool-enabled. Otherwise Godot loads it as a placeholder in the editor and
	# method calls such as ChunkPaintPlacementDef.is_valid() fail.
	var instances: Array[Object] = [
		config,
		config.world_definition,
		config.structure_profile,
		WorldLayoutSnapshot.new(),
		WorldLayoutPreset.new(),
		BiomePaintRectDef.new(),
		BiomeTileBinding.new(),
		ChunkPaintPlacementDef.new(),
		SpawnAnchorDef.new(),
	]
	for biome: BiomeConfig in config.biome_configs:
		instances.append(biome)
	for chunk_def: SpecialChunkDef in config.special_chunk_defs:
		instances.append(chunk_def)
	for instance: Object in instances:
		_assert_tool_script(instance)


func _assert_tool_script(instance: Object) -> void:
	assert(instance != null)
	var instance_script: Script = instance.get_script() as Script
	assert(instance_script != null)
	assert(instance_script.is_tool())


func _test_serialized_authoring_data(config: WorldGenConfig) -> void:
	# The default editor scene must be immediately useful before _ready/bootstrap.
	# This catches regressions where opening DefaultWorldLayout looks empty.
	var layout_node: Node = config.world_definition.layout_scene.instantiate()
	var layout: WorldLayout = layout_node as WorldLayout
	assert(layout != null)
	assert(not layout.use_bootstrap_when_empty)
	assert(layout.bootstrap_preset == null)
	var biomes: BiomeLayer = layout.biome_layer()
	var chunks: ChunkLayer = layout.chunk_layer()
	assert(biomes != null)
	assert(chunks != null)
	assert(biomes.get_used_cells().size() > 0)
	assert(biomes.get_biome_config(Vector2i(-1, -1)).id == &"surface")
	assert(biomes.get_biome_config(Vector2i(0, 0)).id == &"mine")
	assert(chunks.placements.size() > 0)
	assert(layout.get_world_anchors().size() >= 4)
	layout.free()


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


func _test_chunk_layer_authoring_model(config: WorldGenConfig) -> void:
	var layout_node: Node = config.world_definition.layout_scene.instantiate()
	var layout: WorldLayout = layout_node as WorldLayout
	assert(layout != null)
	var chunks: ChunkLayer = layout.chunk_layer()
	assert(chunks != null)
	var chunk_script: Script = chunks.get_script() as Script
	assert(chunk_script != null)
	assert(chunk_script.get_instance_base_type() == &"Node2D")
	assert(chunks.palette_chunks.size() > 0)
	assert(chunks.get_chunk_def_at_origin(Vector2i(-1, -1)) != null)
	var entrance_placement: ChunkPaintPlacementDef = chunks.get_placement_at(Vector2i(1, 0))
	assert(entrance_placement != null)
	assert(entrance_placement.origin == Vector2i(1, -1))
	assert(entrance_placement.chunk_def.id == &"surface_entrance_chunk")
	layout.free()


func _test_fixed_chunks(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-1, -1)) == &"surface_spawn_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(1, -1)) == &"surface_entrance_chunk")
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, -1)) == Vector2i(1, -1))
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, 0)) == Vector2i(1, -1))

	var entrance: SpecialChunkDef = config.get_special_chunk_def(&"surface_entrance_chunk")
	assert(entrance != null)
	assert(entrance.size_in_chunks == Vector2i(1, 2))
	assert(not entrance.allow_random_placement)
	assert(entrance.allowed_biomes.has(&"surface"))
	assert(entrance.allowed_biomes.has(&"mine"))

	var structure: WorldStructure = WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
	var planning_map: BiomeMap = BiomeMap.new(config.world_seed, config, snapshot)
	planning_map.world_structure = structure
	var planner: SpecialChunkPlanner = SpecialChunkPlanner.new(config.world_seed, config, planning_map, structure)
	var placement: SpecialChunkPlacement = planner.get_chunk_at(Vector2i(1, 0))
	assert(placement != null)
	assert(placement.authored)
	assert(placement.origin_chunk == Vector2i(1, -1))
	assert(placement.chunk_def == entrance)

	# Every authored footprint cell must still resolve to the authored placement after
	# random SpecialChunk planning. Procedural planning may never overwrite it.
	for cell_value: Variant in snapshot.fixed_chunk_origin_by_cell.keys():
		var cell: Vector2i = cell_value
		var authored_placement: SpecialChunkPlacement = planner.get_chunk_at(cell)
		assert(authored_placement != null)
		assert(authored_placement.authored)
		assert(authored_placement.origin_chunk == snapshot.get_fixed_chunk_origin(cell))


func _test_anchors(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var definition: WorldDefinition = config.world_definition
	var spawn_position: Variant = snapshot.get_anchor_position(definition.player_spawn_anchor_id)
	assert(spawn_position is Vector2)
	assert(snapshot.get_anchor_cell(definition.player_spawn_anchor_id) == Vector2i(-1, -1))
	assert(snapshot.get_anchor_clearance_radius(definition.player_spawn_anchor_id) > 0.0)
	assert(snapshot.get_anchor_cell(definition.main_entrance_anchor_id) == Vector2i(1, -1))
	assert(snapshot.get_anchor_cell(definition.main_path_start_anchor_id) == Vector2i(1, 1))
	assert(snapshot.get_anchor_cell(definition.main_path_end_anchor_id) == Vector2i(0, 48))


func _test_structure(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var structure: WorldStructure = WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
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
	var map: BiomeMap = BiomeMap.new(config.world_seed, config, snapshot)
	assert(map.get_biome(Vector2i(0, 0)) == &"mine")
	assert(map.get_biome(Vector2i(5, 14)) == &"snow")
	assert(map.get_biome(Vector2i(0, 40)) == &"deep")
	assert(map.get_biome(Vector2i(-11, 0)) == &"")
	assert(not map.has_world_cell(Vector2i(-11, 0)))
