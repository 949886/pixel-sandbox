# World Layout Authoring

This project authors the **macro world** in Godot and keeps the **micro terrain** procedural.
The world layout deliberately does **not** introduce a Region layer.

```text
WorldDefinition
  -> WorldLayout (scene)
      -> BiomeLayer : TileMapLayer
      -> ChunkLayer : TileMapLayer
      -> WorldAnchor nodes
  -> WorldLayoutSnapshot (runtime, thread-readable)
      -> WorldStructureBuilder
      -> SpecialChunkPlanner
      -> PieceChunkGenerator
```

The default layout is `scenes/world_layout/DefaultWorldLayout.tscn` and is referenced by
`resources/world_layout/default_world_definition.tres`.

## Coordinate contract

- One `BiomeLayer` / `ChunkLayer` cell is exactly one runtime chunk.
- Runtime chunk size is `PieceWorldConstants.CHUNK_SIZE` (currently 512 world pixels).
- `Vector2i` world-layout cell coordinates and runtime chunk coordinates are the same coordinate space.
- An empty `BiomeLayer` cell is **VOID**. No procedural chunk is generated there.
- `ChunkLayer` does not create a new coordinate system; it only overrides selected world-layout cells.
- `WorldStructureProfile` contains topology tuning only. It does **not** own min/max world bounds; structure bounds are derived from the painted Biome cells.

Do not change this relationship locally in a generator. If chunk size changes, update the shared
world constants and the editor TileSets together.

## BiomeLayer

`BiomeLayer` is the authoritative answer to **where a biome exists**.
`BiomeConfig` only answers **how that biome generates**.

Open `DefaultWorldLayout.tscn`, select `BiomeLayer`, then use Godot's normal TileMap painting tools:
paint, erase, rectangle, selection, copy/paste, and the visible grid.

The default palette contains Surface, Mine, Snow and Deep. The visual tile is only an editor/storage
representation. Runtime code must never interpret atlas/source integer IDs. The mapping is data:

```text
TileSet cell -> BiomeTileBinding -> BiomeConfig
```

To add a biome:

1. Create/configure a `BiomeConfig` resource and register it in `WorldGenConfig.biome_configs`.
2. Add a visual tile to the Biome TileSet/atlas.
3. Add a `BiomeTileBinding` on `BiomeLayer` that connects that tile to the resource.
4. Paint the desired cells in the editor.

Do **not** add `if biome_id == ...`, depth bands, hard-coded TileSet IDs, or resource paths to generation code.

## ChunkLayer

`ChunkLayer` is an authored **fixed-chunk override** layer.

- Empty cell: use normal procedural generation from `BiomeLayer`.
- Painted cell: this cell is the **origin** of a fixed `SpecialChunkDef`.
- Multi-cell footprint: derived from `SpecialChunkDef.size_in_chunks`.
- A fixed chunk does not replace the biome. Biome ambience/gameplay semantics still come from `BiomeLayer`.

The mapping is also data-driven:

```text
TileSet cell -> ChunkTileBinding -> SpecialChunkDef
```

The editor draws a translucent footprint around multi-cell fixed chunks. Only paint the origin tile;
do not manually paint every occupied cell.

A fixed chunk is rejected during snapshot compilation when it:

- overlaps another fixed chunk,
- occupies VOID,
- references a chunk definition not present in the active `WorldGenConfig`, or
- occupies a biome outside `SpecialChunkDef.allowed_biomes`.

Surface spawn and surface entrance are implemented using the same generic fixed-chunk mechanism; the
runtime does not special-case their resource paths or IDs.

## WorldAnchor

Use `WorldAnchor` (`Marker2D`) for semantic world positions. `WorldDefinition` currently selects:

- player spawn,
- main surface entrance,
- main procedural path start,
- optional main procedural path end.

The selected anchors must be located inside authored Biome cells. Player spawn also carries a
clearance radius/offset; `WorldManager` clears that safety area after the pixel chunk exists, which is
a final guard against the player being trapped by generated material.

Do not use magic spawn coordinates in `WorldManager`, `Player`, or `GameBootstrap`.

## Bootstrap preset vs saved TileMap data

`WorldLayoutPreset` exists only to seed the default scene while its TileMap layers are empty. This is
useful for source-controlled scenes because designers can immediately open the scene and see/edit a
working macro layout.

Rules:

- If a layer already contains saved TileMap cells, saved cells are authoritative.
- Bootstrap only fills an empty layer.
- After painting the layout, save the scene normally.
- If an intentionally empty layout is required, set `use_bootstrap_when_empty = false` instead of relying
  on an invalid/empty preset.

## Runtime and threading

`TileMapLayer` is an **authoring/storage backend**, not a runtime world generator.

Before background generation starts, the main thread compiles the layout scene into a
`WorldLayoutSnapshot`. The snapshot contains only thread-readable dictionaries/values:

- biome ID by cell,
- fixed chunk ID by origin,
- fixed-chunk occupancy,
- anchors,
- used bounds.

Background workers read only this snapshot. They must never call `TileMapLayer`, access the scene tree,
or instantiate layout scenes.

Runtime resolution for a chunk is conceptually:

```text
if layout cell is VOID:
    do not generate
elif cell belongs to a fixed chunk:
    SpecialChunkPlanner / SpecialChunkManager owns its authored terrain
else:
    biome = BiomeLayer snapshot value
    PieceChunkGenerator generates procedural terrain for that biome
```

## Default surface

The default layout demonstrates the intended world philosophy:

- a fixed authored surface strip,
- a safe player spawn on the surface,
- a fixed 1x2 right/down mine entrance,
- an irregular 2D Mine/Snow/Deep macro map,
- procedural underground chunks everywhere not explicitly overridden.

The surface and underground remain one continuous pixel simulation coordinate space. There is no scene
transition between them, so liquids, fire, explosions and digging can cross the entrance naturally.

## Validation checklist

Before committing a world-layout change:

1. Open the layout scene and ensure every intended world cell has a Biome tile.
2. Ensure fixed chunks are painted only once at their origin.
3. Check multi-cell footprints do not overlap or extend into VOID.
4. Keep important `WorldAnchor` nodes inside valid Biome cells.
5. Run `WorldLayoutSmokeTest.tscn`.
6. Run the existing gameplay/runtime smoke tests affected by world startup.
7. Do not introduce GDScript resource/script path literals or numeric tile-to-content `match` tables.
