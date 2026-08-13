# Gameplay V4.3.1 — Spell Drag Preview Fix

V4.3.1 fixes desktop spell drag-and-drop in the Wand Editor / Spell Inventory.

## Root cause

V4.3 emitted `slot_pressed` on the initial left mouse press. The click handler immediately rebuilt the inventory grids, removing the source `SpellSlot` before Godot could call `_get_drag_data()`. The drag API itself was present, but its source Control was destroyed before drag detection could begin.

## Changes

- Mouse click selection now fires on left-button release only when no drag started.
- `_get_drag_data()` now owns the desktop drag path without being interrupted by the click fallback.
- A 52x52 nearest-filtered floating spell card follows the mouse through Godot's native drag preview.
- The source slot dims while the spell is being carried.
- Valid drop targets highlight green while hovered.
- Dropping over a Wand or Inventory slot swaps/moves the spell.
- Dropping outside valid slots leaves the spell unchanged.
- Inventory UI rebuilds are deferred until the native drop transaction has finished, avoiding destruction of drag source/target Controls during `_drop_data()`.
- Touch keeps the existing tap-source + tap-target swap path.

## Manual runtime validation

1. Open `World.tscn`.
2. Press `Tab` or `I`.
3. Hold left mouse on a non-empty Spell slot and move at least several pixels.
4. Confirm the spell icon lifts from the slot and follows the pointer.
5. Hover another Wand/Inventory slot and confirm the destination highlights green.
6. Release and confirm the spells move/swap.
7. Drag a spell outside all slots and release; confirm the deck/inventory remains unchanged.
8. Single-click two slots to confirm click-swap still works.
