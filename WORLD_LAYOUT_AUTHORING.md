# World Layout Authoring

This project authors the **macro world** in Godot and keeps the **micro terrain** procedural.
The world layout deliberately does **not** introduce a Region layer.

```text
WorldDefinition
  -> WorldLayout (scene)
      -> BiomeLayer : TileMapLayer
      -> ChunkLayer : Node2D (independent fixed-SpecialChunk authoring layer)
      -> WorldAnchor nodes
  -> WorldLayoutSnapshot (runtime, thread-readable)
      -> WorldStructureBuilder
      -> SpecialChunkPlanner
      -> PieceChunkGenerator
```

The default layout is `scenes/world_layout/DefaultWorldLayout.tscn` and is referenced by
`resources/world_layout/default_world_definition.tres`.

## Coordinate contract

- One `BiomeLayer` cell is exactly one runtime chunk.
- `ChunkLayer` uses the same integer chunk-coordinate grid, but it is **not a TileMap** and stores no tile IDs.
- Runtime chunk size is `PieceWorldConstants.CHUNK_SIZE` (currently 512 world pixels).
- `Vector2i` world-layout cell coordinates and runtime chunk coordinates are the same coordinate space.
- An empty `BiomeLayer` cell is **VOID**. No procedural or fixed chunk may occupy it.
- `WorldStructureProfile` contains topology tuning only. It does **not** own min/max world bounds; structure bounds are derived from the painted Biome cells.

Do not change this relationship locally in a generator. If chunk size changes, update the shared world constants and the Biome TileSet together. `ChunkLayer` reads the same shared chunk-size constant and therefore does not have a second cell-size asset to maintain.

## BiomeLayer

`BiomeLayer` is the authoritative answer to **where a biome exists**.
`BiomeConfig` only answers **how that biome generates**.

`BiomeLayer` intentionally inherits `TileMapLayer` because biome ownership really is a regular categorical grid. Open `DefaultWorldLayout.tscn`, select `BiomeLayer`, then use Godot's normal TileMap painting tools: paint, erase, rectangle, selection, copy/paste, and the visible grid.

The default palette contains Surface, Mine, Snow and Deep. The visual tile is only an editor/storage representation. Runtime code must never interpret atlas/source integer IDs. The mapping is data:

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

`ChunkLayer` is an independent authored **fixed SpecialChunk placement layer**. It deliberately extends `Node2D`, not `TileMapLayer`.

This distinction is architectural:

- A normal runtime chunk is **not a tile**. It is dynamically filled by the Piece system from the current Biome and world topology.
- `ChunkLayer` stores only the exceptional chunks whose exact placement was authored by a designer.
- A fixed SpecialChunk reserves its complete `size_in_chunks` footprint before any random SpecialChunk or Piece generation is considered.
- Procedural generation must never replace or paint over a fixed placement.

The stored model is direct content data:

```text
ChunkLayer
  -> Array[ChunkPaintPlacementDef]
       -> origin: Vector2i
       -> chunk_def: SpecialChunkDef
```

There is no `ChunkTileBinding`, TileSet source ID, atlas coordinate, alternative tile, or Scene Tile involved.

### ChunkLayer editor tools

The project enables the `World Layout Chunk Layer Editor` plugin. Select the `ChunkLayer` node in a 2D scene to get a dedicated toolbar:

- **Select (Q)**: normal Godot 2D selection; ChunkLayer does not consume paint input.
- **Paint (W)**: place the selected fixed `SpecialChunkDef` on the chunk grid; left-drag paints multiple origins.
- **Erase (E)**: erase the fixed placement under the cursor; clicking any occupied cell removes the whole multi-cell placement.
- **Pick (R)**: pick an existing fixed SpecialChunk into the palette, then return to Paint mode.
- **Right click** while a ChunkLayer paint tool is active: erase the fixed placement under the cursor.
- Every edit participates in the editor Undo/Redo history.

`ChunkLayer.palette_chunks` is data-driven and defines which SpecialChunks are offered by the toolbar. Adding a fixed chunk to the palette requires only assigning the resource; the editor plugin does not contain project chunk IDs or resource paths.

The layer draws its own chunk grid and fixed footprints in editor space. If `SpecialChunkDef.editor_preview` is assigned, that texture is drawn in the footprint; otherwise `editor_color` and the display name are used. Multi-cell footprints come from `SpecialChunkDef.size_in_chunks` and therefore cannot disagree with runtime occupancy.

A fixed placement is rejected when it:

- overlaps another fixed placement,
- extends into a VOID Biome cell,
- uses a biome outside `SpecialChunkDef.allowed_biomes`, or
- references a chunk definition that is not registered by the active `WorldGenConfig` during snapshot validation.

The editor performs the first three checks immediately; snapshot compilation repeats authoritative validation so malformed scene/resource data cannot silently enter runtime.

### Fixed chunk priority

Fixed authored placements have strict priority:

```text
requested world cell
  -> VOID?                       => no chunk
  -> inside authored fixed chunk? => SpecialChunkManager owns it
  -> otherwise                    => PieceChunkGenerator may generate it
```

`SpecialChunkPlanner` plans authored placements first. Random SpecialChunks reject any cell already reserved by those placements. `WorldManager` also skips normal Piece requests for every cell owned by a SpecialChunk and re-checks ownership before attaching asynchronous generation results. This double gate prevents a late worker result from overwriting an authored chunk.

A fixed chunk does **not** replace the underlying Biome. Ambience, encounter/loot policy and other Biome semantics still come from `BiomeLayer`; only that footprint's terrain/structure source is fixed.

## WorldAnchor

Use `WorldAnchor` (`Marker2D`) for semantic world positions. `WorldDefinition` currently selects:

- player spawn,
- main surface entrance,
- main procedural path start,
- optional main procedural path end.

The selected anchors must be located inside authored Biome cells. Player spawn also carries a clearance radius/offset; `WorldManager` clears that safety area after the pixel chunk exists, which is a final guard against the player being trapped by generated material.

Do not use magic spawn coordinates in `WorldManager`, `Player`, or `GameBootstrap`.

## Bootstrap preset vs saved authoring data

`WorldLayoutPreset` exists only to seed a new/empty WorldLayout.

- Biome bootstrap data is copied into `BiomeLayer` when that layer has no painted cells.
- Fixed chunk bootstrap data is copied into `ChunkLayer.placements` when the independent ChunkLayer has no placements.
- Saved Biome cells and saved ChunkLayer placements are authoritative.
- After authoring the layout, save the scene normally.
- If an intentionally empty layout is required, set `use_bootstrap_when_empty = false` instead of relying on an invalid/empty preset.

## Runtime and threading

Editor scene nodes are authoring/storage backends, not runtime world generators.

Before background generation starts, the main thread compiles the layout scene into a `WorldLayoutSnapshot`. The snapshot contains only thread-readable dictionaries/values:

- biome ID by cell,
- fixed chunk ID by origin,
- fixed-chunk occupancy,
- anchors,
- used bounds.

Background workers read only this snapshot. They must never call `BiomeLayer`, `ChunkLayer`, access the scene tree, or instantiate layout scenes.

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
- procedural underground chunks everywhere not explicitly reserved by `ChunkLayer`.

The surface and underground remain one continuous pixel simulation coordinate space. There is no scene transition between them, so liquids, fire, explosions and digging can cross the entrance naturally.

## Validation checklist

Before committing a world-layout change:

1. Open the layout scene and ensure every intended world cell has a Biome tile.
2. Select `ChunkLayer` and verify fixed chunks appear as dedicated overlays, not TileMap tiles.
3. Ensure fixed chunks are placed only once at their origin and multi-cell footprints do not overlap or extend into VOID.
4. Keep important `WorldAnchor` nodes inside valid Biome cells.
5. Run `WorldLayoutSmokeTest.tscn`.
6. Run the existing gameplay/runtime smoke tests affected by world startup.
7. Do not introduce GDScript resource/script path literals, numeric tile-to-content `match` tables, or a TileMap-based ChunkLayer.
