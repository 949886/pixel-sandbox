# Dirty-driven Canvas and Collision Updates — V3.2

## What changed

`SandSimulation` now owns the authoritative dirty state. GDScript no longer guesses whether a chunk changed.

Native API added:

```text
bool is_dirty()
bool is_collision_dirty()
void clear_dirty()
void clear_collision_dirty()
void set_collision_elements(PackedInt32Array element_ids)
PackedInt32Array get_collision_rects(int cell_size)
```

## Visual dirty behavior

Every native cell mutation compares the previous raw element ID with the next ID. The visual dirty flag is raised only when the IDs differ.

Covered mutation paths:

- `set_cell()`
- `draw_cell()`
- `move_and_swap()` and `grow()` through `set_cell()`
- full bulk upload
- ranged bulk upload
- resize/reset
- reactions and element processing through `set_cell()`

Writing the same material back to the same cell preserves the simulation's visited behavior but does not create a false dirty event.

`PixelChunkCanvas.run_simulation_tick()` still advances the simulation at the configured rate, but it performs `get_color_image()`, `Image.create_from_data()` and `ImageTexture.update()` only when `SandSimulation.is_dirty()` is true.

## Collision dirty behavior

Collision dirty is intentionally narrower than visual dirty. `MaterialPalette` sends the native simulation the exact element IDs whose entries have `solid = true`.

A cell change raises collision dirty only when its solid occupancy changes:

- air/non-solid → solid: dirty
- solid → air/non-solid: dirty
- solid A → solid B: not collision dirty
- liquid A → liquid B: not collision dirty
- moving water, gas, smoke or non-colliding powder: not collision dirty

When collision dirty is observed, the native simulation rebuilds the same 25%-occupancy coarse mask and greedy rectangles used by the original worker-generated collision data. Godot creates the resulting PhysicsServer2D shapes under the existing per-frame collision budget.

If another solid change occurs while shapes are being installed, the flag remains set and a fresh snapshot is queued after the current snapshot completes.

## Initial chunk activation

The first live 512×512 texture is always uploaded once. The initial collision snapshot still comes from the background worker. After both represent the native grid, the initial native dirty flags are cleared. From then on, updates are change-driven.

## Required native rebuild

The DLL included in V3.1 predates these APIs. Source compatibility fallback remains in place, but it deliberately uses legacy full repaint behavior when `is_dirty()` is absent.

On Windows:

```text
extensions\sand-slide\build_windows_dirty.bat
```

Or build manually:

```text
cd extensions\sand-slide
scons platform=windows target=template_debug arch=x86_64
scons platform=windows target=template_release arch=x86_64
```

At runtime, an old DLL produces this warning once:

```text
SandSimulation DLL has no is_dirty()/clear_dirty(); using legacy full repaint mode.
```

No warning means the dirty API was detected.

## Expected profiler difference

For static chunks, simulation ticks can still occur, but the expensive CPU color conversion, `Image` creation, full GPU texture upload, and PhysicsServer2D collision rebuild are skipped. Dynamic chunks repaint only on ticks where at least one element ID actually changed. Collision updates occur only when solid occupancy changes.

This change addresses the delayed stutter caused by several warmed chunks continuously repainting unchanged 512×512 textures. It does not yet make `SandSimulation.step()` itself block-sleeping; active-block sleeping remains a separate optimization.
