@tool
class_name ChunkLayer
extends Node2D

## Editor-authored layer for fixed SpecialChunk placements.
##
## This is intentionally NOT a TileMapLayer. A runtime chunk is not a tile: normal
## chunk contents are generated dynamically by the Piece system. ChunkLayer stores
## only authored SpecialChunk origins that must reserve their footprint and override
## procedural generation at those cells.
@export var palette_chunks: Array[SpecialChunkDef] = []
@export var placements: Array[ChunkPaintPlacementDef] = []

@export_category("Editor visualization")
@export var draw_grid: bool = true
@export var draw_fixed_chunks: bool = true
@export var draw_labels: bool = true
@export_range(0.0, 1.0, 0.05) var fixed_chunk_alpha: float = 0.28
@export_range(0.0, 1.0, 0.05) var hover_alpha: float = 0.18
@export var grid_color: Color = Color(0.95, 0.55, 0.15, 0.52)
@export var grid_line_width: float = 1.0
@export var fixed_chunk_border_width: float = 3.0

var _editor_hover_cell: Variant = null
var _editor_preview_chunk: SpecialChunkDef = null
var _editor_redraw_accumulator: float = 0.0


func _ready() -> void:
	visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_editor_redraw_accumulator += delta
	if _editor_redraw_accumulator >= 0.2:
		_editor_redraw_accumulator = 0.0
		queue_redraw()


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


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if draw_grid:
		_draw_grid()
	if draw_fixed_chunks:
		for placement: ChunkPaintPlacementDef in placements:
			_draw_placement(placement)
	_draw_hover_preview()


func _draw_grid() -> void:
	var rect: Rect2i = _editor_grid_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var size: float = float(chunk_size())
	var left: float = float(rect.position.x) * size
	var right: float = float(rect.end.x) * size
	var top: float = float(rect.position.y) * size
	var bottom: float = float(rect.end.y) * size
	for x: int in range(rect.position.x, rect.end.x + 1):
		var px: float = float(x) * size
		draw_line(Vector2(px, top), Vector2(px, bottom), grid_color, grid_line_width)
	for y: int in range(rect.position.y, rect.end.y + 1):
		var py: float = float(y) * size
		draw_line(Vector2(left, py), Vector2(right, py), grid_color, grid_line_width)


func _draw_placement(placement: ChunkPaintPlacementDef) -> void:
	if not _placement_is_valid(placement):
		return
	var chunk_def: SpecialChunkDef = placement.chunk_def
	var rect: Rect2 = cell_rect(placement.origin, chunk_def.size_in_chunks)
	var fill: Color = chunk_def.editor_color
	fill.a = fixed_chunk_alpha
	if chunk_def.editor_preview != null:
		draw_texture_rect(chunk_def.editor_preview, rect, false, Color(1.0, 1.0, 1.0, maxf(fixed_chunk_alpha, 0.72)))
	else:
		draw_rect(rect, fill, true)
	var border: Color = chunk_def.editor_color
	border.a = 0.96
	draw_rect(rect, border, false, fixed_chunk_border_width)
	if draw_labels:
		_draw_chunk_label(rect, chunk_def)


func _draw_hover_preview() -> void:
	if not _editor_hover_cell is Vector2i:
		return
	var cell: Vector2i = _editor_hover_cell
	var size_in_chunks: Vector2i = Vector2i.ONE
	var preview_color: Color = Color(0.9, 0.9, 0.9, hover_alpha)
	if _editor_preview_chunk != null:
		size_in_chunks = _editor_preview_chunk.size_in_chunks
		preview_color = _editor_preview_chunk.editor_color
		preview_color.a = hover_alpha
	var rect: Rect2 = cell_rect(cell, size_in_chunks)
	draw_rect(rect, preview_color, true)
	var border: Color = preview_color
	border.a = 0.9
	draw_rect(rect, border, false, 2.0)


func _draw_chunk_label(rect: Rect2, chunk_def: SpecialChunkDef) -> void:
	var text: String = chunk_def.display_name.strip_edges()
	if text.is_empty():
		text = str(chunk_def.id)
	if text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(16, ThemeDB.fallback_font_size)
	var baseline: Vector2 = rect.position + Vector2(10.0, float(font_size) + 8.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0, font_size, Color(1, 1, 1, 0.95))


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
