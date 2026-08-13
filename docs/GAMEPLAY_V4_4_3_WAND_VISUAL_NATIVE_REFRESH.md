# Gameplay V4.4.3 — Wand Visual / Docs / Native Refresh

This pass addresses feedback after V4.4.2 without adding per-frame UI or resource-loading work.

## Wand UI

- Fixed `WandGlyph.gd` strict typing so warnings-as-errors no longer prevent the component from compiling.
- Quick WANDS slots and expanded wand rows render `WandDef.visual_texture` with `visual_modulate`, matching the Player's in-hand `WandSprite` data source.
- Expanded wand rows keep the icon frame and center container square via shrink flags even when the spell grid wraps to multiple rows.
- Enlarged the detailed wand glyph while retaining nearest filtering and integer-scale drawing.
- Empty wand slots remain absent from the expanded editor; slot 2 keeps the empty high-performance test wand.

## Documentation layout

All `GAMEPLAY_*.md` version notes now live under `docs/`. `README.md` remains at the project root and references the new documentation paths.

## FallingSand binaries

`bin/fallingsand/` was refreshed from the user-provided compiled package. Temporary `~...` replacement/backup files from that package are intentionally excluded; only canonical extension metadata and build artifacts are installed.

## Performance

- No runtime filesystem scanning was added.
- Wand textures remain direct Resource references on `WandDef`.
- WandGlyph only redraws when its wand definition/UI requests a redraw; no texture load or layout work is performed per frame.
- Updated native binaries replace existing artifacts in-place and do not add runtime dispatch layers.
