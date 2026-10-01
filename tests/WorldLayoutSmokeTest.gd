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
	_test_surface_entrance_clearance(config)
	_test_surface_foliage_material()
	_test_anchors(config, snapshot)
	_test_world_presentation(config, snapshot)
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
		config.world_definition.presentation_profile,
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
	assert(snapshot.get_biome_id(Vector2i(5, 8)) == &"snow")
	assert(snapshot.get_biome_id(Vector2i(-6, 16)) == &"deep")
	assert(snapshot.get_biome_id(Vector2i(0, 24)) == &"deep")
	assert(snapshot.used_rect.position.y == -1)
	assert(snapshot.used_rect.end.y == 26)

	# Empty BiomeLayer cells are authoritative VOID, even when they are inside the
	# rectangular used bounds of the macro map.
	assert(not snapshot.has_world_cell(Vector2i(-11, 0)))
	assert(not snapshot.has_world_cell(Vector2i(12, 12)))
	assert(snapshot.has_world_cell(Vector2i(-10, 3)))


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
	chunks.set_editor_selected_origin(Vector2i(-1, -1))
	chunks.clear_editor_selection()
	var entrance_placement: ChunkPaintPlacementDef = chunks.get_placement_at(Vector2i(1, 0))
	assert(entrance_placement != null)
	assert(entrance_placement.origin == Vector2i(1, -1))
	assert(entrance_placement.chunk_def.id == &"surface_entrance_chunk")
	layout.free()


func _test_fixed_chunks(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-5, -1)) == &"surface_left_boundary_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-4, -1)) == &"surface_ground_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-3, -1)) == &"surface_grove_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-2, -1)) == &"surface_approach_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(-1, -1)) == &"surface_spawn_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(0, -1)) == &"surface_east_ground_chunk")
	assert(snapshot.get_fixed_chunk_id_at_origin(Vector2i(1, -1)) == &"surface_entrance_chunk")
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, -1)) == Vector2i(1, -1))
	assert(snapshot.get_fixed_chunk_origin(Vector2i(1, 0)) == Vector2i(1, -1))

	var entrance: SpecialChunkDef = config.get_special_chunk_def(&"surface_entrance_chunk")
	assert(entrance != null)
	assert(entrance.size_in_chunks == Vector2i(1, 2))
	assert(not entrance.allow_random_placement)
	assert(entrance.allowed_biomes.has(&"surface"))
	assert(entrance.allowed_biomes.has(&"mine"))
	assert(entrance.require_material_layout)
	assert(entrance.has_valid_material_layout())
	assert(entrance.bottom_profile.size() == 4)
	assert(entrance.bottom_profile[0] == PieceSocket.SOLID)
	assert(entrance.bottom_profile[1] == PieceSocket.SOLID)
	assert(entrance.bottom_profile[2] == PieceSocket.OPEN_LARGE)
	assert(entrance.bottom_profile[3] == PieceSocket.SOLID)

	var authored_surface_ids: Array[StringName] = [
		&"surface_left_boundary_chunk",
		&"surface_ground_chunk",
		&"surface_grove_chunk",
		&"surface_approach_chunk",
		&"surface_spawn_chunk",
		&"surface_east_ground_chunk",
		&"surface_entrance_chunk",
	]
	for chunk_id: StringName in authored_surface_ids:
		var surface_def: SpecialChunkDef = config.get_special_chunk_def(chunk_id)
		assert(surface_def != null)
		assert(surface_def.require_material_layout)
		assert(surface_def.has_valid_material_layout())
		var material_image: Image = surface_def.create_authored_material_image()
		assert(material_image != null)
		assert(material_image.get_size() == surface_def.expected_material_size())

	var structure: WorldStructure = WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
	var planning_map: BiomeMap = BiomeMap.new(config.world_seed, config, snapshot)
	planning_map.world_structure = structure
	var planner: SpecialChunkPlanner = SpecialChunkPlanner.new(config.world_seed, config, planning_map, structure)
	var placement: SpecialChunkPlacement = planner.get_chunk_at(Vector2i(1, 0))
	assert(placement != null)
	assert(placement.authored)
	assert(placement.origin_chunk == Vector2i(1, -1))
	assert(placement.chunk_def == entrance)
	assert(placement.authored_material_image != null)
	assert(placement.authored_material_image.get_size() == Vector2i(512, 1024))
	# The art-authored shaft reaches the exact OPEN_LARGE socket slot at the bottom.
	assert(placement.authored_material_image.get_pixel(320, 1023).a < 0.05)
	assert(placement.authored_material_image.get_pixel(96, 1023).a > 0.95)
	var baked_entrance: Image = SpecialPieceImageBuilder.build(placement)
	assert(baked_entrance.get_size() == Vector2i(512, 1024))
	assert(baked_entrance.get_pixel(320, 1023).a < 0.05)

	# Every authored footprint cell must still resolve to the authored placement after
	# random SpecialChunk planning. Procedural planning may never overwrite it.
	for cell_value: Variant in snapshot.fixed_chunk_origin_by_cell.keys():
		var cell: Vector2i = cell_value
		var authored_placement: SpecialChunkPlacement = planner.get_chunk_at(cell)
		assert(authored_placement != null)
		assert(authored_placement.authored)
		assert(authored_placement.origin_chunk == snapshot.get_fixed_chunk_origin(cell))


func _test_surface_entrance_clearance(config: WorldGenConfig) -> void:
	var entrance: SpecialChunkDef = config.get_special_chunk_def(&"surface_entrance_chunk")
	var east_ground: SpecialChunkDef = config.get_special_chunk_def(&"surface_east_ground_chunk")
	assert(entrance != null)
	assert(east_ground != null)
	var entrance_image: Image = entrance.create_authored_material_image()
	var east_image: Image = east_ground.create_authored_material_image()
	assert(entrance_image != null and entrance_image.get_size() == Vector2i(512, 1024))
	assert(east_image != null and east_image.get_size() == Vector2i(512, 512))

	# The approach crosses the fixed-chunk seam through air. This catches a closed
	# vertical wall at the authored entrance boundary.
	for y: int in range(294, 316):
		assert(east_image.get_pixel(511, y).a < 0.05)
		assert(entrance_image.get_pixel(0, y).a < 0.05)

	# Check a collider-sized clearance chain from the surface mouth to the bottom
	# OPEN_LARGE socket. Decorative supports may frame the tunnel, but must never
	# span the player's route.
	var path_points: Array[Vector2i] = [
		Vector2i(58, 294),
		Vector2i(96, 302),
		Vector2i(132, 317),
		Vector2i(170, 337),
		Vector2i(208, 368),
		Vector2i(244, 410),
		Vector2i(278, 462),
		Vector2i(305, 520),
		Vector2i(320, 585),
		Vector2i(320, 690),
		Vector2i(320, 805),
		Vector2i(320, 915),
		Vector2i(320, 1010),
	]
	for point: Vector2i in path_points:
		_assert_air_clearance(entrance_image, point, Vector2i(6, 10))


func _assert_air_clearance(image: Image, center: Vector2i, half_size: Vector2i) -> void:
	assert(image != null)
	var rect: Rect2i = Rect2i(center - half_size, half_size * 2 + Vector2i.ONE)
	assert(rect.position.x >= 0 and rect.position.y >= 0)
	assert(rect.end.x <= image.get_width() and rect.end.y <= image.get_height())
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			assert(image.get_pixel(x, y).a < 0.05)


func _test_surface_foliage_material() -> void:
	var palette: MaterialPalette = load("res://resources/materials/default_material_palette.tres") as MaterialPalette
	assert(palette != null)
	palette.rebuild_cache()
	var foliage: MaterialEntry = null
	var organic: MaterialEntry = null
	for entry: MaterialEntry in palette.entries:
		if entry == null:
			continue
		if entry.id == &"surface_foliage":
			foliage = entry
		elif entry.id == &"organic":
			organic = entry
	assert(foliage != null)
	assert(foliage.engine_element_id == 2058)
	assert(foliage.effective_activity_mode() == 1)
	assert(not foliage.solid)
	assert(organic != null)
	assert(organic.engine_element_id == 14)
	assert(palette.element_id_for_color(Color8(46, 92, 42, 255)) == foliage.engine_element_id)
	assert(palette.element_id_for_color(Color8(53, 57, 35, 255)) == organic.engine_element_id)


func _test_anchors(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var definition: WorldDefinition = config.world_definition
	assert(definition.presentation_profile != null)
	assert(definition.presentation_profile.is_valid())
	assert(definition.presentation_profile.surface_reference_anchor_id == definition.player_spawn_anchor_id)
	var spawn_position: Variant = snapshot.get_anchor_position(definition.player_spawn_anchor_id)
	assert(spawn_position is Vector2)
	assert(snapshot.get_anchor_cell(definition.player_spawn_anchor_id) == Vector2i(-1, -1))
	assert(snapshot.get_anchor_clearance_radius(definition.player_spawn_anchor_id) > 0.0)
	assert(snapshot.get_anchor_cell(definition.main_entrance_anchor_id) == Vector2i(1, -1))
	assert(snapshot.get_anchor_cell(definition.main_path_start_anchor_id) == Vector2i(1, 1))
	assert(snapshot.get_anchor_cell(definition.main_path_end_anchor_id) == Vector2i(0, 25))


func _test_world_presentation(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var definition: WorldDefinition = config.world_definition
	var profile: WorldPresentationProfile = definition.presentation_profile
	assert(profile != null)
	var backdrop: WorldBackdrop = WorldBackdrop.new()
	assert(backdrop.configure(snapshot, profile, config.world_seed))
	assert(backdrop.visible)
	assert(backdrop.draw_bounds().size.x > 0.0)
	assert(backdrop.draw_bounds().size.y > 0.0)
	var anchor_value: Variant = snapshot.get_anchor_position(profile.surface_reference_anchor_id)
	assert(anchor_value is Vector2)
	var anchor_position: Vector2 = anchor_value
	assert(is_equal_approx(backdrop.surface_y(), anchor_position.y + profile.surface_y_offset))
	backdrop.free()


func _test_structure(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var structure: WorldStructure = WorldStructureBuilder.new(config.world_seed, config, snapshot).build()
	assert(structure != null)
	assert(structure.nodes.size() == snapshot.biome_by_cell.size())
	assert(structure.has_node(Vector2i(-1, -1)))
	assert(not structure.has_node(Vector2i(-11, 0)))
	assert(structure.has_node(Vector2i(1, 1)))
	assert(structure.has_node(Vector2i(0, 25)))
	assert(structure.get_node(Vector2i(1, 1)).has_tag(&"main_path"))
	assert(structure.get_node(Vector2i(0, 25)).has_tag(&"main_path"))

	# Bounds are derived from the actual authored layout rather than a duplicate
	# rectangle in WorldStructureProfile.
	assert(structure.min_x == snapshot.used_rect.position.x)
	assert(structure.min_y == snapshot.used_rect.position.y)
	assert(structure.max_x == snapshot.used_rect.end.x - 1)
	assert(structure.max_y == snapshot.used_rect.end.y - 1)


func _test_biome_map(config: WorldGenConfig, snapshot: WorldLayoutSnapshot) -> void:
	var map: BiomeMap = BiomeMap.new(config.world_seed, config, snapshot)
	assert(map.get_biome(Vector2i(0, 0)) == &"mine")
	assert(map.get_biome(Vector2i(5, 8)) == &"snow")
	assert(map.get_biome(Vector2i(0, 24)) == &"deep")
	assert(map.get_biome(Vector2i(-11, 0)) == &"")
	assert(not map.has_world_cell(Vector2i(-11, 0)))
