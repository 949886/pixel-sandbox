# Gameplay V4.5 Creative Parser Hotfix

Fixes a Godot parser failure caused by `CreativeBrushController` defining `set_material(element_id)`, which collides with the native `CanvasItem.set_material(Material)` setter inherited by `Node2D`.

## Changes

- Renamed the gameplay brush API to `set_paint_element(element_id: int)`.
- Updated `CreativeUI` to call the renamed method.
- Added regression checks preventing `set_material()` from being reintroduced on the creative `Node2D` brush controller.
- No runtime behavior, brush batching, or rendering path changes.
