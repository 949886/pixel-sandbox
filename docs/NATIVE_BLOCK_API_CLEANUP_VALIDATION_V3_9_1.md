# V3.9.1 Native Block API Cleanup Validation

## Result

PASS.

## Verified cleanup

- `SandSimulation::get_chunk()` declaration removed.
- `SandSimulation::get_chunk()` implementation removed.
- `get_chunk` ClassDB binding removed.
- `SandSimulation::set_chunk_size()` declaration removed.
- `SandSimulation::set_chunk_size()` implementation removed.
- `set_chunk_size` ClassDB binding removed.
- `PixelChunkCanvas.gd` migrated to `set_block_size(16)`.
- Project Painting demo migrated to `set_block_size(16)`.
- Bundled sand-slide demo migrated to `set_block_size(16)`.
- Static source scan confirms no legacy calls remain in C++/GDScript runtime sources.
- Native API version bumped to 11.

## Regression validation

Passed:

- V3.7.2 collision-sector structural validation.
- V3.7.3 mobile/PC budget validation.
- V3.8 Native Seam structural validation (validator updated to accept any API >= 9).
- V3.9 Active Block structural validation.
- Collision-sector randomized model test.
- Burning collision scheduler model test.

The existing `.gdextension` file still declares platform binaries not present in the archive for several targets; these are pre-existing warnings and are unrelated to this cleanup.

## Build note

This environment does not contain the full pinned `godot-cpp` checkout/Godot 4.7 target toolchain, so the final Windows/Android/Web GDExtension binaries were not rebuilt here. Rebuild the extension and verify F1 reports `native yes(api 11)`.
