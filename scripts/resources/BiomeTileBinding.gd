class_name BiomeTileBinding
extends Resource

## Data-only bridge between one TileSet tile and a BiomeConfig. Runtime systems
## never interpret source/atlas IDs directly; BiomeLayer owns that storage detail.
@export var biome: BiomeConfig
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0


func is_valid() -> bool:
	return biome != null and biome.is_valid() and source_id >= 0 and alternative_tile >= 0


func matches(p_source_id: int, p_atlas_coords: Vector2i, p_alternative_tile: int) -> bool:
	return source_id == p_source_id \
		and atlas_coords == p_atlas_coords \
		and alternative_tile == p_alternative_tile
