class_name ChunkTileBinding
extends Resource

## Data-only bridge between one TileSet tile and an authored SpecialChunkDef.
## A painted cell marks the origin of the fixed chunk; multi-cell occupancy comes
## from SpecialChunkDef.size_in_chunks and is validated by WorldLayout.
@export var chunk_def: SpecialChunkDef
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0


func is_valid() -> bool:
	return chunk_def != null \
		and chunk_def.id != &"" \
		and chunk_def.size_in_chunks.x > 0 \
		and chunk_def.size_in_chunks.y > 0 \
		and source_id >= 0 \
		and alternative_tile >= 0


func matches(p_source_id: int, p_atlas_coords: Vector2i, p_alternative_tile: int) -> bool:
	return source_id == p_source_id \
		and atlas_coords == p_atlas_coords \
		and alternative_tile == p_alternative_tile
