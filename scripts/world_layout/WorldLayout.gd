@tool
class_name WorldLayout
extends Node2D

## Editor-authored macro world blueprint. BiomeLayer owns default generation
## semantics; ChunkLayer only overrides selected cells with fixed authored chunks.
@export var bootstrap_preset: WorldLayoutPreset
@export var use_bootstrap_when_empty: bool = true


static func compile_snapshot(config: WorldGenConfig) -> WorldLayoutSnapshot:
	if config == null or config.world_definition == null or config.world_definition.layout_scene == null:
		return null
	var layout_node: Node = config.world_definition.layout_scene.instantiate()
	var layout: WorldLayout = layout_node as WorldLayout
	if layout == null:
		if layout_node != null:
			layout_node.free()
		push_error("WorldLayout: WorldDefinition layout scene root must be WorldLayout.")
		return null
	var snapshot: WorldLayoutSnapshot = layout.build_snapshot(config)
	layout.free()
	return snapshot


func _ready() -> void:
	if Engine.is_editor_hint():
		ensure_bootstrap()
	else:
		visible = false


func biome_layer() -> BiomeLayer:
	return get_node_or_null("BiomeLayer") as BiomeLayer


func chunk_layer() -> ChunkLayer:
	return get_node_or_null("ChunkLayer") as ChunkLayer


func ensure_bootstrap() -> bool:
	if not use_bootstrap_when_empty or bootstrap_preset == null:
		return true
	var biomes: BiomeLayer = biome_layer()
	var chunks: ChunkLayer = chunk_layer()
	if biomes == null or chunks == null:
		return false
	var needs_biome_bootstrap: bool = biomes.get_used_cells().is_empty()
	var needs_chunk_bootstrap: bool = chunks.get_used_cells().is_empty()
	if not needs_biome_bootstrap and not needs_chunk_bootstrap:
		return true
	if not bootstrap_preset.is_valid():
		push_error("WorldLayout: Bootstrap preset is invalid.")
		return false
	var success: bool = true
	if needs_biome_bootstrap:
		success = biomes.apply_bootstrap_rects(bootstrap_preset.biome_rects) and success
	if needs_chunk_bootstrap:
		success = chunks.apply_bootstrap_placements(bootstrap_preset.fixed_chunks) and success
	return success


func build_snapshot(config: WorldGenConfig) -> WorldLayoutSnapshot:
	if config == null or not ensure_bootstrap():
		return null
	var biomes: BiomeLayer = biome_layer()
	var chunks: ChunkLayer = chunk_layer()
	if biomes == null or chunks == null:
		return null
	if not biomes.validate_bindings(config.biome_configs):
		push_error("WorldLayout: BiomeLayer bindings/cells are invalid.")
		return null
	if not chunks.validate_bindings(config.special_chunk_defs):
		push_error("WorldLayout: ChunkLayer bindings/cells are invalid.")
		return null

	var snapshot := WorldLayoutSnapshot.new()
	snapshot.chunk_size = PieceWorldConstants.CHUNK_SIZE
	snapshot.biome_by_cell = biomes.export_biome_ids()
	snapshot.fixed_chunk_id_by_origin = chunks.export_fixed_chunk_origins()
	if not _expand_fixed_chunk_occupancy(snapshot, config):
		return null
	if not _collect_anchors(snapshot):
		return null
	snapshot.used_rect = _rect_for_cells(snapshot.biome_by_cell.keys())
	if not _validate_world_definition_anchors(snapshot, config.world_definition):
		return null
	if not snapshot.is_valid():
		push_error("WorldLayout: Compiled snapshot is invalid.")
		return null
	return snapshot


func _validate_world_definition_anchors(snapshot: WorldLayoutSnapshot, definition: WorldDefinition) -> bool:
	if definition == null:
		return false
	var required_ids: Array[StringName] = [
		definition.player_spawn_anchor_id,
		definition.main_entrance_anchor_id,
		definition.main_path_start_anchor_id,
	]
	if definition.main_path_end_anchor_id != &"":
		required_ids.append(definition.main_path_end_anchor_id)
	for anchor_id: StringName in required_ids:
		if anchor_id == &"" or not snapshot.anchor_data_by_id.has(anchor_id):
			push_error("WorldLayout: Required WorldAnchor '%s' is missing." % str(anchor_id))
			return false
		var anchor_cell: Variant = snapshot.get_anchor_cell(anchor_id)
		if not anchor_cell is Vector2i or not snapshot.has_world_cell(anchor_cell):
			push_error("WorldLayout: WorldAnchor '%s' is outside the authored world." % str(anchor_id))
			return false
	return true


func _expand_fixed_chunk_occupancy(snapshot: WorldLayoutSnapshot, config: WorldGenConfig) -> bool:
	for origin_value: Variant in snapshot.fixed_chunk_id_by_origin.keys():
		var origin: Vector2i = origin_value
		var chunk_id := StringName(snapshot.fixed_chunk_id_by_origin[origin])
		var chunk_def: SpecialChunkDef = config.get_special_chunk_def(chunk_id)
		if chunk_def == null:
			push_error("WorldLayout: Unknown fixed chunk id '%s'." % str(chunk_id))
			return false
		for y: int in range(origin.y, origin.y + chunk_def.size_in_chunks.y):
			for x: int in range(origin.x, origin.x + chunk_def.size_in_chunks.x):
				var coord := Vector2i(x, y)
				if not snapshot.biome_by_cell.has(coord):
					push_error("WorldLayout: Fixed chunk '%s' occupies void cell %s." % [str(chunk_id), str(coord)])
					return false
				var biome_id := StringName(snapshot.biome_by_cell[coord])
				if not chunk_def.allowed_biomes.is_empty() and not chunk_def.allowed_biomes.has(biome_id):
					push_error(
						"WorldLayout: Fixed chunk '%s' is not allowed in biome '%s' at %s."
						% [str(chunk_id), str(biome_id), str(coord)]
					)
					return false
				if snapshot.fixed_chunk_origin_by_cell.has(coord):
					var other_origin: Vector2i = snapshot.fixed_chunk_origin_by_cell[coord]
					push_error("WorldLayout: Fixed chunks overlap at %s (origins %s and %s)." % [str(coord), str(other_origin), str(origin)])
					return false
				snapshot.fixed_chunk_origin_by_cell[coord] = origin
	return true


func _collect_anchors(snapshot: WorldLayoutSnapshot) -> bool:
	var success: bool = true
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
			if not child is WorldAnchor:
				continue
			var anchor := child as WorldAnchor
			if not anchor.is_valid():
				push_error("WorldLayout: Invalid WorldAnchor node '%s'." % str(anchor.name))
				success = false
				continue
			if snapshot.anchor_data_by_id.has(anchor.anchor_id):
				push_error("WorldLayout: Duplicate WorldAnchor id '%s'." % str(anchor.anchor_id))
				success = false
				continue
			snapshot.anchor_data_by_id[anchor.anchor_id] = {
				&"position": anchor.global_position,
				&"clearance_radius": anchor.clearance_radius,
				&"clearance_offset": anchor.clearance_offset,
				&"tags": anchor.tags.duplicate(),
			}
	return success


func _rect_for_cells(cells: Array) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var first: Vector2i = cells[0]
	var min_x: int = first.x
	var min_y: int = first.y
	var max_x: int = first.x
	var max_y: int = first.y
	for value: Variant in cells:
		var cell: Vector2i = value
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
