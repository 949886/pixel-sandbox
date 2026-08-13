# Gameplay V4.5.2 — Scene UI + Creative Input Arbitration

## Goals

This pass addresses two architectural issues found during the V4.5 Creative feedback cycle:

1. Painting terrain with the Creative material tool could also trigger `wand_fire` because Player polls the action state independently of GUI/unhandled input consumption.
2. Gameplay and Creative UI still constructed many Controls from GDScript, which made visual iteration harder and mixed presentation construction with runtime logic.

## Creative input arbitration

`CreativeBrushController` now registers itself as a Creative input capture with `GameModeManager`.

When the Creative **MATERIALS** workspace is active, the brush reports that it owns `wand_fire`. `Player._fire_wand()` asks `GameModeManager.gameplay_action_blocked(&"wand_fire")` before calling the WandController.

Switching to SPELLS / WANDS / PLAYER / WORLD disables brush interaction, so Wand testing works normally outside the material editor.

The manager stores input captures as `WeakRef`s registered only when controllers enter/leave the tree. It does not scan the scene tree on every cast attempt.

## Scene-authored UI

The fixed UI hierarchy is now stored in scenes instead of being created from code:

- `scenes/ui/GameplayUI.tscn`
- `scenes/ui/creative/CreativeUI.tscn`
- `scenes/ui/shared/SpellSlot.tscn`
- `scenes/ui/shared/WandGlyph.tscn`
- `scenes/ui/shared/WandQuickSlot.tscn`
- `scenes/ui/shared/WandRowUI.tscn`
- `scenes/ui/shared/StatusLabel.tscn`
- `scenes/ui/creative/CreativeMaterialTile.tscn`
- `scenes/ui/creative/CreativeSpellTile.tscn`

Scripts now primarily perform:

- data binding;
- state refresh;
- signal routing;
- drag/drop handling;
- inventory/Wand mutations;
- mode/input logic.

Dynamic lists still instantiate PackedScenes when their backing data changes, but UI Controls are no longer assembled with `PanelContainer.new()`, `Button.new()`, `Label.new()`, etc.

## WandGlyph

`WandGlyph` is now a scene-authored `TextureRect` instead of a custom `_draw()` Control. It continues to use the exact same `WandDef.visual_texture` and `visual_modulate` as the Player-held Wand with nearest filtering and aspect-preserving scaling.

## Performance

This pass does not add a per-frame UI rebuild. Fixed Controls are loaded once from their scenes. Resource grids rebuild only on the same event-driven paths as before. Creative input captures are cached with WeakRefs rather than discovered with a scene-tree scan per shot.
