# Gameplay V4.5 — Creative Sandbox + Wand Lab

V4.5 adds a first-class Creative game mode rather than a collection of UI cheats. The mode is controlled by `GameModeManager` and `GameRules`, and the player/combat/wand systems expose explicit runtime switches for invulnerability, infinite mana, infinite flight, and no-collision creative flight.

## Creative UI

The Creative UI takes its interaction model from the existing `painting/` sandbox: a collapsible bottom dock leaves most of the world visible while exposing focused tool tabs. It deliberately does **not** reuse the painting module's independent `SandSimulation` or its per-pixel GDScript painter.

Tabs in this pass:

- **MATERIALS** — brush, eraser, picker, brush radius, and a palette generated from the live `MaterialPalette`.
- **SPELLS** — unlimited `SpellCatalog` library with search/type filtering. Click adds to the first empty slot; drag places a spell into an exact slot of the selected Wand.
- **WANDS** — select four runtime Wand slots, create/duplicate/delete/clear, edit Mana/Recharge/Cast Delay/Reload/Capacity/Spread/Spells-per-cast/Shuffle, and reorder the live deck.
- **PLAYER** — invulnerability, infinite mana, infinite flight, no-clip creative fly, heal, and clear statuses.
- **WORLD** — current sandbox notes; entity spawning and simulation stepping are intentionally deferred.

`F8` toggles Creative Mode. In Creative Mode `Tab/I` collapses or expands the bottom dock instead of opening the normal paused inventory.

## Performance

Creative world painting calls `WorldGameplayService.paint_material_circle(..., only_replace_air=false)`. `WorldManager` routes this mode to `PixelChunkCanvas.erase_circle_local(..., replacement_element)`, which uses fallingsand's Native `erase_circle` implementation when available. The brush therefore performs one Native region operation per overlapped chunk instead of one GDScript-to-native call per pixel.

Continuous strokes interpolate between mouse samples with spacing derived from the brush radius and cap interpolation work per input event. The brush radius is capped at 64 pixels in this pass.

Spell resources are obtained from a cached `SpellCatalog`, and all icons remain direct `SpellDef.icon` resource references. Creative UI grids are rebuilt only when switching panels or changing runtime Wand contents/capacity, not every frame.

## Runtime safety / data ownership

Creative Wand operations only mutate runtime-owned `WandDef` duplicates stored by `PlayerInventory`. Source `.tres` resources are never edited. Spell definitions remain immutable shared Resources.

Deleting the last remaining Wand is rejected so the player cannot leave the Wand controller pointing at a removed runtime definition.

## Deferred from V4.5

- Entity spawning/deletion palette
- Sand simulation pause/single-step/speed controls
- World snapshots and Creative save slots
- Undo/redo for terrain edits
- Rectangle/line/fill brushes
