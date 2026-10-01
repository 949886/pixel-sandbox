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
- **Fixed Chunks** — selects the independent `ChunkLayer`, opens the bottom **Special Chunks** palette, and enables Select/Paint/Erase/Pick tools. In Select mode, click a fixed Chunk to highlight its complete footprint and show its authoring data in the World Layout Dock; double-click or use **Inspect SpecialChunkDef** to open the resource Inspector.
- **Anchors** — selects the semantic `WorldAnchor` nodes.
- **Validate** — compiles a snapshot using an open matching `WorldGenConfig` context.

Biome colors, fixed chunk footprints, and anchor markers are visible together. The orange Chunk grid is shown only while `ChunkLayer` is selected. The dock can toggle
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

### Overlay visibility

The Scene Tree eye icons are authoritative editor state. Selecting `BiomeLayer`, `ChunkLayer`, or an anchor must not force it visible. The World Layout Dock checkboxes mirror the current node visibility and only change it when the checkbox itself is toggled. Runtime still hides all authoring overlays.

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

The custom editor tools provide TileMap-like interaction without TileMap storage. **All ChunkLayer authoring graphics**—the orange grid, complete fixed-Chunk color backing, transparent art preview, footprint border, labels, selection handles, and hover preview—are rendered by the EditorPlugin as a screen-space viewport overlay, not by `ChunkLayer._draw()`. Force canvas overlay forwarding keeps authored Fixed Chunks visible as soon as a `WorldLayout` scene opens, regardless of the currently selected editor object. The orange grid is different: it is an active editing aid and is drawn only while the exact `ChunkLayer` node is selected. This keeps the default world overview clean while preserving stable screen-pixel line widths during Chunk editing. Each authored footprint is always filled with its full `SpecialChunkDef.editor_color` before an optional transparent `editor_preview` is composited, so a terrain-only PNG can never make the Chunk cell appear incomplete. Overlay bounds still come from `BiomeLayer.get_used_rect()`, so the grid visualizes the authored world rather than an independent rectangle.

- Select (Q)
- Paint (W)
- Erase (E)
- Pick (R)
- transient bottom **Special Chunks** palette
- thumbnail grid sourced from `ChunkLayer.palette_chunks`
- search by display name, content ID, allowed Biome, or Tag
- multi-Tag filters with **Match any / Match all**
- Pick tool synchronization back to the palette
- multi-cell footprint preview
- overlap/VOID/allowed-biome checks
- Undo/Redo

`SpecialChunkDef.size_in_chunks` defines the occupied footprint. Designers place only the origin.
Fixed chunks are reserved before random special chunks and procedural Piece generation, and runtime
attachment performs additional guards so an asynchronous procedural result cannot overwrite them.

There is deliberately no `ChunkTileBinding`, Chunk TileSet, scene tile, source ID, atlas coordinate,
or alternative-tile protocol for fixed chunks.

### SpecialChunk bottom palette

Selecting `ChunkLayer` opens a transient bottom `EditorDock`, matching the workflow of Godot's TileMap tools without using TileMap storage. The panel is the authoritative brush selector for fixed chunks:

```text
ChunkLayer.palette_chunks
  -> SpecialChunkPalettePanel
      -> thumbnail ItemList
      -> text search
      -> tag filter (Any / All)
      -> selected SpecialChunk brush
```

The palette must never scan a directory or infer content from file paths. Designers explicitly add resources to `ChunkLayer.palette_chunks`; the panel reads `SpecialChunkDef.display_name`, `id`, `editor_preview`, `editor_color`, `allowed_biomes`, `size_in_chunks`, and `tags`. Selecting an item switches the editor to Paint mode. The Pick tool clears incompatible filters when necessary and reveals the picked resource. Double-clicking a palette item or pressing **Inspect** opens the resource Inspector.

Tag filtering is content data, not editor code. Add reusable semantic tags such as `surface`, `ground`, `reward`, `shrine`, `large`, or `ruins` directly to `SpecialChunkDef.tags`. Do not add tag-to-resource switch statements in the plugin.

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

## Default macro depth

The default authored underground currently occupies chunk rows `0..25` below the surface row `-1`. Its broad progression is deliberately compact:

```text
Mine / Mine-to-Snow transition : y = 0..8
Snow                           : y = 7..16
Deep                           : y = 15..25
```

The overlap in the ranges above describes irregular horizontal transition rows; each individual cell still owns exactly one Biome. Changing the macro depth means repainting `BiomeLayer` and moving semantic anchors such as `main_path_end`, never adding depth thresholds back to `BiomeConfig` or the generator.

## Default surface

The default authored layout demonstrates the intended world philosophy:

- a fixed authored surface strip,
- safe player spawn,
- a fixed multi-cell right/down mine entrance,
- irregular 2D Mine/Snow/Deep macro shapes,
- procedural underground chunks everywhere not explicitly overridden.

Surface and underground remain one continuous pixel simulation coordinate space. There is no level
transition at the entrance.

## Authored material layouts for fixed chunks

A fixed `SpecialChunkDef` may reference `material_layout: Texture2D`. This is the authoritative pixel-material
source for art-critical chunks such as the surface spawn, mine entrance, shop, shrine, boss arena, and treasure
room.

Contract:

```text
texture dimensions = size_in_chunks * PieceWorldConstants.CHUNK_SIZE
transparent pixel  = air
opaque pixel       = MaterialPalette source/display color
```

For critical authored content, enable `require_material_layout`. Validation then rejects a missing or wrong-size
texture instead of silently substituting procedural placeholder art. `layout_style` remains only a fallback for
non-critical/prototype SpecialChunks.

The runtime thread contract is deliberate:

```text
SpecialChunkDef Texture2D
  -> main-thread planner extracts RGBA8 Image
  -> SpecialChunkPlacement owns Image copy
  -> background worker crops/converts/collides the Image
```

Background workers must never call `Texture2D.get_image()`, `ResourceLoader`, or SceneTree APIs.

When painting an authored material image, use exact colors already declared by `MaterialPalette`. Do not invent
nearly matching colors and depend on nearest-color fallback for final art. Alpha zero is the only authored air
representation.

## Default surface opening

The default surface is a horizontal series of fixed SpecialChunks:

```text
Left Boundary -> West Ground -> Grove -> Approach -> Spawn -> East Ground -> 1x2 Mine Entrance
```

The entrance occupies cells `(1, -1)` and `(1, 0)`. Its bottom opening is centered in socket slot 2 and uses an
`OPEN_LARGE` profile, so the first procedural Mine chunk at `(1, 1)` receives the same opening contract. Changing
the painted shaft without updating the socket profile, or changing the profile without repainting the shaft, is
invalid authoring.

The PlayerSpawn anchor sits above the authored solid surface and retains runtime clearance as defense in depth.
The MainEntrance anchor marks the visible mouth of the slope, while MainPathStart marks the first procedural
chunk below the fixed 1x2 entrance.

## World presentation

`WorldDefinition.presentation_profile` selects a `WorldPresentationProfile`. It controls background coverage,
sky/horizon/underground colors, transition depth, and deterministic surface silhouettes. `WorldBackdrop` only
executes that data; it does not know concrete world IDs or resource paths.

Transparent pixels in Surface chunks reveal this backdrop, while the same continuous backdrop darkens into the
underground without changing scenes or simulation spaces.

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
