# Gameplay V4.4.2 — UI / Resource Cleanup

This pass addresses feedback from the V4.4.1 Noita-style inventory UI without adding new per-frame systems.

## UI sizing
- Spell hover tooltip keeps a fixed readable width but derives height from content.
- Wand detail card keeps a fixed width but derives height from content.
- Empty wand inventory rows are not constructed.
- Wand icon frames in editor rows are square 50x50 controls.

## Spell atlas ownership
- Atlas moved from the project root to `res://resources/gameplay/spells/atlas/`.
- `SpellDef` now owns a direct `Texture2D` icon resource reference.
- All current gameplay SpellDef `.tres` files reference their AtlasTexture directly.
- `SpellIconRegistry` is only a compatibility accessor and performs no path construction, directory scan, ResourceLoader lookup, or icon cache work.

## Wand visuals
- `WandDef` owns `visual_texture` and `visual_modulate`.
- Player in-hand WandSprite and UI WandGlyph use the same WandDef visual resource.
- The old procedural UI wand silhouette and inner outline were removed.
- Player.tscn no longer hard-wires a separate wand texture.

## Test wand
- Slot 2 starts with `High Performance Test Wand`.
- The test wand has 24 empty slots, 2000 mana, 1000 mana/sec recharge, 0.02s cast delay, and 0.08s recharge.
- Its cyan tint is applied both in the UI and in the player's hand.

## Performance notes
- No runtime icon path lookup or directory scan.
- Only SpellDef-referenced AtlasTexture resources are resolved for gameplay spells.
- Wand glyphs redraw only when their WandDef changes.
- Tooltip/detail height fitting runs only when displayed content changes, not every frame.
