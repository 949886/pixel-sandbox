@tool
class_name BiomeLayer
extends TileMapLayer

## Visual authoring layer for macro biome ownership. One cell corresponds to one
## runtime chunk. Tile IDs are storage details resolved through data bindings.
@export var bindings: Array[BiomeTileBinding] = []


func _ready() -> void:
	# The macro layout is editor data, not runtime world rendering.
	visible = Engine.is_editor_hint()


func get_biome_config(cell: Vector2i) -> BiomeConfig:
	var source_id: int = get_cell_source_id(cell)
	if source_id < 0:
		return null
	var atlas_coords: Vector2i = get_cell_atlas_coords(cell)
	var alternative_tile: int = get_cell_alternative_tile(cell)
	for binding: BiomeTileBinding in bindings:
		if binding != null and binding.matches(source_id, atlas_coords, alternative_tile):
			return binding.biome
	return null


func set_biome_cell(cell: Vector2i, biome: BiomeConfig) -> bool:
	if biome == null:
		erase_cell(cell)
		return true
	var binding: BiomeTileBinding = _binding_for_biome(biome)
	if binding == null:
		return false
	set_cell(cell, binding.source_id, binding.atlas_coords, binding.alternative_tile)
	return true


func export_biome_ids() -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in get_used_cells():
		var biome: BiomeConfig = get_biome_config(cell)
		if biome != null and biome.id != &"":
			result[cell] = biome.id
	return result


func apply_bootstrap_rects(entries: Array[BiomePaintRectDef]) -> bool:
	var success: bool = true
	for entry: BiomePaintRectDef in entries:
		if entry == null or not entry.is_valid():
			success = false
			continue
		for y: int in range(entry.rect.position.y, entry.rect.end.y):
			for x: int in range(entry.rect.position.x, entry.rect.end.x):
				if not set_biome_cell(Vector2i(x, y), entry.biome):
					success = false
	return success


func validate_bindings(known_biomes: Array[BiomeConfig]) -> bool:
	if tile_set == null or tile_set.tile_size != Vector2i(PieceWorldConstants.CHUNK_SIZE, PieceWorldConstants.CHUNK_SIZE):
		return false
	var known_ids: Dictionary = {}
	for biome: BiomeConfig in known_biomes:
		if biome != null and biome.id != &"":
			known_ids[biome.id] = true
	var seen_tile_keys: Dictionary = {}
	for binding: BiomeTileBinding in bindings:
		if binding == null or not binding.is_valid() or not known_ids.has(binding.biome.id):
			return false
		var key: String = _tile_key(binding.source_id, binding.atlas_coords, binding.alternative_tile)
		if seen_tile_keys.has(key):
			return false
		seen_tile_keys[key] = true
	for cell: Vector2i in get_used_cells():
		if get_biome_config(cell) == null:
			return false
	return true


func _binding_for_biome(biome: BiomeConfig) -> BiomeTileBinding:
	for binding: BiomeTileBinding in bindings:
		if binding != null and binding.biome == biome:
			return binding
	return null


func _tile_key(source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> String:
	return "%d:%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]
