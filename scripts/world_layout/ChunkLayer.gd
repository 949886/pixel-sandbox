@tool
class_name ChunkLayer
extends Node2D

## Editor-authored layer for fixed SpecialChunk placements.
##
## This is intentionally NOT a TileMapLayer. A runtime chunk is not a tile: normal
## chunk contents are generated dynamically by the Piece system. ChunkLayer stores
## only authored SpecialChunk origins that must reserve their footprint and override
## procedural generation at those cells.
# Explicit, data-driven source for the TileMap-like bottom brush palette.
# The editor never scans folders or infers resource paths.
@export var palette_chunks: Array[SpecialChunkDef] = []
@export var placements: Array[ChunkPaintPlacementDef] = []

@export_category("Editor visualization")
@export var draw_grid: bool = true
@export var draw_fixed_chunks: bool = true
@export var draw_labels: bool = true
@export_range(0.0, 1.0, 0.05) var fixed_chunk_alpha: float = 0.28
@export_range(0.0, 1.0, 0.05) var hover_alpha: float = 0.18
@export var grid_color: Color = Color(0.95, 0.55, 0.15, 0.52)
@export_range(1.0, 6.0, 0.5) var grid_line_width: float = 1.5
@export var fixed_chunk_border_width: float = 3.0
@export var selected_chunk_border_color: Color = Color(1.0, 0.88, 0.24, 1.0)
@export var selected_chunk_border_width: float = 6.0

var _editor_hover_cell: Variant = null
var _editor_preview_chunk: SpecialChunkDef = null
var _editor_selected_origin: Variant = null


func _ready() -> void:
	# Keep the author's editor visibility state. Runtime never renders this
	# authoring-only layer. All authoring graphics are drawn by the EditorPlugin
	# in viewport/screen space so they remain complete at every zoom level.
	if not Engine.is_editor_hint():
		visible = false


func chunk_size() -> int:
	return PieceWorldConstants.CHUNK_SIZE


func world_to_cell(local_position: Vector2) -> Vector2i:
	var size: float = float(chunk_size())
	return Vector2i(floori(local_position.x / size), floori(local_position.y / size))


func cell_rect(origin: Vector2i, size_in_chunks: Vector2i = Vector2i.ONE) -> Rect2:
	var size: float = float(chunk_size())
	return Rect2(Vector2(origin) * size, Vector2(size_in_chunks) * size)


func get_origin_cells() -> Array[Vector2i]:
	# Only authored SpecialChunk origins are stored. Procedural chunk cells are
	# intentionally absent from this component.
	var result: Array[Vector2i] = []
	for placement: ChunkPaintPlacementDef in placements:
		if _placement_is_valid(placement):
			result.append(placement.origin)
	return result


func is_empty() -> bool:
	return get_origin_cells().is_empty()


func get_chunk_def_at_origin(cell: Vector2i) -> SpecialChunkDef:
	for placement: ChunkPaintPlacementDef in placements:
		if _placement_is_valid(placement) and placement.origin == cell:
			return placement.chunk_def
	return null


func get_placement_at(cell: Vector2i) -> ChunkPaintPlacementDef:
	for placement: ChunkPaintPlacementDef in placements:
		if not _placement_is_valid(placement):
			continue
		if _placement_contains_cell(placement, cell):
			return placement
	return null


func get_chunk_def(cell: Vector2i) -> SpecialChunkDef:
	# Returns the fixed chunk occupying a cell, not only its origin.
	var placement: ChunkPaintPlacementDef = get_placement_at(cell)
	return placement.chunk_def if placement != null else null


func has_fixed_chunk_at(cell: Vector2i) -> bool:
	return get_placement_at(cell) != null


func set_chunk_origin(cell: Vector2i, chunk_def: SpecialChunkDef) -> bool:
	if chunk_def == null:
		return remove_chunk_at(cell)
	if not can_place_chunk(cell, chunk_def, true):
		return false

	var updated: Array[ChunkPaintPlacementDef] = duplicate_placements()
	# Replacing an existing chunk is only allowed when it has the exact same
	# origin. Other occupied footprints are protected from accidental painting.
	for index: int in range(updated.size() - 1, -1, -1):
		var existing: ChunkPaintPlacementDef = updated[index]
		if existing != null and existing.origin == cell:
			updated.remove_at(index)
	var placement: ChunkPaintPlacementDef = ChunkPaintPlacementDef.new()
	placement.chunk_def = chunk_def
	placement.origin = cell
	updated.append(placement)
	set_placements_data(updated)
	return true


func remove_chunk_at(cell: Vector2i) -> bool:
	var hit: ChunkPaintPlacementDef = get_placement_at(cell)
	if hit == null:
		return false
	var updated: Array[ChunkPaintPlacementDef] = []
	for placement: ChunkPaintPlacementDef in placements:
		if placement != hit:
			updated.append(_duplicate_placement(placement))
	set_placements_data(updated)
	return true


func can_place_chunk(origin: Vector2i, chunk_def: SpecialChunkDef, allow_replace_same_origin: bool = false) -> bool:
	if chunk_def == null or chunk_def.id == &"" \
		or chunk_def.size_in_chunks.x <= 0 or chunk_def.size_in_chunks.y <= 0:
		return false

	for placement: ChunkPaintPlacementDef in placements:
		if not _placement_is_valid(placement):
			continue
		if allow_replace_same_origin and placement.origin == origin:
			continue
		if _rects_overlap(
			origin,
			chunk_def.size_in_chunks,
			placement.origin,
			placement.chunk_def.size_in_chunks
		):
			return false
	return true


func duplicate_placements() -> Array[ChunkPaintPlacementDef]:
	var result: Array[ChunkPaintPlacementDef] = []
	for placement: ChunkPaintPlacementDef in placements:
		result.append(_duplicate_placement(placement))
	return result


func set_placements_data(value: Array) -> void:
	var copied: Array[ChunkPaintPlacementDef] = []
	for item: Variant in value:
		var placement: ChunkPaintPlacementDef = item as ChunkPaintPlacementDef
		if placement != null:
			copied.append(_duplicate_placement(placement))
	placements = copied
	queue_redraw()
	if Engine.is_editor_hint():
		notify_property_list_changed()


func export_fixed_chunk_origins() -> Dictionary:
	var result: Dictionary = {}
	for placement: ChunkPaintPlacementDef in placements:
		if _placement_is_valid(placement):
			result[placement.origin] = placement.chunk_def.id
	return result


func apply_bootstrap_placements(entries: Array[ChunkPaintPlacementDef]) -> bool:
	if entries.is_empty():
		return true
	var updated: Array[ChunkPaintPlacementDef] = duplicate_placements()
	for entry: ChunkPaintPlacementDef in entries:
		if not _placement_is_valid(entry):
			return false
		var duplicate: ChunkPaintPlacementDef = _duplicate_placement(entry)
		# Bootstrap data should itself be conflict-free. Do not silently replace an
		# authored fixed chunk if a malformed preset overlaps another placement.
		for existing: ChunkPaintPlacementDef in updated:
			if _placement_is_valid(existing) and _rects_overlap(
				duplicate.origin,
				duplicate.chunk_def.size_in_chunks,
				existing.origin,
				existing.chunk_def.size_in_chunks
			):
				return false
		updated.append(duplicate)
	set_placements_data(updated)
	return true


func validate_placements(known_chunks: Array[SpecialChunkDef]) -> bool:
	var known_ids: Dictionary = {}
	for chunk_def: SpecialChunkDef in known_chunks:
		if chunk_def != null and chunk_def.id != &"":
			known_ids[chunk_def.id] = true

	var palette_ids: Dictionary = {}
	for chunk_def: SpecialChunkDef in palette_chunks:
		if chunk_def == null or chunk_def.id == &"" or not known_ids.has(chunk_def.id):
			return false
		if palette_ids.has(chunk_def.id):
			return false
		palette_ids[chunk_def.id] = true

	for i: int in range(placements.size()):
		var placement: ChunkPaintPlacementDef = placements[i]
		if not _placement_is_valid(placement) or not known_ids.has(placement.chunk_def.id):
			return false
		for j: int in range(i + 1, placements.size()):
			var other: ChunkPaintPlacementDef = placements[j]
			if not _placement_is_valid(other):
				return false
			if _rects_overlap(
				placement.origin,
				placement.chunk_def.size_in_chunks,
				other.origin,
				other.chunk_def.size_in_chunks
			):
				return false
	return true


func set_editor_preview(cell: Variant, chunk_def: SpecialChunkDef) -> void:
	_editor_hover_cell = cell
	_editor_preview_chunk = chunk_def
	queue_redraw()


func clear_editor_preview() -> void:
	_editor_hover_cell = null
	_editor_preview_chunk = null
	queue_redraw()


func set_editor_selected_origin(origin: Variant) -> void:
	_editor_selected_origin = origin
	queue_redraw()


func clear_editor_selection() -> void:
	_editor_selected_origin = null
	queue_redraw()


func _draw() -> void:
	# Intentionally empty. Fixed-chunk fills, previews, outlines, labels, selection,
	# hover footprint, and the Chunk grid are all editor viewport overlays. Keeping
	# them out of Node2D custom drawing avoids CanvasItem bounds clipping and
	# zoom-scaled line widths. ChunkLayer remains only the authored placement data.
	pass


func editor_grid_rect() -> Rect2i:
	## Authoring bounds used by the screen-space editor grid. The public query keeps
	## the EditorPlugin independent from BiomeLayer's TileMap storage details.
	return _editor_grid_rect()


func editor_hover_cell() -> Variant:
	return _editor_hover_cell


func editor_preview_chunk() -> SpecialChunkDef:
	return _editor_preview_chunk


func editor_selected_origin() -> Variant:
	return _editor_selected_origin


func editor_placement_is_valid(placement: ChunkPaintPlacementDef) -> bool:
	return _placement_is_valid(placement)


func _editor_grid_rect() -> Rect2i:
	var parent: Node = get_parent()
	if parent != null:
		for sibling: Node in parent.get_children():
			if sibling is BiomeLayer:
				var biome_layer: BiomeLayer = sibling as BiomeLayer
				var used: Rect2i = biome_layer.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					return used
	var origins: Array[Vector2i] = get_origin_cells()
	if origins.is_empty():
		return Rect2i()
	var min_cell: Vector2i = origins[0]
	var max_cell: Vector2i = origins[0]
	for cell: Vector2i in origins:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


func _placement_is_valid(placement: ChunkPaintPlacementDef) -> bool:
	if placement == null:
		return false
	# Tool scripts cannot call methods on placeholder instances. Keep drawing and
	# validation quiet while the editor is reloading scripts, then use the real
	# resource method once its script is available in tool mode.
	if Engine.is_editor_hint():
		var placement_script: Script = placement.get_script() as Script
		if placement_script != null and not placement_script.is_tool():
			return false
	return placement.is_valid()


func _placement_contains_cell(placement: ChunkPaintPlacementDef, cell: Vector2i) -> bool:
	var size: Vector2i = placement.chunk_def.size_in_chunks
	return cell.x >= placement.origin.x \
		and cell.y >= placement.origin.y \
		and cell.x < placement.origin.x + size.x \
		and cell.y < placement.origin.y + size.y


func _rects_overlap(a_origin: Vector2i, a_size: Vector2i, b_origin: Vector2i, b_size: Vector2i) -> bool:
	return a_origin.x < b_origin.x + b_size.x \
		and a_origin.x + a_size.x > b_origin.x \
		and a_origin.y < b_origin.y + b_size.y \
		and a_origin.y + a_size.y > b_origin.y


func _duplicate_placement(placement: ChunkPaintPlacementDef) -> ChunkPaintPlacementDef:
	if placement == null:
		return null
	var duplicate: ChunkPaintPlacementDef = ChunkPaintPlacementDef.new()
	duplicate.chunk_def = placement.chunk_def
	duplicate.origin = placement.origin
	return duplicate
