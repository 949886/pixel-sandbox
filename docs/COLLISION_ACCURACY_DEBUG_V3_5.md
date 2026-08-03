# Collision Accuracy + F6 Debug — V3.5

## Why V3.4 left a gap
V3.4 used 8×8 collision cells on PC and 16×16 cells on mobile. A cell became solid when it contained any solid pixel. This preserved thin walls but expanded collision into nearby empty pixels by up to 7/15 pixels. CharacterBody2D safe margin added another small separation.

## V3.5 changes
- Both runtime profiles use `collision_cell_size = 1`.
- The existing greedy rectangle merge still combines adjacent solid pixels, but the source occupancy mask is now pixel exact.
- Player `safe_margin` is reduced from `0.5` to `0.01`.
- F6 toggles a cyan collision debug layer.
- The debug layer renders `_collision_active_rects`, i.e. the exact double-buffered snapshot currently committed to PhysicsServer2D, not the snapshot still being staged.
- The debug layer creates no CollisionShape2D nodes and has zero draw cost while disabled.

## Controls
- F6: show/hide collision debug rectangles.

## Native rebuild note
`SandSimulation.get_collision_rects(1)` is pixel exact even with the earlier conservative occupancy rule because each cell contains exactly one pixel. Rebuilding the extension is not required solely for the V3.5 accuracy change, though rebuilding remains recommended for all V3.2 dirty APIs.
