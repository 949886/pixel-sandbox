# Gameplay V4.4 — Noita-style UI Rebuild

V4.4 replaces the V4.3 centered editor/demo HUD with a world-first inventory and wand editing surface inspired by the information architecture of Noita. The implementation deliberately uses original procedural chrome and the user-provided spell icon atlas rather than copying Noita UI textures or fonts.

## Research findings applied

- The normal combat view keeps most of the screen unobstructed. Wands/items live in a compact quick inventory at the upper-left; health, mana, gold, and statuses are separated to the upper-right.
- Opening the inventory expands the quick-inventory language rather than switching to a conventional full-screen RPG window. The top band is divided into WANDS, ITEMS, and SPELLS.
- Wands are treated as containers. Each wand row exposes its wand glyph, Shuffle state, Spells/Cast value, and its ordered spell cards.
- Detailed wand statistics are shown as a compact dark tooltip/card: Shuffle, Spells/Cast, Cast Delay, Recharge Time, Mana Max, Mana Charge Speed, Capacity, and Spread.
- Spell information is hover-driven and compact. Dense 16×16 spell art and thin warm borders carry most of the visual identity.
- The visual chrome is square, dark, and low-contrast, with warm brown/orange selection frames. It avoids rounded modern panels, glass blur, and oversized headings.

## V4.4 layout

### Combat HUD

- Upper-left: 4 wand quick slots + 4 reserved item slots.
- Upper-right: HP, Mana, Flight Fuel, Gold, and active status text.
- Removed the previous large bottom Wand HUD.
- Number keys 1–4 now equip wand slots 1–4.
- Mouse wheel now cycles available wands instead of jumping the internal spell-deck cursor.

### Inventory / Wand Editor

- `Tab` / `I` opens the editor.
- The world remains visible through a very light overlay; there is no centered 1100×620 modal window.
- The top strip expands to show the 24-slot SPELLS inventory.
- Four editable wand rows appear below the quick inventory.
- Each wand row shows a procedural pixel wand glyph, Shuffle, Spells/Cast, and its ordered spell slots.
- Hovering a spell opens a pointer-following tooltip.
- Hovering/selecting a wand updates the wand-stat card.
- Spell cards can be dragged between the spell inventory and any wand.
- Shift-click or double-click performs a quick move between the selected wand and the spell inventory.
- Touch tap-source/tap-target swapping remains supported.

## Visual language

- Square corners only.
- Near-black translucent panel backgrounds.
- Warm brown 1px frames and amber selected/equipped frames.
- Nearest filtering for all spell art.
- Dense 38×38 UI slots around 16×16 atlas icons.
- Limited-use counts may appear in the corner; mana cost is kept in the tooltip instead of cluttering every slot.
- Wand art is procedurally drawn from each `wand_id` so different runtime wands read as distinct gear without requiring copied wand sprites.

## New / changed files

- `scripts/ui/gameplay/GameplayUI.gd` — full layout rewrite.
- `scripts/ui/gameplay/SpellSlot.gd` — square Noita-style slot, drag preview, quick-move input, limited-use count.
- `scripts/ui/gameplay/NoitaUITheme.gd` — UI palette and square pixel frame helpers.
- `scripts/ui/gameplay/WandGlyph.gd` — procedural pixel wand representation.
- `scripts/player/Player.gd` — 1–4 and wheel now select wands rather than spell-deck positions.
- `tools/validate_gameplay_v4_4_noita_ui.py` — V4.4 structure/interaction validation.

## Intentional differences

- Inventory currently pauses gameplay because the project allows free wand editing anywhere and V4.4 preserves the existing safety behavior. This can later be tied to a Holy-Mountain/Tinker-style rule.
- ITEMS slots are visual placeholders until the potion/item gameplay layer exists.
- Flight Fuel remains in the top-right HUD because it is a project-specific player resource.
