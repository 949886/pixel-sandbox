# Gameplay V4.5.3 — Creative Sandbox Tools

V4.5.3 finishes the next safe Creative Mode sandbox layer without moving UI construction back into scripts.

## Entity Sandbox

- New ENTITIES tab in `CreativeUI.tscn`.
- Spawn Cave Eye, Gold Pickup, or Fireball Spell Pickup.
- DELETE tool only removes nodes spawned through the Creative entity controller.
- CLEAR SPAWNED removes all current Creative-spawned entities.
- Entity placement reserves the primary mouse button through the existing GameModeManager input-arbitration system, so placing/deleting entities does not fire the equipped wand.
- Entity tile UI is a PackedScene (`CreativeEntityTile.tscn`); script only binds resource data and signals.

## Simulation Lab

WORLD now exposes:

- Pause Sand
- Step 1 simulation tick while paused
- 0.25x / 0.5x / 1x / 2x / 4x speed

Slow motion lowers simulation timing. 2x/4x keeps the existing scene-tree scheduling and increases native sand iterations per due tick instead of introducing extra UI/process loops.

Exiting Creative Mode resets the sandbox simulation controls to normal 1x live behavior.

## Terrain Undo / Redo

Terrain Undo/Redo remains intentionally disabled in this version. The current fallingsand binary exposes region mutation but not an API returning the previous element contents for a region. Implementing correct undo now would require a GDScript per-pixel snapshot during large brush strokes, defeating the native Creative Brush performance path.

The intended native extension is a bounded region snapshot/restore API, after which Creative history can store compressed `PackedInt32Array` deltas without per-pixel cross-language calls.
