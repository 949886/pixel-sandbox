# Pixel Sandbox

> 基于 Godot 4.7 与原生 falling-sand GDExtension 构建的横版像素沙盒 / Wand 组合玩法原型。


Pixel Sandbox 是一个类 Noita 游戏。同时项目提供 **Creative Mode**，可以直接绘制像素世界、创建和编辑法杖、生成测试实体，并暂停或单步运行沙盒模拟。


---

## 目录

- [当前已经完成的内容](#当前已经完成的内容)
- [核心架构](#核心架构)
- [1. Piece 世界生成](#1-piece-世界生成)
- [2. Chunk Streaming 与性能系统](#2-chunk-streaming-与性能系统)
- [3. Falling-sand 像素模拟](#3-falling-sand-像素模拟)
- [4. 动态碰撞与视觉增量更新](#4-动态碰撞与视觉增量更新)
- [5. Player 与基础 Gameplay](#5-player-与基础-gameplay)
- [6. Wand / Spell 系统](#6-wand--spell-系统)
- [7. Inventory / Gameplay UI](#7-inventory--gameplay-ui)
- [8. Creative Mode](#8-creative-mode)
- [9. Mobile / Touch](#9-mobile--touch)
- [10. Debug 与测试](#10-debug-与测试)
- [操作说明](#操作说明)
- [运行与平台](#运行与平台)
- [目录结构](#目录结构)
- [当前已知限制](#当前已知限制)
- [接下来的主要开发方向](#接下来的主要开发方向)
- [文档索引](#文档索引)

---

# 当前已经完成的内容

目前项目已经具备以下主要系统：

- 128×128 Piece 驱动的程序化洞穴世界。
- 512×512 World Chunk 与动态流式加载 / 卸载。
- 60 个 Piece Definition、3 个 Biome、4 个 Special Chunk。
- 后台线程 Chunk 生成与主线程预算化上传。
- 原生 falling-sand 像素模拟。
- 16×16 Active Simulation Blocks。
- Native 跨 Chunk 液体 / 气体 / Powder 流动。
- 64×64 Collision Sectors 与增量动态碰撞重建。
- 64×64 Visual Sectors 与 RenderingDevice 局部纹理更新。
- PC / Mobile 独立 Runtime Profile。
- 完整横版 Player Controller：移动、冲刺、跳跃、悬浮、游泳、蹲伏、Aim、Kick。
- Health / Damage / Faction / Status Gameplay 基础组件。
- Water / Oil / Fire / Lava / Acid 与 Actor 状态交互。
- Cave Eye 第一种正式敌人。
- Gold Pickup 与 Spell Pickup。
- 数据驱动 Wand / Spell / GameplayEffect 架构。
- 从旧 Luna C# 项目迁移并 GDScript 化的 Wand Deck / Modifier / Multicast 系统。
- 32 个当前可用 Spell Resource。
- 像素化 Projectile / Trail / Impact / Lightning / Special Spell VFX。
- 4 Wand Slots + 24 Spell Inventory。
- Spell 拖拽、交换、拾取与实时 Wand Deck 重建。
- Noita-like Normal Gameplay UI。
- Painting 风格 Creative UI。
- Creative Material Brush / Erase / Picker。
- Creative 无限 Spell Library 与 Wand Lab。
- Creative Entity Spawner / Delete Tool。
- Sand Simulation Pause / Step / Speed Control。
- Desktop + Touch 输入支持。
- Debug Overlay、World Debug、Collision Debug 与多组 Smoke Test / Validation Script。

---

# 核心架构

项目目前大致分为以下几层：

```text
World Structure / Biome / Special Chunk
                 │
                 ▼
        Piece Chunk Generation
                 │
                 ▼
        512×512 World Chunk
                 │
                 ▼
       Material / Element Mapping
                 │
                 ▼
       Native SandSimulation
                 │
      ┌──────────┼──────────┐
      │          │          │
      ▼          ▼          ▼
 Simulation   Collision   Visual
  Blocks      Sectors     Sectors
   16×16       64×64       64×64
      │          │          │
      └──────────┼──────────┘
                 ▼
       WorldGameplayService
                 │
      ┌──────────┼───────────┐
      ▼          ▼           ▼
   Player      Combat      Wand/Spell
      │          │           │
      └──────────┼───────────┘
                 ▼
        Gameplay / Creative UI
```

一个重要设计原则是：

> **Gameplay 不直接依赖 Chunk / Sector / Native Grid 的内部实现。**

Player、Spell、Creative Tool 等通过 `WorldGameplayService` 操作世界，让 3.x 的世界底层可以继续独立优化，而不会牵连 Gameplay 层。

---

# 1. Piece 世界生成

## 基础尺寸

```text
Piece Unit       128 × 128 px
Chunk Units        4 × 4
World Chunk      512 × 512 px
```

定义位于：

```text
scripts/piece_world/PieceWorldConstants.gd
```

## Piece 系统

当前共有：

```text
Generated Pieces   57
Uploaded Pieces     3
Total Pieces       60
```

Piece 使用四边 Socket Profile 进行连接。当前 Socket 类型已经精简为：

```text
SOLID
OPEN_SMALL
DOUBLE_OPEN_SMALL
OPEN_MEDIUM
OPEN_LARGE
ANY
```

旧的 `ROOM / SHAFT` Socket 已移除；房间、实验室、洞穴等语义继续通过 Piece kind / tags 表达。

核心文件：

```text
scripts/piece_world/PieceChunkGenerator.gd
scripts/piece_world/PieceDef.gd
scripts/piece_world/PiecePlacement.gd
scripts/piece_world/PieceSocket.gd
scripts/piece_world/PieceLibrary.gd
scripts/world/SocketProfilePlanner.gd
scripts/world/WorldSeamRegistry.gd
resources/pieces/piece_library.tres
```

## Biome

当前拥有 3 个 Biome：

```text
Mine
Snow
Deep
```

资源位于：

```text
resources/biomes/
```

Biome 可以控制不同深度下的：

- Piece Pool
- Opening 概率
- Cave / Main Path 倾向
- Special Chunk 分布
- 材质与视觉风格

## Special Chunk

当前有 4 类特殊区域：

```text
Mine Treasure
Ancient Hall
Snow Shrine
Crystal Grotto
```

核心系统：

```text
scripts/special/SpecialChunkPlanner.gd
scripts/special/SpecialChunkManager.gd
scripts/special/SpecialPieceRenderer.gd
resources/special_chunks/
```

Special Chunk 已具备 biome、depth、branch、placement weight 等结构条件，后续可以直接作为 Chest、Shop、Shrine、Boss、Puzzle 等 Gameplay Room 的挂载点。

---

# 2. Chunk Streaming 与性能系统

世界不是一次性全部生成，而是围绕玩家进行动态 Streaming。

当前包含：

- 玩家附近 Chunk 动态加载。
- 远处 Chunk 卸载。
- Background Worker 生成普通 Piece Chunk。
- Background Worker 生成 Special Chunk 图像。
- 有界 Ready Queue。
- 主线程 Upload Budget。
- Renderer Pool。
- Worker Queue 根据玩家位置重新排序。
- 玩家移动方向 Predictive Prewarm。
- PC / Mobile 独立 Runtime Profile。

核心文件：

```text
scripts/world/WorldManager.gd
scripts/world/ChunkGenerationWorker.gd
scripts/special/SpecialChunkImageWorker.gd
scripts/piece_world/PieceChunkRenderer.gd
```

## Runtime Profile

资源：

```text
resources/runtime_profiles/pc_runtime_profile.tres
resources/runtime_profiles/mobile_runtime_profile.tres
```

当前典型设置：

| 项目 | PC | Mobile |
|---|---:|---:|
| Chunk Load Radius | 2 | 1 |
| Simulation Radius | 1 | 0 |
| Main Simulation | 60 Hz | 30 Hz |
| Background Simulation | 60 Hz | 8 Hz |

PC 默认相当于维持约 5×5 Chunk 的加载区域；移动端默认约 3×3，以更保守的模拟半径换取帧时间稳定性。

---

# 3. Falling-sand 像素模拟

项目通过 `fallingsand` GDExtension 驱动像素级材料模拟。

运行时由 `PixelChunkCanvas.gd` 检测 Native API 能力。当前 Visual Sector 路径要求：

```text
Native API >= 12
```

## Active Simulation Blocks

每个 512×512 Chunk 内部使用：

```text
Simulation Block = 16×16
32×32 Blocks / Chunk
1024 Blocks / Chunk
```

Block 可以处于：

```text
Active
Cooling
Sleeping
```

稳定区域不会每帧重复扫描；发生 `set_cell()`、爆炸、地形破坏、跨 Chunk 流动等变化时，会重新唤醒相关 Block 与邻域。

同时存在材料 Activity Policy，避免 REACTIVE / AUTONOMOUS 材料被错误睡眠。

## Native Cross-Chunk Flow

跨 Chunk 边界的材料流动已经转入 Native Seam Bridge，包括：

- Liquid 下落与横向流动。
- Gas 上升。
- Powder 跨边界移动。
- 斜向移动。
- Density swap。
- Mobile Warm Neighbour / Dynamic Wake。

这一层解决的是“材料能够跨 Chunk 移动”；更完整的跨 Chunk reaction neighbourhood / ghost halo 仍属于后续技术方向。

---

# 4. 动态碰撞与视觉增量更新

## Collision Sectors

动态像素碰撞使用：

```text
Collision Sector = 64×64
8×8 Sectors / Chunk
64 Sectors / Chunk
```

使用 `PhysicsServer2D RID` 管理动态 Shape，而不是为每个区域创建大量 Scene Node。

当前已经包含：

- Dirty Sector。
- Sector Revision。
- Occupancy Bitset。
- Added / Removed 变化分类。
- Conservative Snapshot。
- Staging Collision。
- Atomic Physics Commit。
- Dynamic rebuild throttle。
- Collision-first safety。

例如 `Air → Solid` 会优先提交碰撞再显示，避免玩家先进入尚未生成碰撞的墙体。

## Visual Sectors

Visual update 同样使用：

```text
Visual Sector = 64×64
8×8 Sectors / Chunk
```

局部变化只生成 64×64 RGBA staging texture，再通过 `RenderingDevice.texture_copy()` 更新 512×512 Chunk Texture 的对应区域。

当 Dirty Sector 数量过多时，自动回退到 full repaint：

```text
VISUAL_FULL_REPAINT_THRESHOLD = 24
```

因此目前 Simulation / Collision / Visual 三条主要像素世界性能路径都已经具备局部更新机制。

---

# 5. Player 与基础 Gameplay

## Character Controller

Player 当前支持：

- 左右移动。
- Sprint。
- Acceleration / Deceleration。
- Gravity / Max Fall Speed。
- Jump。
- Coyote Time。
- Jump Buffer。
- Short Hop。
- Noita-like Levitation Fuel。
- Ground / Swimming Fuel Recharge。
- Crouch。
- Fast Fall。
- Swimming / Dive。
- 约 3px 小台阶自动适配。
- 独立 Arm / Wand Aim。
- Kick。
- Camera Zoom。
- Creative No-clip Fly。

Player 场景：

```text
scenes/Player.tscn
scripts/player/Player.gd
```

## Combat Foundation

Gameplay Combat 已拆成独立组件：

```text
DamagePacket
DamageTypes
HealthComponent
FactionComponent
GameplayProjectile
```

主要文件：

```text
scripts/gameplay/combat/
```

Player 和 Enemy 使用同一套 Damage Pipeline，不需要各自维护一套伤害逻辑。

## Status / Environment

当前已经接入：

```text
Wet
Oiled
Burning
Toxic Contact
Slow
Stun
```

世界材质与 Actor 状态存在真实 Gameplay 关系，例如：

```text
Water
→ Wet
→ 加速熄灭 Burning

Oil
→ Oiled
→ 延长并强化 Burning

Fire / Lava
→ Burning / Fire Damage

Acid
→ Toxic Contact Damage
```

核心文件：

```text
scripts/gameplay/status/EnvironmentSensor.gd
scripts/gameplay/status/StatusComponent.gd
scripts/gameplay/status/GameplayMaterialRules.gd
```

## Enemy / Pickup

当前正式敌人：

```text
Cave Eye
```

它是一种适合可破坏地形环境的飞行远程敌人，不依赖动态 NavigationMesh。

当前 Pickup：

```text
Gold Pickup
Spell Pickup
```

Cave Eye 可以掉落 Gold 与 Spell。

---

# 6. Wand / Spell 系统

Wand 系统已经从早期 Player 固定参数，发展为正式的数据驱动系统，并融合了旧 Luna C# Wand/Spell 架构。

## 施法链

```text
WandController
      │
      ▼
WandDef
      │
      ▼
SpellDeckRuntime
      │
      ▼
SpellDef
      │
      ▼
SpellCastState / CastContext
      │
      ▼
GameplayEffect
      │
      ├── Projectile
      ├── Damage
      ├── Explosion
      ├── Terrain
      ├── Material
      ├── Status
      ├── Hitscan
      ├── Teleport
      └── Special Runtime
```

## Wand 能力

当前支持：

- Mana Max。
- Mana Recharge。
- Cast Delay。
- Recharge Time。
- Capacity。
- Spread。
- Shuffle。
- Deck Cursor / Reload。
- Modifier 传播。
- Extra Draw。
- Multicast。
- Formation。
- Recoil。
- Critical Chance 数据。
- Runtime duplicate / live refresh。

## 当前 Spell 数量

当前工程包含 **32 个 Spell Resource**，分为：

```text
4  基础验证 Spell
16 Luna Action Spell
5  Modifier
7  Multicast / Formation
```

### 基础 Spell

```text
Spark Bolt
Dig Bolt
Fire Bolt
Bomb
```

### Luna Action Spell

包括：

```text
Acid Splash
Black Hole
Chainsaw
Death Cross
Dragon Breath
Dynamite
Energy Sphere
Explosive Bomb
Fireball
Glue Ball
Ice Bolt
Lightning
Lightning Beam
Magic Arrow
Spark
Teleport Bolt
```

### Modifier

```text
Damage Plus
Spread
Fixed Angle
Long Distance Cast
Light
```

### Multicast / Formation

```text
Double Cast
Triple Cast
Quadruple Cast
Octuple Cast
Double Scatter
Formation
Formation Back And Front
```

## 像素法术表现

法术视觉不使用大量平滑 Sprite 粒子，而是强调与世界一致的低分辨率颗粒感：

- 整数像素对齐。
- 方形弹丸核心。
- 离散像素 Trail。
- Pixel muzzle / impact debris。
- Zig-zag Lightning Arc。
- 特殊法术运行时像素场。
- Fire / Acid 等部分效果直接写入真实 SandSimulation。

例如：

```text
Fire Bolt / Fireball / Dragon Breath
→ Visual fire particles
→ Actor Burning
→ Real Fire material in world

Acid Splash
→ Toxic damage
→ Real Acid material

Bomb / Dynamite
→ Actor damage
→ Terrain destruction
→ Impulse
→ Fire material
```

VFX 核心：

```text
scripts/gameplay/vfx/PixelSpellVFX.gd
scripts/gameplay/vfx/PixelArcVFX.gd
scripts/gameplay/spells/runtime/SpecialSpellRuntime.gd
```

---

# 7. Inventory / Gameplay UI

Normal Mode 使用一套独立 Gameplay UI，不再把临时 HUD 挂在 Player 身上。

## Player Inventory

当前默认：

```text
Wand Slots       4
Spell Inventory 24
```

支持：

- Wand 装备切换。
- Spell Inventory。
- Wand Deck 编辑。
- Spell 拖拽。
- Wand ↔ Inventory 交换。
- Slot ↔ Slot 交换。
- 点击交换作为 Touch fallback。
- Shift / Double-click 快速移动 Spell。
- Runtime Wand Deck 实时重建。
- Spell Pickup 自动进入 Inventory。
- Inventory 满时 Pickup 不会被吞掉。

## UI 架构

固定 UI 已经全部迁入 `.tscn`，Script 主要负责逻辑、数据绑定与信号。

```text
scenes/ui/GameplayUI.tscn
scenes/ui/shared/SpellSlot.tscn
scenes/ui/shared/WandGlyph.tscn
scenes/ui/shared/WandQuickSlot.tscn
scenes/ui/shared/WandRowUI.tscn
scenes/ui/shared/StatusLabel.tscn
```

Normal Gameplay UI 当前采用 Noita-like 的布局思路：

- Wands / Items 快捷区。
- HP / Mana / Flight / Gold / Status HUD。
- 展开的 Wand Deck。
- Spell Inventory。
- Wand Detail。
- Spell Tooltip。
- Drag Preview 独立高层 CanvasLayer。

Spell 图标图集存放在：

```text
resources/gameplay/spells/atlas/
```

`SpellDef` 直接持有 `Texture2D` 资源引用，UI 不通过硬编码路径查找图标。

---

# 8. Creative Mode

Creative Mode 是当前项目的重要开发 / Sandbox 工具，而不仅仅是无敌作弊模式。

开发阶段按：

```text
F8
```

切换：

```text
NORMAL ↔ CREATIVE
```

Game Mode 由：

```text
scripts/gameplay/modes/GameModeManager.gd
scripts/gameplay/modes/GameRules.gd
resources/gameplay/modes/creative_rules.tres
```

统一管理。

默认 Creative Rules：

```text
Invulnerable       ON
Infinite Mana      ON
Infinite Flight    ON
Creative Fly       ON
World Editing      ON
Wand Lab           ON
Entity Spawning    ON
Progression        OFF
```

## Creative UI

Creative UI 完全采用项目 `painting` 模块的视觉语言：

- Painting Theme。
- Poppins 字体。
- 灰紫色面板。
- Painting 风格 Button / Toggle / ScrollBar。
- 橙色选中状态。
- Bottom Dock 工作区。

场景：

```text
scenes/ui/creative/CreativeUI.tscn
```

当前包含：

```text
MATERIALS
SPELLS
WANDS
ENTITIES
PLAYER
WORLD
```

## MATERIALS

支持：

```text
BRUSH
ERASE
PICK
Brush Size 1–64
```

Material Palette 来自正式 Material 数据，不需要在 UI 中手写材料列表。

连续拖动使用插值 Brush，避免快速移动鼠标时出现断点。

世界修改走：

```text
CreativeBrushController
→ WorldGameplayService
→ WorldManager
→ PixelChunkCanvas
→ Native fallingsand region operation
```

不会照搬 Painting Demo 的逐像素 GDScript `draw_cell()` 路径。

### Creative 输入仲裁

当 MATERIALS Tool 正在占用左键时：

```text
左键 = 绘制 / 擦除 / 取样
```

不会同时发射 Wand。

切换到 SPELLS / WANDS / PLAYER / WORLD 后，左键重新允许正常法术测试。

## SPELLS

Creative 模式提供：

```text
Infinite Spell Library
```

Spell 数据来自 `SpellCatalog`，支持搜索与分类。

Library 中的 Spell 不会被消耗，可以无限：

```text
Spell Library
→ Drag
→ 任意 Wand Slot
```

## WANDS

Creative Wand Lab 支持：

```text
NEW
DUPLICATE
DELETE
CLEAR SPELLS
EQUIP
```

并允许实时修改：

```text
Mana
Mana Recharge
Cast Delay
Recharge Time
Capacity
Spread
Spells / Cast
Shuffle
```

所有编辑都作用于 runtime duplicate，不会修改原始 `.tres`。

第二 Wand Slot 默认提供一根：

```text
High Performance Test Wand
```

用于高频法术 / 弹幕测试。

## ENTITIES

当前 Creative Entity Sandbox 支持生成：

```text
Cave Eye
Gold Pickup
Fireball Spell Pickup
```

工具：

```text
SPAWN
DELETE
CLEAR SPAWNED
```

只有创造模式生成并标记为 `creative_deletable` 的实体可以被 DELETE / CLEAR 删除，避免误删 Player、WorldManager 等核心节点。

## PLAYER

可以切换：

```text
Invulnerable
Infinite Mana
Infinite Flight
No-clip Creative Fly
```

并提供：

```text
Heal
Clear Status
```

## WORLD / Simulation Lab

目前支持：

```text
Pause Sand
Step 1 Tick
Simulation Speed
```

速度：

```text
0.25x
0.50x
1.00x
2.00x
4.00x
```

暂停的是 SandSimulation，而不是整个 SceneTree，因此暂停后仍然可以：

- 移动 Player。
- 操作 Creative UI。
- 绘制材料。
- 调整 Wand。
- 观察单步模拟。

退出 Creative Mode 时会自动恢复：

```text
Simulation = Running
Speed = 1x
```

---

# 9. Mobile / Touch

项目已有独立 Touch Control：

- 左侧 Virtual Joystick。
- Jump / Flight。
- Directional Fire。
- 多 Touch Index 分离。
- Web Mobile 环境检测。
- PC / Mobile Runtime Profile 自动选择。

相关场景：

```text
scenes/ui/TouchControls.tscn
```

Mobile 默认采用更小的 Chunk Load Radius、更低 simulation cadence 与更保守的 visual settings。

---

# 10. Debug 与测试

## Runtime Debug

主要快捷键：

```text
F1  Debug Overlay
F2  World Structure Debug
F6  Collision Sector Debug
```

Debug Overlay 当前可以观察：

- World / Streaming。
- Current Chunk。
- Piece / Seam。
- Generation Queue。
- Special Structure。
- Simulation。
- Active Blocks。
- Cross-Chunk Flow。
- Collision。
- Frame Pipeline。

## Smoke Tests

当前工程包含：

```text
tests/ActiveBlockSmokeTest.tscn
tests/CollisionSectorSmokeTest.tscn
tests/NativeSeamBridgeSmokeTest.tscn
tests/GameplayCombatSmokeTest.tscn
tests/GameplayUIInventorySmokeTest.tscn
tests/LunaWandMigrationSmokeTest.tscn
tests/LifetimeReferenceSmokeTest.tscn
tests/ProjectileRuntimeSafetySmokeTest.tscn
tests/CreativeModeSmokeTest.tscn
tests/CreativeEntitySpawnPositionSmokeTest.tscn
```

另外还有大量 Python 静态 / 模型 Validation，用于检查：

- Active Blocks。
- Collision Sector。
- Native Flow。
- Visual Sector。
- Mobile Budget。
- Gameplay / Wand。
- UI / Inventory。
- Creative Mode。
- Resource reference。

---

# 操作说明

## Normal Mode

| 输入 | 功能 |
|---|---|
| `A / D`、方向键 | 左右移动 |
| `Shift` | Sprint |
| `W / Space / ↑` | Jump / 空中悬浮 |
| `S / ↓` | Crouch / Fast Fall / Dive |
| 鼠标 | Aim |
| 左键 | Cast Wand |
| 右键 / `F` | Kick |
| `1`–`4` | 选择 Wand Slot |
| 鼠标滚轮 | 循环 Wand |
| `Tab / I` | 打开 Wand Editor / Spell Inventory |
| `Esc` | 关闭 Inventory |
| `+ / -` | Camera Zoom |
| `F1` | Debug Overlay |
| `F2` | World Debug |
| `F3` | 使用相同 Seed Regenerate |
| `F4` | 使用下一个 Seed Regenerate |
| `F6` | Collision Sector Debug |
| `F8` | 开发阶段切换 Creative Mode |

## Creative Mode

`F8` 进入 Creative 后：

| 区域 | 功能 |
|---|---|
| MATERIALS | Brush / Erase / Picker |
| SPELLS | 无限 Spell Library，拖入 Wand |
| WANDS | 新建 / 复制 / 删除 / 编辑 Wand |
| ENTITIES | Spawn / Delete / Clear Creative Entity |
| PLAYER | 无敌、无限 Mana / Flight、No-clip |
| WORLD | Pause / Step / Simulation Speed |
| `Tab / I` | 展开 / 收起 Creative Bottom Dock |
| 中键 | Material Picker |
| `Shift` | Creative Fly 加速 |

注意：MATERIALS / ENTITIES 工具使用主鼠标键时，会通过 Input Arbitration 阻止 Wand 同时施法。

---

# 运行与平台

## Godot

工程目标版本：

```text
Godot 4.7
Forward Plus
```

主场景：

```text
res://scenes/World.tscn
```

项目开启：

```text
textures/vram_compression/import_etc2_astc=true
```

## Native fallingsand

GDExtension：

```text
res://bin/fallingsand/fallingsand.gdextension
```

当前工程包实际包含的最新编译产物：

```text
Windows x86_64  Debug / Release
Android arm64   Debug / Release
Web wasm32      Debug / Release
```

`fallingsand.gdextension` 中仍声明了 Linux、macOS、Windows x86_32、Android x86_64 等平台路径，但这些平台的二进制**没有全部包含在当前工程包中**。

因此：

> 如果需要在未打包 Native Binary 的平台运行，请先重新编译 fallingsand GDExtension 并补齐 `bin/fallingsand/` 对应文件。

## Export Presets

当前 `export_presets.cfg` 已定义：

```text
Windows
Linux
macOS
Web
Android
iOS
```

但 Export Preset 的存在不等于对应 Native GDExtension Binary 已经齐全，请以上一节的实际文件列表为准。

---

# 目录结构

```text
.
├── README.md
├── docs/                         # 技术说明、版本说明、验证报告
├── scenes/
│   ├── World.tscn                # 主场景
│   ├── Player.tscn
│   ├── gameplay/
│   └── ui/
│       ├── GameplayUI.tscn
│       ├── TouchControls.tscn
│       ├── creative/
│       └── shared/
│
├── scripts/
│   ├── world/                    # Streaming / Chunk / WorldManager
│   ├── piece_world/              # Piece 世界生成
│   ├── special/                  # Special Chunk
│   ├── pixel_world/              # PixelChunkCanvas / simulation bridge
│   ├── player/
│   ├── gameplay/
│   │   ├── combat/
│   │   ├── creative/
│   │   ├── enemies/
│   │   ├── items/
│   │   ├── modes/
│   │   ├── spells/
│   │   ├── status/
│   │   ├── vfx/
│   │   └── world/
│   ├── ui/
│   └── debug/
│
├── resources/
│   ├── generated_pieces/
│   ├── pieces/
│   ├── biomes/
│   ├── special_chunks/
│   ├── runtime_profiles/
│   └── gameplay/
│       ├── creative/
│       ├── modes/
│       ├── spells/
│       │   └── atlas/
│       └── wands/
│
├── painting/                     # 独立 Painting Demo / Creative UI 视觉参考
├── bin/fallingsand/              # GDExtension 编译产物
└── tests/                        # Smoke Test / Validation
```

---

# 当前已知限制

## 1. Creative Terrain Undo / Redo 尚未完成

目前 Brush 修改通过 Native region operation 批量执行，性能较好；但 fallingsand 尚未提供：

```text
capture_region()
restore_region()
```

一类 Native region snapshot API。

因此暂时没有使用 GDScript 逐像素读取旧 Cell 的低性能方式硬做 Undo。

推荐后续 Native API 方向：

```text
capture_region(x, y, width, height)
restore_region(x, y, width, height, data)
```

再在 Creative History 中存储区域快照。

## 2. 跨 Chunk 邻域反应仍可继续加强

当前 Native Seam Bridge 已解决材料跨 Chunk transport，但 Fire / Acid / Explosion 等更复杂规则若需要完整读取相邻 Chunk 邻域，后续仍适合加入 Ghost Halo。

## 3. Gameplay 内容量仍处于 Alpha 阶段

目前只有第一只正式敌人 Cave Eye，尚未形成完整：

- Enemy roster。
- Boss。
- Chest / Shop / Shrine 玩法。
- Potion / General Item。
- 完整 Loot Economy。
- Run End / Victory。
- Meta Progression。

## 4. World Persistence 尚未正式建立

当前主线倾向 Roguelite Run，因此没有优先实现完整长期 World Delta Save。

## 5. Native 平台文件尚未全部补齐

当前包主要保证 Windows x86_64、Android arm64、Web wasm32 编译产物；Linux / macOS / 其他架构仍需自行编译。

## 6. 自动验证不能完全代替真机 Runtime Test

项目包含较多 Static Validation 与 Smoke Test，但 GDExtension、Physics、RenderingDevice、Mobile GPU 行为仍需要在实际目标设备上验证。

---

# 接下来的主要开发方向

根据当前完成度，后续优先级建议为：

## Creative Mode

- fallingsand Native region snapshot / restore。
- Terrain Undo / Redo。
- 更多 Creative Entity。
- World Snapshot。
- Line / Rectangle / Fill Tool。
- Simulation Debug / Material Inspect。

## Gameplay

- 更多 Enemy / AI archetype。
- Melee / Flying / Material Enemy。
- Chest、Treasure Room、Shrine、Shop。
- Wand Pickup / Wand Compare。
- Potion / Item 系统。
- 更完整 Spell Loot 与 rarity。
- Boss 与 Biome progression。
- RunManager / Death / Victory loop。

## Wand / Spell

- 更多 Luna Spell 迁移与新 Spell。
- Trigger / Timer / On-hit Cast。
- 更多 Modifier。
- Cast Preview / Wand Analyzer。
- 更完整递归 / projectile safety budget。

## 世界与模拟

- Ghost Halo / Cross-Chunk reaction neighbourhood。
- Visual-only animated material policy。
- Visual Sector threshold 真机 Profiling。
- 更多 Biome / Piece / Special Chunk 内容。

---

# 文档索引

README 只保留当前项目总览。详细设计、版本说明和验证报告统一存放在：

```text
docs/
```

建议优先阅读：

## Gameplay / Wand / UI

- [`docs/GAMEPLAY_V4_0_FOUNDATION.md`](docs/GAMEPLAY_V4_0_FOUNDATION.md)
- [`docs/GAMEPLAY_V4_1_WAND_PIXEL_SPELLS.md`](docs/GAMEPLAY_V4_1_WAND_PIXEL_SPELLS.md)
- [`docs/GAMEPLAY_V4_2_LUNA_WAND_MIGRATION.md`](docs/GAMEPLAY_V4_2_LUNA_WAND_MIGRATION.md)
- [`docs/GAMEPLAY_V4_2_2_RUNTIME_HARDENING.md`](docs/GAMEPLAY_V4_2_2_RUNTIME_HARDENING.md)
- [`docs/GAMEPLAY_V4_3_WAND_EDITOR_INVENTORY_UI.md`](docs/GAMEPLAY_V4_3_WAND_EDITOR_INVENTORY_UI.md)
- [`docs/GAMEPLAY_V4_4_NOITA_UI_REBUILD.md`](docs/GAMEPLAY_V4_4_NOITA_UI_REBUILD.md)

## Creative Mode

- [`docs/GAMEPLAY_V4_5_CREATIVE_SANDBOX_WAND_LAB.md`](docs/GAMEPLAY_V4_5_CREATIVE_SANDBOX_WAND_LAB.md)
- [`docs/GAMEPLAY_V4_5_1_PAINTING_CREATIVE_UI.md`](docs/GAMEPLAY_V4_5_1_PAINTING_CREATIVE_UI.md)
- [`docs/GAMEPLAY_V4_5_2_SCENE_UI_INPUT_ARBITRATION.md`](docs/GAMEPLAY_V4_5_2_SCENE_UI_INPUT_ARBITRATION.md)
- [`docs/GAMEPLAY_V4_5_3_CREATIVE_SANDBOX_TOOLS.md`](docs/GAMEPLAY_V4_5_3_CREATIVE_SANDBOX_TOOLS.md)
- [`docs/GAMEPLAY_V4_5_3_1_ENTITY_SPAWN_POSITION_FIX.md`](docs/GAMEPLAY_V4_5_3_1_ENTITY_SPAWN_POSITION_FIX.md)

## Pixel World / Performance

- [`docs/THREADING_STREAMING_GUIDE.md`](docs/THREADING_STREAMING_GUIDE.md)
- [`docs/RUNTIME_PROFILES_GUIDE.md`](docs/RUNTIME_PROFILES_GUIDE.md)
- [`docs/MOBILE_PERFORMANCE_GUIDE.md`](docs/MOBILE_PERFORMANCE_GUIDE.md)
- [`docs/NATIVE_CROSS_CHUNK_FLOW_V3_8.md`](docs/NATIVE_CROSS_CHUNK_FLOW_V3_8.md)
- [`docs/NATIVE_ACTIVE_BLOCKS_V3_9.md`](docs/NATIVE_ACTIVE_BLOCKS_V3_9.md)
- [`docs/VISUAL_SECTORS_V3_10.md`](docs/VISUAL_SECTORS_V3_10.md)
- [`docs/COLLISION_BURNING_PERFORMANCE_V3_7_2.md`](docs/COLLISION_BURNING_PERFORMANCE_V3_7_2.md)

## Debug / Player

- [`docs/DEBUG_OVERLAY_GUIDE.md`](docs/DEBUG_OVERLAY_GUIDE.md)
- [`docs/PLAYER_CONTROLLER_GUIDE.md`](docs/PLAYER_CONTROLLER_GUIDE.md)
- [`docs/PIECE_GENERATION_SEQUENCE_DEMO_GUIDE.md`](docs/PIECE_GENERATION_SEQUENCE_DEMO_GUIDE.md)

---

# 当前项目阶段

如果从底层技术来看，项目已经具备比较完整的：

```text
Procedural World
+ Streaming
+ Falling Sand
+ Dynamic Collision
+ Incremental Rendering
+ Cross-Chunk Flow
+ Wand Runtime
+ Creative Sandbox
```

接下来最重要的任务已经不再是继续大幅重构 3.x 底层，而是利用这些系统构建真正的游戏内容：

```text
探索
→ 战斗
→ 环境互动
→ 获得 Spell / Wand
→ 编辑 Wand
→ 深入 Biome / Special Room
→ 更强敌人 / Boss
→ Run Progression
```

当前 V4.x 的核心方向可以概括为：

> **使用可组合的法术操控一个真实模拟的像素环境，通过环境、元素、地形和 Wand 构筑解决战斗与探索问题。**
