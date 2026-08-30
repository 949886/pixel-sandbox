class_name WorldLayoutSnapshot
extends RefCounted

## Immutable-at-runtime, thread-readable macro world data compiled from the editor
## TileMapLayers on the main thread. Background generation must only read this
## snapshot, never TileMapLayer nodes.
var biome_by_cell: Dictionary = {}
var fixed_chunk_id_by_origin: Dictionary = {}
var fixed_chunk_origin_by_cell: Dictionary = {}
var anchor_data_by_id: Dictionary = {}
var used_rect: Rect2i = Rect2i()
var chunk_size: int = PieceWorldConstants.CHUNK_SIZE


func has_world_cell(coord: Vector2i) -> bool:
	return biome_by_cell.has(coord)


func get_biome_id(coord: Vector2i) -> StringName:
	return StringName(biome_by_cell.get(coord, &""))


func get_fixed_chunk_id_at_origin(coord: Vector2i) -> StringName:
	return StringName(fixed_chunk_id_by_origin.get(coord, &""))


func get_fixed_chunk_origin(coord: Vector2i) -> Variant:
	return fixed_chunk_origin_by_cell.get(coord, null)


func is_fixed_chunk_cell(coord: Vector2i) -> bool:
	return fixed_chunk_origin_by_cell.has(coord)


func get_anchor_position(anchor_id: StringName) -> Variant:
	var data: Variant = anchor_data_by_id.get(anchor_id, null)
	if data is Dictionary:
		return (data as Dictionary).get(&"position", null)
	return null


func get_anchor_clearance_radius(anchor_id: StringName) -> float:
	var data: Variant = anchor_data_by_id.get(anchor_id, null)
	if data is Dictionary:
		return maxf(0.0, float((data as Dictionary).get(&"clearance_radius", 0.0)))
	return 0.0


func get_anchor_clearance_offset(anchor_id: StringName) -> Vector2:
	var data: Variant = anchor_data_by_id.get(anchor_id, null)
	if data is Dictionary:
		var value: Variant = (data as Dictionary).get(&"clearance_offset", Vector2.ZERO)
		if value is Vector2:
			return value
	return Vector2.ZERO


func get_anchor_cell(anchor_id: StringName) -> Variant:
	var position: Variant = get_anchor_position(anchor_id)
	if not position is Vector2 or chunk_size <= 0:
		return null
	var world_position: Vector2 = position
	return Vector2i(
		floori(world_position.x / float(chunk_size)),
		floori(world_position.y / float(chunk_size))
	)


func is_valid() -> bool:
	if chunk_size <= 0 or biome_by_cell.is_empty():
		return false
	for coord_value: Variant in fixed_chunk_origin_by_cell.keys():
		var coord: Vector2i = coord_value
		if not biome_by_cell.has(coord):
			return false
	for anchor_id_value: Variant in anchor_data_by_id.keys():
		var anchor_id := StringName(anchor_id_value)
		if anchor_id == &"":
			return false
		var position: Variant = get_anchor_position(anchor_id)
		if not position is Vector2:
			return false
	return true
