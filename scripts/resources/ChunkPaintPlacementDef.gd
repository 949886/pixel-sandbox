class_name ChunkPaintPlacementDef
extends Resource

## Authoring data for one fixed SpecialChunk origin. ChunkLayer stores an array of
## these resources directly; multi-cell occupancy is derived from the referenced
## SpecialChunkDef instead of duplicating size data here.
@export var chunk_def: SpecialChunkDef
@export var origin: Vector2i = Vector2i.ZERO


func is_valid() -> bool:
	return chunk_def != null and chunk_def.id != &"" \
		and chunk_def.size_in_chunks.x > 0 and chunk_def.size_in_chunks.y > 0
