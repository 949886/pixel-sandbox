@tool
class_name ChunkLayer
extends TileMapLayer

## Visual authored-chunk override layer. A painted tile marks only the origin;
## SpecialChunkDef.size_in_chunks expands the placement across the macro grid.
@export var bindings: Array[ChunkTileBinding] = []
@export var draw_footprints: bool = true
@export_range(0.0, 1.0, 0.05) var footprint_alpha: float = 0.22

var _editor_redraw_accumulator: float = 0.0


func _ready() -> void:
	visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not draw_footprints:
		return
	_editor_redraw_accumulator += delta
	if _editor_redraw_accumulator >= 0.25:
		_editor_redraw_accumulator = 0.0
		queue_redraw()


func get_chunk_def(cell: Vector2i) -> SpecialChunkDef:
	var source_id: int = get_cell_source_id(cell)
	if source_id < 0:
		return null
	var atlas_coords: Vector2i = get_cell_atlas_coords(cell)
	var alternative_tile: int = get_cell_alternative_tile(cell)
	for binding: ChunkTileBinding in bindings:
		if binding != null and binding.matches(source_id, atlas_coords, alternative_tile):
			return binding.chunk_def
	return null


func set_chunk_origin(cell: Vector2i, chunk_def: SpecialChunkDef) -> bool:
	if chunk_def == null:
		erase_cell(cell)
		return true
	var binding: ChunkTileBinding = _binding_for_chunk(chunk_def)
	if binding == null:
		return false
	set_cell(cell, binding.source_id, binding.atlas_coords, binding.alternative_tile)
	queue_redraw()
	return true


func export_fixed_chunk_origins() -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in get_used_cells():
		var chunk_def: SpecialChunkDef = get_chunk_def(cell)
		if chunk_def != null and chunk_def.id != &"":
			result[cell] = chunk_def.id
	return result


func apply_bootstrap_placements(entries: Array[ChunkPaintPlacementDef]) -> bool:
	var success: bool = true
	for entry: ChunkPaintPlacementDef in entries:
		if entry == null or not entry.is_valid() or not set_chunk_origin(entry.origin, entry.chunk_def):
			success = false
	queue_redraw()
	return success


func validate_bindings(known_chunks: Array[SpecialChunkDef]) -> bool:
	if tile_set == null or tile_set.tile_size != Vector2i(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE):
		return false
	var known_ids: Dictionary = {}
	for chunk_def: SpecialChunkDef in known_chunks:
		if chunk_def != null and chunk_def.id != &"":
			known_ids[chunk_def.id] = true
	var seen_tile_keys: Dictionary = {}
	for binding: ChunkTileBinding in bindings:
		if binding == null or not binding.is_valid() or not known_ids.has(binding.chunk_def.id):
			return false
		var key: String = _tile_key(binding.source_id, binding.atlas_coords, binding.alternative_tile)
		if seen_tile_keys.has(key):
			return false
		seen_tile_keys[key] = true
	for cell: Vector2i in get_used_cells():
		if get_chunk_def(cell) == null:
			return false
	return true


func _draw() -> void:
	if not Engine.is_editor_hint() or not draw_footprints or tile_set == null:
		return
	var tile_size: Vector2 = Vector2(tile_set.tile_size)
	for cell: Vector2i in get_used_cells():
		var chunk_def: SpecialChunkDef = get_chunk_def(cell)
		if chunk_def == null:
			continue
		var center: Vector2 = map_to_local(cell)
		var top_left: Vector2 = center - tile_size * 0.5
		var size: Vector2 = tile_size * Vector2(chunk_def.size_in_chunks)
		var color: Color = chunk_def.editor_color
		color.a = footprint_alpha
		draw_rect(Rect2(top_left, size), color, true)
		var border: Color = chunk_def.editor_color
		border.a = 0.9
		draw_rect(Rect2(top_left, size), border, false, 3.0)


func _binding_for_chunk(chunk_def: SpecialChunkDef) -> ChunkTileBinding:
	for binding: ChunkTileBinding in bindings:
		if binding != null and binding.chunk_def == chunk_def:
			return binding
	return null


func _tile_key(source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%d:%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]
