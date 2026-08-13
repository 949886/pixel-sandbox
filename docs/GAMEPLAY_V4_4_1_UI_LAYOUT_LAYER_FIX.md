# Gameplay V4.4.1 — UI Layout / Layer Fix

This patch addresses two UI problems reported after the V4.4 Noita-style rebuild.

## Wand spell wrapping

Wand spell slots no longer live inside a horizontal `ScrollContainer`. Each wand now uses a 12-column `GridContainer`; capacity 13+ automatically continues on a second row, 25+ on a third row, etc. The whole wand row grows vertically so all spell slots remain visible at once.

## Inventory overlap

The top SPELLS inventory can occupy multiple rows. The Wand editor and Wand detail card are now positioned from the actual spell-inventory row count instead of assuming a fixed `y=92`. This prevents the second spell-inventory row from covering Wand 1.

## Drag preview layering

The native Control drag preview was vulnerable to higher-z gameplay controls. Spell dragging now emits a request to `GameplayUI`, which renders the dragged icon in a dedicated `CanvasLayer` at layer 120 and follows the pointer every frame while Godot reports a GUI drag. This visual is above the Gameplay UI (layer 40) and touch controls (layer 30).

## Validation

Run:

```bash
python tools/validate_gameplay_v4_4_1_layout_layers.py
```
