# Gameplay V4.0 Foundation

本版本把开发主线从 3.x 性能优化切换到 Gameplay，并尽量冻结现有 World/Simulation/Collision/Visual 架构。

## 已接入的第一条可玩闭环

```text
Player Wand
  -> GameplayProjectile
  -> Faction gate
  -> DamagePacket
  -> Enemy HealthComponent
  -> Cave Eye death
  -> GoldPickup
  -> Player gold
```

Cave Eye 同时会进行简单 LOS 判断、保持距离并向 Player 发射敌对 Projectile。Player 拥有 100 HP，死亡后短暂延迟并回到本局出生点。

## Gameplay 组件

- `scripts/gameplay/combat/DamageTypes.gd`：第一版伤害分类。
- `DamagePacket.gd`：统一伤害上下文。
- `HealthComponent.gd`：HP、受伤、治疗、死亡与轻量 i-frame。
- `FactionComponent.gd`：Player / Enemy / Neutral 与 friendly-fire gate。
- `GameplayProjectile.gd`：玩家和敌人共用的 ray-stepped projectile。
- `WorldGameplayService.gd`：Gameplay 到 Pixel World 的稳定 facade。
- `EnvironmentSensor.gd`：采样 Actor 周围实时 SandSimulation material。
- `StatusComponent.gd`：Wet / Oiled / Burning / Toxic 及环境持续伤害。
- `CaveEye.gd`：第一只不依赖动态 NavMesh 的飞行远程敌人。
- `GoldPickup.gd`：第一版战斗奖励。

## Material -> Gameplay

第一版识别 native sand-slide IDs：Water(3)、Fire(5)、Lava(20)、Acid(21)、Blue Fire(24)、Oil(30)、Burning Oil(50)，并同时读取 palette entry id。

当前规则：

- Water -> Wet，快速熄灭 Burning。
- Oil -> Oiled，延长 Burning，并提高持续燃烧伤害。
- Fire / Lava -> Ignite；Lava 还提供更高接触伤害。
- Acid -> Toxic 接触伤害。

## Collision layers

- World terrain: layer 1
- Player: layer 2
- Enemy: layer 4
- Player projectile ray mask: 1 + 4 = 5
- Enemy projectile ray mask: 1 + 2 = 3

## 下一步建议

1. SpellDef / WandDef 数据驱动化：把当前 wand_damage / dig_radius 参数移出 Player。
2. 加入 Spark Bolt / Fire Bolt / Bomb / Dig Bolt 四个验证法术。
3. 增加 Health Pickup 和 Spell Pickup，把 Gold 接入 Shop 后再做完整 Inventory。
4. 增加第二只地面敌人 Crawler，用简单局部探测而不是动态 NavMesh。
5. 将 SpecialChunk 的 Treasure / Shrine / Shop 接到 Gameplay controller。

## 验证

静态验证（压缩包根目录）：

```bash
python validate_gameplay_v4_0.py
```

有 Godot 4 可执行文件时可额外运行纯 Gameplay smoke test：

```bash
godot --headless --path game --scene res://tests/GameplayCombatSmokeTest.tscn
```

原有 3.x validators 也应继续通过。当前包未附带可执行 Godot Editor，因此仍需在目标机器上打开 `scenes/World.tscn` 做真实 World + Physics + Rendering runtime smoke test。
