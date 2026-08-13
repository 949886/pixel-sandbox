# Gameplay V4.2.1 — Lifetime Reference Fix

## Fixed runtime error

```
CastContext.duplicate_for_impact: Invalid assignment of property or key 'source'
with value of type 'previously freed'
```

Long-lived projectiles and spell runtimes can outlive the caster/source that
created them (most visibly across player death/respawn). V4.2 stored those Nodes
directly in `CastContext`, allowing a freed Godot Object handle to survive until
a later projectile impact.

## Changes

- `CastContext` now stores caster/source/projectile_parent/world_interface/target
  through `WeakRef`-backed properties. Expired objects resolve to `null`.
- `DamagePacket` source/instigator are also WeakRef-backed so delayed damage
  observers cannot retain stale Object handles.
- `StatusComponent` stores the Burning instigator through a WeakRef. Burning can
  continue ticking safely after the original caster disappears.
- `GameplayProjectile` validates its legacy source before faction/damage lookup.
- Added `tests/LifetimeReferenceSmokeTest.tscn` reproducing the exact lifetime
  sequence: create context -> free caster/source -> duplicate impact context.
- Added `tools/validate_gameplay_v4_2_1_lifetime_refs.py`.

## Runtime test

Run:

```
res://tests/LifetimeReferenceSmokeTest.tscn
```

Expected output:

```
Lifetime Reference Smoke Test: PASS
```
