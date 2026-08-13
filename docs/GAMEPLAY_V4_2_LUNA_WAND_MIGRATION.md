# Gameplay V4.2 — Luna C# Wand / Spell Migration

This pass semantically migrates the uploaded Luna C# Noita-style wand system into the current Godot 4 GDScript gameplay stack.

## Architecture translation

| Luna C# | V4.2 GDScript adaptation |
|---|---|
| `Card.cs` / `Spell.cs` | `SpellDef.gd` Resource card |
| `Deck<T>` / `SpellDeck.cs` | `SpellDeckRuntime.gd` draw cursor + extra-draw + modifier propagation |
| `Wand.cs` | `WandDef.gd` + `WandController.gd` |
| `Magic.cs` / `Projectile2D.cs` | `GameplayProjectile.gd` + `ProjectileDef.gd` |
| `MagicModifier.cs` | modifier `SpellDef` resources |
| `FormationSpell.cs` / `Formation.cs` | multicast/formation `SpellDef` + `SpellCastState.direction_for()` |
| `ElementalEffect.cs` | `StatusComponent.gd`, `ApplyStatusEffect.gd`, live pixel-world material writes |
| scene-heavy VFX | procedural square-pixel VFX / fields / arcs |

The migration is intentionally semantic rather than a line-for-line port. The old implementation relied heavily on RigidBody scenes and smooth `Line2D` / polygon effects. The current project has destructible native sand simulation, dynamic collision sectors and a shared combat/status architecture, so those behaviors are translated into the current runtime instead of recreating the old coupling.

## Wand behavior retained

- ordered deck cursor
- optional shuffle on reload
- base multicast
- `extra_draw` modifier cards
- modifier propagation to actions drawn in the same cast
- mana cost
- mana regeneration
- wand cast delay
- per-card cast delay
- wand recharge time
- per-card recharge additions
- spread
- recoil
- critical chance
- formation angles
- forward origin offset (Long Distance Cast)

A legacy bug where modifier cards were drawn but their mana cost was not charged is intentionally corrected. Obvious octuple resource inconsistencies are normalized to eight draws in the new resource.

## V4.1 spells retained

The original four V4.1 spells remain unchanged as resources and occupy the first four cards of the default hybrid showcase wand:

1. Spark Bolt
2. Dig Bolt
3. Fire Bolt
4. Bomb

They now run through the same deck/runtime state as the migrated Luna cards, so Damage Plus, Spread, formation and future modifiers can affect them.

## Luna action spells migrated

- Acid Splash — toxic hit, live acid pixels, local terrain dissolve
- Black Hole — moving square-pixel singularity, pull, continuous damage, terrain erosion
- Explosive Bomb — heavy arcing/fused explosive variant
- Chainsaw — short-lived high-frequency cutting field
- Death Cross — moving rotating cross-shaped damage field
- Dragon Breath — persistent cone damage plus live fire pixels
- Dynamite — gravity projectile with large terrain explosion
- Energy Sphere — multi-bounce energy projectile
- Fireball — explosive fire projectile with live fire trail and Burning
- Glue Ball — impact glue field and movement slow
- Ice Bolt — slow + radial pixel ice shards
- Lightning Bolt — projectile lightning with stun and chain arcs
- Lightning Beam — instant zig-zag pixel hitscan adaptation of old `LightningBolt.cs`
- Magic Arrow — piercing projectile
- Spark — tiny legacy utility spark
- Teleport Bolt — caster teleports to projectile impact/timeout position

The duplicate historical `spark_bolt.tres` / `sparkbolt.tres` behavior is represented by the existing V4.1 `spark_bolt.tres`, rather than keeping two nearly identical cards.

## Modifier cards migrated

- Damage Plus
- Spread
- Fixed Angle
- Long Distance Cast
- Light (adds orbiting one-pixel satellite motes)

## Multicast cards migrated / normalized

- Double Cast
- Triple Cast
- Double Scatter
- Quadruple Cast
- Octuple Cast
- Formation
- Formation Back And Front

## Pixel visual direction

The migrated spells do not copy Noita art assets. They use the project's own procedural visual language:

- integer-snapped square projectile cores
- discrete pixel trail samples
- one-pixel satellite motes instead of smooth glow sprites
- square impact debris
- zig-zag `PixelArcVFX` for electricity
- live SandSimulation fire/acid writes where appropriate
- square-pixel persistent fields for Black Hole, Death Cross, Dragon Breath, Chainsaw and Glue
- no filtered textures required by the migrated spell visuals

## Test wands

- `starter_wand.tres` — default hybrid showcase: original four V4.1 spells + migrated Luna cards/modifiers
- `luna_test_wand.tres` — converted equivalent of the old Luna Test Wand sequence
- `luna_formation_wand.tres` — converted equivalent of the old Formation Wand

The desktop `1-4` keys now act as convenient jumps to the first four deck slots. Mouse wheel moves the deck cursor. Normal firing consumes cards in order and reloads the deck when exhausted.

## Validation status

Static integration validation covers resource paths, migrated spell count, deck/modifier APIs and inherited V3.x/V4.0/V4.1 checks. Runtime behavior still needs a Godot 4 executable / editor smoke test because the build environment used for this migration does not include Godot.
