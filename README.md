> **V3.9.1 Native Block API Cleanup：** `SandSimulation` 的 16×16 Simulation Blocks 现在只暴露 `get_block()` / `set_block_size()`；旧 `get_chunk()` / `set_chunk_size()` 已从 C++ 与 GDScript API 中彻底删除。Active Block 调度逻辑保持 V3.9 不变。稳定的 INERT/MOVABLE 区域会在 4 个 quiet tick 后睡眠，`set_cell()`、爆炸、地形破坏与 API 9 Native Seam 会自动唤醒本 Block 与 3×3 邻域；REACTIVE/AUTONOMOUS 材料使用保守 Activity Policy 防止反应睡死。PC 的 3×3 simulation radius 现在统一使用 60Hz，依靠 Active Blocks 降低实际扫描量。请重新编译 `extensions/sand-slide`，并在 F1 确认 `native yes(api 11)` 与 `Active blocks: yes`。详见 `docs/NATIVE_BLOCK_API_CLEANUP_V3_9_1.md` 与 `docs/NATIVE_ACTIVE_BLOCKS_V3_9.md`。

> **V3.8.1 Native Cross-Chunk Flow：** 液体、气体与显式 Powder 现在通过 API 9 Native Seam Bridge 跨 Chunk；移动端保留 `simulation_radius = 0`，正交邻居只保持 Warm，真实跨边界后临时唤醒。请重新编译 `extensions/sand-slide`，并在 F1 确认 `Native flow: yes` / `api 9`。V3.8.1 额外修复 MSVC 对 `std::min(int, int64_t)` 的严格模板推导错误；运行时 Native API 仍为 9。详见 `docs/NATIVE_CROSS_CHUNK_FLOW_V3_8.md` 与 `docs/MSVC_BUILD_FIX_V3_8_1.md`。

> **V3.7.3 移动端 PC 预算测试：** 移动端的流水线、模拟、碰撞构建与 Sector 提交预算已统一到 PC 档；加载范围、模拟频率、纹理缩放和对象池仍保留移动端设置。详见 `docs/MOBILE_PC_BUDGETS_V3_7_3.md`。

> **V3.7.2 燃烧性能修复：** 动态碰撞采用紧凑 Sector 占用位图、删除/新增分级同步与保守快照渐进提交。请重新编译 `extensions/sand-slide`，并在 F1 HUD 确认 `native yes(api 8)`。详见 `docs/COLLISION_BURNING_PERFORMANCE_V3_7_2.md`。

# Noita Piece World Demo

This project is the migrated version of the original TileMapLayer world prototype.
The runtime terrain generation path now uses 128px **Piece** units instead of
64px TileMap cells.

## What changed

- Removed the TileMapLayer runtime generation pipeline.
- Migrated the Piece/PieceSocket/PieceLibrary/PieceChunk generation stack.
- Kept project 2's macro world structure, biome planning, special-chunk planning,
  player controller, HUD, and world debug drawer.
- Replaced legacy 8-point edge profiles with 4 PieceSocket slots per chunk edge.
- Special chunks are planned by `SpecialChunkPlanner` but rendered by
  `SpecialPieceRenderer` instead of TileMap scenes.
- Project 1 debug/demo scripts were intentionally not copied; debugging is handled
  by `scripts/debug/DebugOverlay.gd` and `scripts/debug/WorldDebugDrawer.gd`.

## Runtime controls

- `WASD` / arrow keys: move player camera anchor
- `+` / `-`: zoom
- `F1`: toggle HUD
- `F2`: toggle world debug overlay
- `F3`: regenerate same seed
- `F4`: advance seed and regenerate

## Socket model

`PieceSocket.Socket` now only contains boundary-connection shapes:

```text
SOLID, OPEN_SMALL, DOUBLE_OPEN_SMALL, OPEN_MEDIUM, OPEN_LARGE, ANY
```

The old `ROOM` and `SHAFT` socket variants were removed because no piece or special-chunk resource used them as edge socket values. Room/lab/cave identity still exists through `PieceDef.kind` and piece tags such as `room`, `lab`, and `cave_room`.

## Main files

- `scenes/World.tscn` — main scene
- `scripts/world/WorldManager.gd` — streaming coordinator
- `scripts/piece_world/PieceChunkGenerator.gd` — piece-based chunk generation
- `scripts/world/SocketProfilePlanner.gd` — socket seam planner, 4 slots per edge
- `scripts/special/SpecialPieceRenderer.gd` — image-based special chunks
- `resources/pieces/piece_library.tres` — migrated piece library

## Debug guide

See [`DEBUG_OVERLAY_GUIDE.md`](DEBUG_OVERLAY_GUIDE.md) for a detailed explanation of the F1 HUD, F2 world debug drawer, socket marker shapes, and color meanings.

## Piece generation sequence demo

A standalone adapted sequence visualizer is available at:

```text
scenes/PieceGenerationSequenceDemo.tscn
```

It was migrated from project 1 but now uses the current piece-world generator, 128px units, 4 socket slots per edge, `WorldSeamRegistry`, and non-destructive seam repair. See `PIECE_GENERATION_SEQUENCE_DEMO_GUIDE.md` for controls and how to read the expected/actual socket markers.


## Threaded streaming

This build includes a threaded chunk-streaming refactor. Normal piece chunk generation and special chunk image construction are queued to background workers; the main thread only uploads ready images to `ImageTexture` and attaches renderer nodes. See `THREADING_STREAMING_GUIDE.md` for details and runtime tuning options.

## Mobile performance

This build also includes a mobile performance pass: shared per-frame upload budget, renderer pooling, hidden debug overlays by default, CPU visual-image release after upload, and optional half-resolution visual texture upload. See `MOBILE_PERFORMANCE_GUIDE.md` for recommended settings and tradeoffs.


## Runtime profiles

The world scene now uses separate runtime profile resources for PC and mobile:

- `resources/runtime_profiles/pc_runtime_profile.tres`
- `resources/runtime_profiles/mobile_runtime_profile.tres`

`WorldManager.runtime_profile_mode = Auto` selects PC in the desktop/editor and Mobile on Android/iOS/mobile exports. Use `PC`, `Mobile`, or `Custom` to force a profile while testing.

See `RUNTIME_PROFILES_GUIDE.md` and `MOBILE_PERFORMANCE_GUIDE.md` for details.


## Collision debug

- `F6`: toggle the collision sector debug layer. Cyan is the exact Active snapshot; red/yellow/magenta show dirty/build/commit-pending sectors.

## Noita-style character controller

The former free-flying gradient demo anchor has been replaced by the character in
`assets/player/`. The controller now uses the generated pixel collision, samples
live liquids, aims an independent arm/wand at the mouse and fires digging bolts.

- `A` / `D` or left/right: move
- `Shift`: sprint
- `W`, `Space` or up: jump; hold in the air to consume levitation fuel
- `S` or down: crouch on ground, fast-fall in air, swim downward in liquid
- Mouse: aim
- Left mouse: fire wand and remove a small circle of simulated material
- `F` or right mouse: kick animation
- `+` / `-`: camera zoom

Movement includes acceleration/deceleration, gravity, coyote time, jump buffering,
short-hop release, crouch clearance checks, grounded fuel recharge and swim control.
