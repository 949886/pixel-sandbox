# World Layout Authoring

This project authors the **macro world** in Godot and keeps the **micro terrain** procedural.
The world layout deliberately does **not** introduce a Region layer.

```text
WorldDefinition
  -> WorldLayout (scene)
      -> BiomeLayer : TileMapLayer
      -> ChunkLayer : Node2D
      -> WorldAnchor nodes
  -> WorldLayoutSnapshot (runtime, thread-readable)
      -> WorldStructureBuilder
      -> SpecialChunkPlanner
      -> PieceChunkGenerator
```

The default layout is referenced by `WorldDefinition.layout_scene`. Runtime/editor code must resolve
that reference through configured resources; do not add a script-path or scene-path literal to find it.

## Editor entry points

The enabled **World Layout Editor** plugin adds three entry points:

1. A Godot 4.7 **EditorDock** named **World Layout**. The plugin focuses it once when loaded so it cannot remain hidden in an old editor layout.
2. A **World Layout** navigation group in the 2D toolbar whenever `Main`, `World`, or a `WorldLayout` scene is active.
3. **Tools > Open Current World Layout**.

When `Main` or `World` is the edited scene, the plugin searches the scene's configured
`WorldGenConfig`/template, resolves its `WorldDefinition`, and opens the referenced layout scene.
No default world path is encoded in the plugin.

`Main.tscn` remains a runtime bootstrap scene and therefore intentionally does not embed or duplicate the map. Its central 2D canvas can remain empty in edit mode; that is not the world authoring surface. The expected workflow is: open `Main` -> use either the visible 2D toolbar group or the **World Layout** dock -> **Open World Layout**. This keeps runtime composition data-driven while making the authored world one click away.

If neither the dock nor the toolbar group appears, the editor plugin did not compile or is disabled. Resolve every GDScript parse error first, then verify **Project > Project Settings > Plugins > World Layout Editor** is enabled.

The same 2D toolbar group is visible from `Main`/`World` and opens the configured layout. When a `WorldLayout` scene is already open, it changes focus inside that scene and exposes:

- **Biomes** — selects `BiomeLayer` and uses Godot's normal TileMap tools.
- **Fixed Chunks** — selects the independent `ChunkLayer` and enables Select/Paint/Erase/Pick tools.
- **Anchors** — selects the semantic `WorldAnchor` nodes.
- **Validate** — compiles a snapshot using an open matching `WorldGenConfig` context.

Biome colors, fixed chunk footprints/grid, and anchor markers are visible together. The dock can toggle
those overlays independently.

## Tool-mode dependency rule

The World Layout UI executes inside the Godot editor. Every instantiated custom GDScript object whose
properties or methods are read by that `@tool` code must also declare `@tool`. This includes the authoring
resources and validation snapshot, not only the visible Node scripts:

```text
WorldGenConfig / WorldDefinition / WorldStructureProfile
BiomeConfig / BiomeTileBinding / BiomePaintRectDef
WorldLayoutPreset / WorldLayoutSnapshot
ChunkPaintPlacementDef / SpecialChunkDef / SpawnAnchorDef
```

Without this closure, Godot creates a placeholder script instance. Exported data may still appear in the
Inspector, but calling a method such as `ChunkPaintPlacementDef.is_valid()` fails in editor drawing code.
Static-only helpers such as constants/enums are allowed to remain non-tool. `WorldLayoutSmokeTest` checks
`Script.is_tool()` for the editor resource graph to prevent regressions. After changing tool annotations,
fully restart Godot so previously cached placeholder instances are discarded.

## Coordinate contract

- One `BiomeLayer` cell is exactly one runtime chunk.
- `ChunkLayer` placements use exactly the same chunk coordinate space.
- Runtime chunk size is `PieceWorldConstants.CHUNK_SIZE` (currently 512 world pixels).
- `Vector2i` world-layout cell coordinates and runtime chunk coordinates are identical.
- An empty `BiomeLayer` cell is **VOID**. No procedural chunk is generated there.
- `WorldStructureProfile` contains topology tuning only. It does **not** own a second world rectangle;
  structure bounds are derived from the authored Biome cells.

## BiomeLayer

`BiomeLayer` is the authoritative answer to **where a biome exists**.
`BiomeConfig` only answers **how that biome generates**.

`BiomeLayer` intentionally inherits `TileMapLayer`, because biome ownership is a regular grid and
Godot's native TileMap painting workflow is useful here. One tile is only an editor/storage proxy.
Runtime code never interprets numeric source/atlas IDs directly:

```text
TileMap cell
  -> BiomeTileBinding
  -> BiomeConfig
```

The default layout stores its painted cells directly in `TileMapLayer.tile_map_data`. It does not rely
on a bootstrap preset to appear in the editor. `WorldLayoutPreset` remains available only as an
optional migration/new-layout seeding helper.

To add a biome:

1. Create/configure a `BiomeConfig` resource and register it in `WorldGenConfig.biome_configs`.
2. Add an editor tile to the Biome TileSet.
3. Add a `BiomeTileBinding` mapping that tile to the Biome resource.
4. Paint the desired cells and save the layout scene.

Do not add depth bands, `if biome_id == ...`, numeric TileSet ID branches, or resource paths to world
generation code.

## ChunkLayer

`ChunkLayer` is **not** a `TileMapLayer` and must never become one.

It is an independent `Node2D` authoring component whose serialized data is:

```text
ChunkLayer
  -> placements: Array[ChunkPaintPlacementDef]
       -> origin: Vector2i
       -> chunk_def: SpecialChunkDef
```

Only fixed, hand-authored `SpecialChunkDef` placements are stored. Ordinary runtime chunks do not
exist in this layer at all; the Piece system fills them procedurally.

Resolution is therefore:

```text
Biome cell exists?
  no  -> VOID
  yes -> authored fixed SpecialChunk occupies this cell?
           yes -> fixed SpecialChunk owns the full authored footprint
           no  -> Piece system generates a procedural chunk for the Biome
```

The custom editor tools provide TileMap-like interaction without TileMap storage:

- Select (Q)
- Paint (W)
- Erase (E)
- Pick (R)
- SpecialChunk palette
- multi-cell footprint preview
- overlap/VOID/allowed-biome checks
- Undo/Redo

`SpecialChunkDef.size_in_chunks` defines the occupied footprint. Designers place only the origin.
Fixed chunks are reserved before random special chunks and procedural Piece generation, and runtime
attachment performs additional guards so an asynchronous procedural result cannot overwrite them.

There is deliberately no `ChunkTileBinding`, Chunk TileSet, scene tile, source ID, atlas coordinate,
or alternative-tile protocol for fixed chunks.

## WorldAnchor

`WorldAnchor` is a semantic `Marker2D` with an always-visible editor marker/label. `WorldDefinition`
selects required anchors by ID, currently including player spawn, main surface entrance, main path
start, and optional main path end.

Important positions are authored as anchors, not hard-coded coordinates in `WorldManager`, `Player`,
or `GameBootstrap`.

## Runtime and threading

The scene-based authoring representation is compiled on the main thread into a
`WorldLayoutSnapshot` before background generation begins. The snapshot contains plain thread-readable
values only:

- biome ID by cell,
- fixed chunk ID by origin,
- fixed-chunk occupancy,
- anchor data,
- used bounds.

Background workers must never access `TileMapLayer`, `ChunkLayer`, the SceneTree, or instantiate layout
scenes.

## Default surface

The default authored layout demonstrates the intended world philosophy:

- a fixed authored surface strip,
- safe player spawn,
- a fixed multi-cell right/down mine entrance,
- irregular 2D Mine/Snow/Deep macro shapes,
- procedural underground chunks everywhere not explicitly overridden.

Surface and underground remain one continuous pixel simulation coordinate space. There is no level
transition at the entrance.

## Validation checklist

Before committing a World Layout change:

1. Open the World Layout dock from `Main`/`World` and jump to the active layout.
2. Ensure every intended world cell has a Biome tile; empty cells intentionally mean VOID.
3. Ensure every fixed chunk is placed only once at its origin.
4. Verify multi-cell footprints do not overlap or enter VOID.
5. Keep required `WorldAnchor` nodes inside authored Biome cells.
6. Press **Validate Layout** in the dock.
7. Run `WorldLayoutSmokeTest.tscn` and affected runtime smoke tests.
8. Do not introduce GDScript resource/script path literals or numeric tile-to-content tables.
