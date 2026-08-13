# Gameplay V4.2.2 — Runtime Hardening

This patch hardens the V4.2 Luna wand/spell migration against runtime edge cases discovered during real Godot playtesting.

## Primary fix

`GameplayProjectile` no longer passes an invalid `(0, 0)` collision normal to `Vector2.bounce()`. Every bounce now resolves a safe normalized collision normal. If physics did not provide a usable normal, the projectile falls back to the inverse incoming direction, then `Vector2.UP` as a final defensive fallback.

## Lifetime safety

Long-lived projectiles and delayed spell effects can outlive their caster, source, target, world facade, or parent scene. Projectile source/world references now use weak references, matching the V4.2.1 `CastContext`/`DamagePacket` lifetime work. Runtime effects and spawners validate nodes before using or parenting them.

## Physics-query safety

- Zero-motion projectile raycasts are skipped.
- Hitscan range is clamped away from zero and validates `World2D`.
- Chain Lightning rejects non-positive query radii and handles coincident targets.
- Cave Eye LOS treats coincident positions as already visible instead of constructing a zero-length ray.
- Special runtime query radii are clamped to a valid positive shape radius.

## Zero-vector safety

- Teleport impacts with no collision normal use a safe fallback normal.
- Explosion damage at the exact blast center uses the cast direction instead of normalizing zero.
- Radial pull/damage and cone checks guard zero-length vectors.

## Runtime behavior fixes

- Caster-bound Chainsaw and Dragon Breath end when their caster is gone instead of becoming orphaned damage fields.
- Gold pickups now re-check overlapping bodies when the pickup delay expires, preventing a player who entered too early from leaving the pickup permanently uncollectable.
- Gold pickup collection is guarded against duplicate collection in one physics step.
- Wand mana/recharge inputs and gameplay-world write inputs are clamped defensively.
- Projectile/VFX/special-runtime parent nodes are validated before `add_child()`.
- `Fixed Angle` now uses additive modifier semantics so it no longer resets modifiers accumulated before it in the same cast.

## Regression tests

Added:

- `res://tests/ProjectileRuntimeSafetySmokeTest.tscn`
- Extended `res://tests/LifetimeReferenceSmokeTest.tscn`
- `validate_gameplay_v4_2_2_runtime_safety.py`

The static validator covers bounce-normal fallback, weak projectile references, zero-length ray/radius guards, teleport fallback, centered explosion direction, caster-bound spell cleanup, GoldPickup overlap timing, safe cast parenting, world write guards, modifier preservation, and resource-reference integrity.
