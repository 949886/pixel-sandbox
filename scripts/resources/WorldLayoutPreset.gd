class_name WorldLayoutPreset
extends Resource

## Optional bootstrap data for a new WorldLayout. It is deliberately not the
## authoritative runtime format: saved TileMapLayer cells are authoritative.
@export var biome_rects: Array[BiomePaintRectDef] = []
@export var fixed_chunks: Array[ChunkPaintPlacementDef] = []


func is_valid() -> bool:
	if biome_rects.is_empty():
		return false
	for entry: BiomePaintRectDef in biome_rects:
		if entry == null or not entry.is_valid():
			return false
	for placement: ChunkPaintPlacementDef in fixed_chunks:
		if placement == null or not placement.is_valid():
			return false
	return true
