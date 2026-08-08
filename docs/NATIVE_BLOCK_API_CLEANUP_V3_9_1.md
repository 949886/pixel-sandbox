# V3.9.1 Native Block API Cleanup

V3.9.1 removes the legacy SandSimulation `get_chunk()` and `set_chunk_size()` compatibility API completely.

- Removed both declarations from `sand_simulation.h`.
- Removed both C++ implementations.
- Removed both ClassDB bindings, so GDScript no longer exposes these methods.
- Migrated `PixelChunkCanvas.gd`, the project Painting demo, and the bundled sand-slide demo to `set_block_size(16)`.
- `get_block()` / `set_block_size()` are now the only public names for the internal 16x16 Simulation Block API.
- Native API version is bumped from 10 to 11 because the public API surface changed. Active Block capability remains available for API >= 10.

This is an API cleanup only; Block scheduling, Native Seam behavior, Collision Sector logic, and runtime budgets are unchanged.
