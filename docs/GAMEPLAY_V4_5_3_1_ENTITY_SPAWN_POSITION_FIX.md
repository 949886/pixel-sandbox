# Gameplay V4.5.3.1 — Creative Entity Spawn Position Fix

This hotfix fixes Creative Entity placement for floating pickup entities.

## Root cause

`GoldPickup` and `SpellPickup` cached `_base_y` in `_ready()`. `CreativeEntityDef.spawn()` previously added the node to the scene tree before assigning its requested world position, so `_ready()` observed the parent's origin. On the next physics tick the pickup bobbing code restored Y toward that stale value, making pickups jump to a chunk/world boundary while `CaveEye` remained correct.

The same lifetime ordering could also affect normal enemy drops because CaveEye adds pickup nodes before assigning their final world position.

## Fix

- `CreativeEntityDef.spawn()` now prepositions `Node2D` instances relative to a `Node2D` parent before `add_child()`, then reasserts the requested `global_position` after insertion.
- `GoldPickup` and `SpellPickup` no longer capture their bobbing baseline in `_ready()`.
- Both pickups lazily capture their final `global_position.y` on their first physics tick, after normal spawn code has had a chance to place them.
- Added `CreativeEntitySpawnPositionSmokeTest.tscn` covering Gold and Fireball pickup placement before and after one physics tick.
- Added `validate_gameplay_v4_5_3_1_entity_spawn_position.py` regression validation.

## Performance

The fix adds no per-frame scene-tree scans, resource loads, physics queries, or Native sand operations. Each floating pickup performs one boolean check and one baseline assignment on its first physics tick only; subsequent update cost is unchanged.
