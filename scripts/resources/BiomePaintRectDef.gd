class_name BiomePaintRectDef
extends Resource

## Bootstrap-only authored rectangle used when a WorldLayout scene has no saved
## TileMap cells yet. Once the TileMap is painted/saved, the real TileMap data wins.
@export var biome: BiomeConfig
@export var rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ONE)


func is_valid() -> bool:
	return biome != null and biome.is_valid() and rect.size.x > 0 and rect.size.y > 0
