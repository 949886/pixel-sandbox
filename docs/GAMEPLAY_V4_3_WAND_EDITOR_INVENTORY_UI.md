# Gameplay V4.3 — Wand Editor / Inventory / Spell Pickup UI

V4.3 removes the temporary player-owned HUD and introduces a standalone gameplay UI layer plus a runtime spell inventory/editor.

## UI architecture

- `scenes/ui/GameplayUI.tscn` is a standalone `CanvasLayer` owned by `World.tscn`.
- `Player.tscn` no longer contains the old `HUD` subtree or direct UI node references.
- `GameplayUI.gd` binds to Player/Health/Status/Wand/Inventory signals and owns:
  - HP / Mana / Flight / Gold / Status HUD
  - live wand/deck strip and recharge state
  - death overlay
  - pickup toast
  - full-screen paused Inventory + Wand Editor
- `SpellSlot.gd` is a reusable spell-card slot supporting desktop drag/drop and tap-source/tap-target swapping.

## Runtime inventory

`PlayerInventory.gd` provides:

- 4 wand slots
- 24 spell inventory slots
- an isolated runtime copy of the starter wand
- equipping a wand
- moving/swapping spells between wand slots and inventory slots
- live `WandController.refresh_definition()` when the equipped wand is edited

Spell resources remain shared and immutable; only the wand/deck layout is duplicated for runtime ownership.

## Spell icons

The uploaded 638-icon 16x16 atlas package is installed at:

`res://resources/gameplay/spells/atlas/`

`SpellDef` resources hold direct `Texture2D` references to their AtlasTexture icons. `SpellIconRegistry.gd` is now only a compatibility facade that returns `spell.icon`; there are no runtime path lookups or string maps. UI textures use nearest filtering and integer-scaled icon surfaces.

## Spell pickups

`SpellPickup.gd` is a world-space pickup that:

- renders the SpellDef atlas icon
- retries pickup while overlapping if inventory was full
- transfers the SpellDef into `PlayerInventory`
- remains in-world when the inventory has no free slot

`CaveEye.gd` now has configurable `spell_drop_chance` and `spell_drop_max_tier` exports and can drop a random resource from `SpellCatalog` on death.

`World.tscn` contains one Fireball pickup near the starter area as an immediate editor/inventory test object.

## Controls

- `Tab` or `I`: open/close Inventory / Wand Editor
- `Esc`: close editor
- Drag a spell: move/swap
- Touch/click fallback: tap a source slot, then a destination slot
- `EQUIP`: equip the wand currently selected in the editor

Gameplay pauses while the editor is open. The UI CanvasLayer runs in `PROCESS_MODE_ALWAYS`, so it remains interactive while the world is paused.

## Validation

Static validation:

`python tools/validate_gameplay_v4_3_ui_inventory.py`

Runtime smoke scene (run in Godot):

`res://tests/GameplayUIInventorySmokeTest.tscn`

The smoke test checks runtime wand duplication, spell movement into inventory, live deck rebuild, inventory capacity, and atlas texture loading.

## Asset note

The atlas folder is included because it was supplied with this development task. Before publishing or redistributing a build that contains these source icons, verify that your project has the necessary rights for the intended distribution.
