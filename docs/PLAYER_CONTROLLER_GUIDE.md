# Noita-style player controller

## Files

- `scenes/Player.tscn` — feet-origin character scene, collider, body atlas,
  independent arm/wand, camera and compact fuel HUD.
- `scripts/player/Player.gd` — movement, state selection, atlas playback, aim,
  firing and input registration.
- `scripts/player/NoitaBolt.gd` — ray-stepped digging projectile.
- `assets/player/` — the supplied character, hotspot, arm and wand files.
- `scripts/world/WorldManager.gd` — public live-material query and circular erase
  helpers used by swimming and wand projectiles.

## Controls

| Input | Action |
| --- | --- |
| A / D, left / right | Move |
| Shift | Sprint |
| W / Space / up | Jump; hold in air to levitate |
| S / down | Crouch, fast-fall, or swim downward |
| Mouse | Aim arm and wand |
| Left mouse | Fire digging bolt |
| F / right mouse | Kick |
| + / - | Zoom |

## Movement model

The controller uses a feet-origin `CharacterBody2D` and the streamed static
collision snapshots already produced by `PixelChunkCanvas`. It retains the
world's collision-readiness guard, so movement cannot enter a newly streamed
chunk before that chunk has committed a complete collision snapshot.

Ground movement has acceleration, braking, sprint and crouch speeds. Jumping has
coyote time, input buffering and variable jump height. Holding jump while airborne
uses a finite levitation reserve; it recharges on the ground and more slowly while
swimming. Two ceiling rays prevent standing up inside solid pixels.

## Animation model

The supplied `player.xml` describes a 57x40 body atlas with a common `(31, 35)`
origin. The controller reads the corresponding atlas rows through a compact state
library and updates a `Sprite2D.region_rect`, avoiding hundreds of generated
`AtlasTexture` subresources. The body faces the aim direction and switches between
forward and backward locomotion rows. The arm pivot is aligned to the red body
hotspot from the supplied hotspot atlas.

## Live material integration

`WorldManager.get_element_id_at_world_position()` samples the initialized native
sand grid. `is_liquid_at_world_position()` maps that element through the active
material palette. `erase_material_circle()` writes air into initialized canvases;
the existing dirty and collision rebuild budgets then update their visuals and
physics snapshots.

## Main tuning values

Select the `Player` instance or open `scenes/Player.tscn` and tune exported values
on `Player.gd`. Useful groups are:

- Ground movement: speed, acceleration, gravity and fast fall.
- Jump and levitation: jump speed, coyote/buffer windows, thrust and fuel rates.
- Swimming: speed, acceleration and buoyancy/gravity scale.
- Wand: fire rate, projectile speed/lifetime and digging radius.
- Camera: zoom range and step.

## Validation note

The project archive includes native falling-sand libraries for Windows, Android
and Web, but not Linux x86_64. Therefore the complete project cannot be executed
in a Linux x86_64 validation container without an additional matching
`libgdfallingsand.linux.*.x86_64.so`. Resource paths, node paths, atlas bounds,
text structure and archive integrity were validated statically.

## AnimatedSprite2D 动画资源

角色动画现已迁移到 Godot 原生 `AnimatedSprite2D`。完整设计、生成方式和扩展说明见：

`res://docs/ANIMATED_SPRITE_REFACTOR.md`

主要资源：

- `res://assets/player/player_sprite_frames.tres`：50 个身体动画、243 帧
- `res://assets/player/player_arm_sprite_frames.tres`：3 个手臂动画、3 帧
- `res://tools/generate_sprite_frames.py`：由原始 XML 自动重新生成资源

## 2026-08 controller fixes

The player now uses `character_scale = 0.5`, supports repeated levitation presses while fuel remains, and automatically climbs solid pixel steps up to `max_step_height = 3.0` world pixels. See `docs/PLAYER_CONTROLLER_FIXES_V2.md` for implementation details.
