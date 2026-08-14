# GitHub Roadmap Manifest

> **Planning only：本文件不会创建或修改任何 GitHub Issue、Label、Milestone。**

这份 Manifest 将当前已经讨论过的后续迭代统一整理为可落地的 GitHub 结构。它同时定义标题规则、Labels、Milestones、父子关系、依赖关系和验收标准；真正创建 GitHub 对象时以本文与同目录 YAML 为准。

## 1. 约定

- **Issue 标题保持整洁**：标题只写任务名称，例如 `Wand Loot & Generation`，不写 `[V5.0][EPIC][P0]`。
- **版本号进入 Milestone**：V5.0、V5.1 等全部由 Milestone 表达。
- **类型 / Area / Priority 进入 Label**：`type:*`、`area:*`、`priority:*`。
- **最多 4 层 Issue**：Roadmap → Version/Theme Epic → System Epic → Concrete Task；更细实现步骤放 Issue 内 checkbox。
- **V5.0 Scope Guard**：若任务不能明显改善 `New Game → Explore → Fight → Loot → Build Wand → Special Room → Boss → End`，默认不属于 V5.0 blocker。
- **不一次性创建全部 105 个定义**：Manifest 可以完整，但 GitHub Open Issue 应按接近开发的范围逐步展开。

## 2. Milestones

### V5.0 — First Playable Game

状态：`current`

完成第一条从 New Game 到 Mine Boss / Victory 的完整可玩 Game。

### V5.1 — Wand & Material Gameplay

状态：`planned`

深化 Wand 构筑，并让 Spell 更系统地操纵像素环境。

### V5.2 — Snow Biome Gameplay

状态：`planned`

把 Snow 做到与 Mine 同等级的第二个完整 Gameplay Biome。

### V5.3 — Creative Developer Toolkit

状态：`planned`

把 Creative Mode 提升为高效率 Gameplay 开发与复现工具。

### V5.4 — Engine & Platform Hardening

状态：`planned`

在 Gameplay Loop 稳定后系统处理性能、稳定性和平台覆盖。

### V6.0 — World & Progression Expansion

状态：`future`

扩展 Deep、多 Biome Run、Elite、更多 Boss 与世界进度。

### V6.1 — Meta Progression

状态：`tentative`

仅在基础 Game 已被证明好玩后评估局外成长。

## 3. Labels

### Type

- `type:roadmap` — 跨多个版本的长期路线图
- `type:epic` — 由多个子任务组成的系统级/版本级 Epic
- `type:feature` — 独立功能
- `type:content` — 敌人、Boss、房间、Biome 等内容
- `type:tech` — 架构、性能、Native、平台技术任务
- `type:bug` — 缺陷修复
- `type:balance` — 数值、掉落、难度、经济、手感

### Area

- `area:run` — Game 生命周期与进度
- `area:world` — 世界、Encounter、房间、Biome
- `area:enemy` — 敌人与 AI
- `area:combat` — 战斗规则与反馈
- `area:loot` — 掉落、奖励、经济、Pickup
- `area:wand` — Wand 系统
- `area:spell` — Spell/Cast/Modifier
- `area:material` — 材质 Gameplay
- `area:ui` — Gameplay UI
- `area:creative` — Creative Sandbox/开发工具
- `area:native` — fallingsand Native
- `area:platform` — 平台覆盖与设备 profiling

### Priority

- `priority:P0` — 阻塞当前 Milestone 发布
- `priority:P1` — 当前 Milestone 强烈需要
- `priority:P2` — 有价值的后续增强
- `priority:P3` — 长期 backlog / nice-to-have

## 4. 总体 Issue Tree

```text
Gameplay Alpha Roadmap  (`roadmap-alpha`)
├── First Playable Game  (`first-playable-run`)
│   ├── Game Foundation  (`run-foundation`)
│   │   ├── GameManager and Game State  (`run-manager-state`)
│   │   ├── Game Death and Restart Flow  (`run-death-restart`)
│   │   ├── Game Start, Death, Victory and Summary UI  (`run-ui-summary`)
│   │   └── Clean Session Reset  (`session-reset`)
│   ├── Wand Loot & Generation  (`wand-loot-generation`)
│   │   ├── Runtime Wand Generator  (`runtime-wand-generator`)
│   │   ├── Deterministic Wand Generation  (`deterministic-wand-generation`)
│   │   ├── World Wand Pickup  (`world-wand-pickup`)
│   │   ├── Wand Comparison UI  (`wand-comparison-ui`)
│   │   └── Unified Wand Reward API  (`wand-reward-api`)
│   ├── Mine Enemy Set  (`mine-enemy-set`)
│   │   ├── Unified Enemy Architecture  (`enemy-architecture`)
│   │   ├── Cave Eye Production Pass  (`cave-eye-production`)
│   │   ├── Crawler  (`crawler-enemy`)
│   │   ├── Bomber  (`bomber-enemy`)
│   │   ├── Fire Slime  (`fire-slime`)
│   │   ├── Oil Slime  (`oil-slime`)
│   │   ├── Enemy Loot Tables  (`enemy-loot-tables`)
│   │   ├── Encounter Spawner and Difficulty Budget  (`encounter-spawner`)
│   │   └── Piece Spawn Anchors  (`piece-spawn-anchors`)
│   ├── Special Rooms & Economy  (`special-rooms-economy`)
│   │   ├── Chest System  (`chest-system`)
│   │   ├── Treasure Room Gameplay  (`treasure-room`)
│   │   ├── Game Modifiers / Perks v1  (`run-modifiers`)
│   │   ├── Shrine System  (`shrine-system`)
│   │   ├── Shop System  (`shop-system`)
│   │   └── Gold Economy v1  (`gold-economy`)
│   ├── Mine Boss & Exit  (`mine-boss-exit`)
│   │   ├── Boss Framework  (`boss-framework`)
│   │   ├── Boss Arena Special Chunk  (`boss-arena`)
│   │   ├── Mine Boss  (`mine-boss`)
│   │   ├── Boss Major Reward  (`boss-major-reward`)
│   │   └── Exit / Victory Flow  (`exit-victory`)
│   ├── Alpha Balance Pass  (`alpha-balance-pass`)
│   │   ├── Player Survivability Balance  (`player-balance`)
│   │   ├── Enemy Composition and Damage Balance  (`enemy-balance`)
│   │   ├── Wand Generation Balance  (`wand-generation-balance`)
│   │   ├── Loot and Economy Balance  (`loot-economy-balance`)
│   │   ├── Core Spell Baseline  (`spell-baseline`)
│   │   └── Combat Feedback Pass  (`combat-feedback`)
│   └── Basic Dig Power and Terrain Hardness  (`basic-dig-resistance`)
├── Wand & Material Gameplay  (`wand-material-gameplay`)
│   ├── Wand System Expansion  (`wand-system-expansion`)
│   │   ├── Trigger Cast Architecture  (`trigger-cast-architecture`)
│   │   ├── Trigger Spells  (`trigger-spells`)
│   │   ├── Timer Spells  (`timer-spells`)
│   │   ├── Conditional Casts  (`conditional-casts`)
│   │   ├── Homing Modifier  (`homing-modifier`)
│   │   ├── Orbit Modifier  (`orbit-modifier`)
│   │   └── Trail Modifier  (`trail-modifier`)
│   └── Material Gameplay Expansion  (`material-gameplay-expansion`)
│       ├── Material Gameplay Metadata  (`material-gameplay-metadata`)
│       ├── Full Dig Power and Hardness  (`full-dig-hardness`)
│       ├── Material Conductivity  (`conductivity-system`)
│       ├── Wet and Electricity Interaction  (`wet-electricity`)
│       └── Advanced Material Reactions  (`advanced-material-reactions`)
├── Snow Biome Gameplay  (`snow-biome-gameplay`)
│   ├── Snow Enemy Set  (`snow-enemy-set`)
│   ├── Snow Encounter Profile  (`snow-encounters`)
│   ├── Snow Environmental Hazards  (`snow-hazards`)
│   ├── Snow Loot Profile  (`snow-loot-profile`)
│   ├── Snow Special Rooms  (`snow-special-rooms`)
│   ├── Snow Boss  (`snow-boss`)
│   └── Mine to Snow Progression  (`mine-snow-progression`)
├── Creative Developer Toolkit  (`creative-developer-toolkit`)
│   ├── Scenario Presets  (`scenario-presets`)
│   ├── Creative Wand Presets  (`wand-presets`)
│   ├── Entity Spawn Sets  (`entity-spawn-sets`)
│   ├── Simulation Debugging Tools  (`simulation-debugging`)
│   └── Terrain Editing History  (`terrain-editing-history`)
│       ├── Native Region Snapshot  (`native-region-snapshot`)
│       ├── Native Region Restore  (`native-region-restore`)
│       ├── Terrain Edit Command Model  (`terrain-edit-command`)
│       ├── Creative Terrain Undo and Redo  (`terrain-undo-redo`)
│       └── Creative World Snapshot  (`world-snapshot`)
├── Engine & Platform Hardening  (`engine-platform-hardening`)
│   ├── Engine Performance Hardening  (`engine-performance-hardening`)
│   │   ├── Ghost Halo  (`ghost-halo`)
│   │   ├── Visual Sector Profiling  (`visual-sector-profiling`)
│   │   ├── Collision Sector Profiling  (`collision-sector-profiling`)
│   │   ├── Streaming Profiling  (`streaming-profiling`)
│   │   ├── Native Sand Profiling  (`native-sand-profiling`)
│   │   └── Memory and Long-run Stability  (`memory-longrun-stability`)
│   └── Platform Coverage  (`platform-coverage`)
│       ├── Linux Native Binary  (`linux-native-binary`)
│       ├── macOS Native Binary  (`macos-native-binary`)
│       ├── Android Platform Coverage  (`android-platform-coverage`)
│       ├── Web Platform Profiling  (`web-platform-profiling`)
│       ├── Mobile Hardware Profiling  (`mobile-hardware-profiling`)
│       ├── Desktop Hardware Profiling  (`desktop-hardware-profiling`)
│       └── Runtime Profile Tuning  (`runtime-profile-tuning`)
├── World & Progression Expansion  (`world-progression-expansion`)
│   ├── Deep Biome Gameplay  (`deep-biome`)
│   ├── Multi-biome Complete Game  (`multi-biome-run`)
│   ├── Elite Enemy Modifiers  (`elite-modifiers`)
│   ├── Additional Boss Archetypes  (`boss-archetypes`)
│   ├── Discovery and Collection  (`discovery-collection`)
│   └── Expanded Special Rooms  (`expanded-special-rooms`)
└── Meta Progression  (`meta-progression`)
    ├── Meta Progression Framework  (`meta-progression-framework`)
    ├── Persistent Unlocks  (`persistent-unlocks`)
    └── Meta Progression Balance Guard  (`meta-balance-guard`)
```

这个树是**完整规划图**，不是建议现在一次创建的 Open Issue 数量。V5.0 会先展开；V5.1+ 暂时主要用于保留方向和边界。

## 5. 顶层 Roadmap

### Gameplay Alpha Roadmap

`id: roadmap-alpha`

Labels: `type:roadmap`

把当前像素模拟 + Wand/Spell + Creative + 基础 Combat 原型推进为完整 Gameplay Alpha，并追踪 V5.x–V6.x 主线。

**Children**

- [ ] `first-playable-run` — First Playable Game
- [ ] `wand-material-gameplay` — Wand & Material Gameplay
- [ ] `snow-biome-gameplay` — Snow Biome Gameplay
- [ ] `creative-developer-toolkit` — Creative Developer Toolkit
- [ ] `engine-platform-hardening` — Engine & Platform Hardening
- [ ] `world-progression-expansion` — World & Progression Expansion
- [ ] `meta-progression` — Meta Progression

**Definition of Done**

- [ ] V5.0 完成第一条完整 Run
- [ ] V5.1 完成 Wand/Material 深化
- [ ] V5.2 完成第二个完整 Biome
- [ ] 完成 Alpha stabilization / release candidate

### Roadmap Issue 建议正文 Tasklist

```markdown
## V5.0 — First Playable Game
- [ ] First Playable Game

## V5.1 — Wand & Material Gameplay
- [ ] Wand & Material Gameplay

## V5.2 — Snow Biome Gameplay
- [ ] Snow Biome Gameplay

## V5.3 — Creative Developer Toolkit
- [ ] Creative Developer Toolkit

## V5.4 — Engine & Platform Hardening
- [ ] Engine & Platform Hardening

## Future
- [ ] World & Progression Expansion
- [ ] Meta Progression（tentative）
```

## 6. V5.0 — First Playable Game：完整展开

### First Playable Game

`id: first-playable-run`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:run`, `priority:P0`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

让玩家从 New Game 开始，在 Mine 中探索、战斗、Loot、构筑 Wand、进入 Special Room、击败 Boss，并以死亡或 Victory 正式结束一局。

**Children**

- [ ] `run-foundation` — Game Foundation
- [ ] `wand-loot-generation` — Wand Loot & Generation
- [ ] `mine-enemy-set` — Mine Enemy Set
- [ ] `special-rooms-economy` — Special Rooms & Economy
- [ ] `mine-boss-exit` — Mine Boss & Exit
- [ ] `alpha-balance-pass` — Alpha Balance Pass
- [ ] `basic-dig-resistance` — Basic Dig Power and Terrain Hardness

**Definition of Done**

- [ ] New Game → Explore → Fight → Loot → Build Wand → Special Room → Boss → Death/Victory 全链路成立
- [ ] 死亡真正结束 Normal Run，Restart 创建干净新 Run
- [ ] 奖励能改变 Build，Gold 有用途
- [ ] 至少 5 类正式 Mine 敌人
- [ ] Treasure / Shrine / Shop 可用
- [ ] 至少 1 个正式 Boss 和 Exit/Victory
- [ ] Creative 不参与 Normal progression
- [ ] 完整 Game 不依赖开发者手工摆放关键奖励

**Non-goals**

- 完整 Snow Biome
- Meta Progression
- 高级 Trigger/Timer Spell
- Creative Terrain Undo
- 所有 Sand Material Gameplay 化

### Game Foundation

`id: run-foundation`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:run`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

建立正式 Game 生命周期、死亡、重启、结算和 Session 清理。

**Children**

- [ ] `run-manager-state` — GameManager and Game State
- [ ] `run-death-restart` — Game Death and Restart Flow
- [ ] `run-ui-summary` — Game Start, Death, Victory and Summary UI
- [ ] `session-reset` — Clean Session Reset

**Definition of Done**

- [ ] Game 有明确状态机
- [ ] 死亡与 Restart 链路完整
- [ ] 新 Game 不继承上一局 runtime 状态

#### GameManager and Game State

`id: run-manager-state`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:run`, `priority:P0`  
Parent: `run-foundation` — Game Foundation

建立 GameManager 管理 seed、biome、depth、elapsed time、boss/special-room state 与统计。

**Definition of Done**

- [ ] 支持 STARTING / PLAYING / TRANSITION / PLAYER_DEAD / VICTORY
- [ ] Game 有唯一 seed
- [ ] 状态切换通过 signal 暴露
- [ ] GameManager 不接管 PlayerInventory/WandController/HealthComponent
- [ ] Normal 与 Creative Session 分离

#### Game Death and Restart Flow

`id: run-death-restart`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:run`, `area:combat`, `priority:P0`  
Parent: `run-foundation` — Game Foundation

把 Normal Mode 测试 Respawn 改成真正 Game Death；Creative 保留测试友好行为。

**Blocked by**

- `run-manager-state` — GameManager and Game State

**Definition of Done**

- [ ] HP<=0 后禁用 Gameplay 输入
- [ ] 进入 PLAYER_DEAD
- [ ] 有 Restart/Quit 流程
- [ ] Restart 创建新 Run
- [ ] Creative 测试流程不受破坏

#### Game Start, Death, Victory and Summary UI

`id: run-ui-summary`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:run`, `area:ui`, `priority:P1`  
Parent: `run-foundation` — Game Foundation

提供 Game Start、Death、Restart、Victory/Transition 与简洁 Summary UI。

**Blocked by**

- `run-manager-state` — GameManager and Game State

**Definition of Done**

- [ ] 至少显示 Depth、Gold、Elapsed Time、Enemies Killed、Wands/Spells Collected
- [ ] 固定 UI 在 .tscn，脚本只处理逻辑/绑定

#### Clean Session Reset

`id: session-reset`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:run`, `area:world`, `priority:P0`  
Parent: `run-foundation` — Game Foundation

保证 New Game 完整清理上一局 runtime 状态和对象生命周期。

**Blocked by**

- `run-manager-state` — GameManager and Game State

**Definition of Done**

- [ ] 重置 World seed/Chunks/Gold/Inventory/Wands/Status/Boss/Special Rooms
- [ ] 清理旧 Projectiles/Pickups/Enemies
- [ ] Creative 临时状态不泄漏到 Normal
- [ ] 重复 Restart 不产生悬挂引用/重复节点

### Wand Loot & Generation

`id: wand-loot-generation`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:wand`, `area:loot`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

建立随机 Wand 生成、世界 WandPickup、比较/替换与统一奖励接口。

**Blocked by**

- `run-manager-state` — GameManager and Game State

**Children**

- [ ] `runtime-wand-generator` — Runtime Wand Generator
- [ ] `deterministic-wand-generation` — Deterministic Wand Generation
- [ ] `world-wand-pickup` — World Wand Pickup
- [ ] `wand-comparison-ui` — Wand Comparison UI
- [ ] `wand-reward-api` — Unified Wand Reward API

**Definition of Done**

- [ ] 世界中可自然发现随机 Wand
- [ ] Wand 可拾取/比较/替换
- [ ] 生成受 biome/depth/rarity 控制
- [ ] 同 Game seed 下可复现关键 Wand

#### Runtime Wand Generator

`id: runtime-wand-generator`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:wand`, `priority:P0`  
Parent: `wand-loot-generation` — Wand Loot & Generation

使用数据驱动 Generation Profile 生成 Runtime WandDef：stats、capacity、shuffle、spell pool、visual。

**Definition of Done**

- [ ] 输入支持 biome/depth/rarity/random source
- [ ] 只生成 runtime data
- [ ] 范围来自 Resource/Profile
- [ ] 支持 Common/Rare/Treasure/Shop/Boss profile

#### Deterministic Wand Generation

`id: deterministic-wand-generation`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:wand`, `area:run`, `priority:P1`  
Parent: `wand-loot-generation` — Wand Loot & Generation

让 Wand 生成与 Game seed / loot id 建立稳定关系。

**Blocked by**

- `run-manager-state` — GameManager and Game State
- `runtime-wand-generator` — Runtime Wand Generator

**Definition of Done**

- [ ] 同 seed + loot id 生成相同 Wand
- [ ] 不依赖帧时序/全局随机状态
- [ ] 可记录重现信息

#### World Wand Pickup

`id: world-wand-pickup`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:wand`, `area:loot`, `priority:P0`  
Parent: `wand-loot-generation` — Wand Loot & Generation

新增持有 Runtime WandDef 的世界 WandPickup，并显示一致 visual。

**Blocked by**

- `runtime-wand-generator` — Runtime Wand Generator

**Definition of Done**

- [ ] 空 Wand Slot 可直接拾取
- [ ] 满槽进入比较/替换
- [ ] Pickup 生命周期与 Streaming/删除安全

#### Wand Comparison UI

`id: wand-comparison-ui`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:wand`, `area:ui`, `priority:P0`  
Parent: `wand-loot-generation` — Wand Loot & Generation

比较当前 Wand 与发现 Wand 的 stats/spells，并允许 Swap / Leave。

**Blocked by**

- `world-wand-pickup` — World Wand Pickup

**Definition of Done**

- [ ] 复用 WandGlyph/SpellSlot/Wand stats
- [ ] 显示核心属性差异
- [ ] 固定 UI 在 .tscn
- [ ] Swap 不破坏 runtime ownership

#### Unified Wand Reward API

`id: wand-reward-api`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:wand`, `area:loot`, `priority:P1`  
Parent: `wand-loot-generation` — Wand Loot & Generation

建立 Chest/Shop/Boss/World Spawn 共用的 Wand 奖励入口。

**Blocked by**

- `runtime-wand-generator` — Runtime Wand Generator

**Definition of Done**

- [ ] 可按 profile/depth/rarity 请求 Wand
- [ ] 调用方不需知道生成细节
- [ ] 支持 deterministic random source

### Mine Enemy Set

`id: mine-enemy-set`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:enemy`, `area:combat`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

完成 Mine 第一套正式敌人生态，并建立数据驱动 Encounter 与 Spawn Anchor。

**Children**

- [ ] `enemy-architecture` — Unified Enemy Architecture
- [ ] `cave-eye-production` — Cave Eye Production Pass
- [ ] `crawler-enemy` — Crawler
- [ ] `bomber-enemy` — Bomber
- [ ] `fire-slime` — Fire Slime
- [ ] `oil-slime` — Oil Slime
- [ ] `enemy-loot-tables` — Enemy Loot Tables
- [ ] `encounter-spawner` — Encounter Spawner and Difficulty Budget
- [ ] `piece-spawn-anchors` — Piece Spawn Anchors

**Definition of Done**

- [ ] 至少 5 类正式敌人有明显战术差异
- [ ] 至少两类敌人主动改变像素环境
- [ ] Enemy loot 数据驱动
- [ ] 深度提升主要靠组合而非纯 HP 膨胀

#### Unified Enemy Architecture

`id: enemy-architecture`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:enemy`, `area:combat`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

统一 Health/Status/Faction/Loot/Environment/Brain 架构，减少敌人重复逻辑。

**Definition of Done**

- [ ] 公共 death/damage/status/loot 行为复用
- [ ] 差异主要放在 Brain/Movement/Attack/DeathEffect
- [ ] 不要求所有敌人共享单一大脚本

#### Cave Eye Production Pass

`id: cave-eye-production`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `priority:P1`  
Parent: `mine-enemy-set` — Mine Enemy Set

把 Cave Eye 从验证敌人整理为 Mine 正式基础远程飞行敌人。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture
- `enemy-loot-tables` — Enemy Loot Tables

**Definition of Done**

- [ ] 正式 Spawn profile
- [ ] 正式 LootTable
- [ ] Damage/Fire Rate/HP 可配置
- [ ] 保留 ranged flying 身份

#### Crawler

`id: crawler-enemy`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

地面近战追击敌人，用于验证动态地形中的局部移动与近战压力。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture

**Definition of Done**

- [ ] 能在常见 Mine 地形追击玩家
- [ ] 不依赖重型全局 A*
- [ ] 有近战/受击/死亡反馈
- [ ] 使用 ground anchor

#### Bomber

`id: bomber-enemy`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `area:material`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

远程爆炸敌人，使敌人正式拥有破坏地形的能力。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture

**Definition of Done**

- [ ] 投射爆炸物攻击
- [ ] 爆炸走正式 WorldGameplayService/Native terrain path
- [ ] 能改变可破坏地形
- [ ] 限制高频地形破坏

#### Fire Slime

`id: fire-slime`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `area:material`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

与 Burning/Fire Material 交互的环境型敌人。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture

**Definition of Done**

- [ ] 攻击或死亡至少一种行为产生真实 Fire
- [ ] 与 Oiled/Burning 状态系统互动
- [ ] 不是普通敌人换色

#### Oil Slime

`id: oil-slime`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `area:material`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

产生 Oil 的环境型敌人，与 Fire 敌人/Spell 形成组合危险。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture

**Definition of Done**

- [ ] 攻击或死亡产生真实 Oil
- [ ] Oil 使用正式 Material API
- [ ] 和 Fire 同场产生可观察系统互动

#### Enemy Loot Tables

`id: enemy-loot-tables`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:enemy`, `area:loot`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

将敌人掉落改为数据驱动 LootTable。

**Definition of Done**

- [ ] 支持 Gold/Health/rare Spell 等 entry
- [ ] 普通敌人 Spell Drop 默认很低
- [ ] LootTable 可复用
- [ ] 兼容 Game seed/random source

#### Encounter Spawner and Difficulty Budget

`id: encounter-spawner`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:world`, `area:enemy`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

按 biome/depth/piece metadata/spawn anchors/difficulty budget 生成敌人组合。

**Blocked by**

- `enemy-architecture` — Unified Enemy Architecture
- `piece-spawn-anchors` — Piece Spawn Anchors

**Definition of Done**

- [ ] 支持 deterministic random source
- [ ] 深度提升主要改变组合/预算
- [ ] 避免 enemy HP × depth
- [ ] 兼容 Streaming 生命周期
- [ ] Creative 可复现 encounter profile

#### Piece Spawn Anchors

`id: piece-spawn-anchors`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:world`, `area:enemy`, `priority:P0`  
Parent: `mine-enemy-set` — Mine Enemy Set

给 Piece/World content 提供 ground/air/ceiling/wall/guard Spawn Anchor/Tag。

**Definition of Done**

- [ ] Spawner 可按 tag 请求合法位置
- [ ] Anchor 数据属于 Piece/世界内容
- [ ] 不依赖运行时全地图随机找点

### Special Rooms & Economy

`id: special-rooms-economy`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:world`, `area:loot`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

把特殊地形转成 Gameplay Room，让 Gold/Wand/Spell 形成经济闭环。

**Blocked by**

- `wand-loot-generation` — Wand Loot & Generation
- `enemy-loot-tables` — Enemy Loot Tables

**Children**

- [ ] `chest-system` — Chest System
- [ ] `treasure-room` — Treasure Room Gameplay
- [ ] `run-modifiers` — Game Modifiers / Perks v1
- [ ] `shrine-system` — Shrine System
- [ ] `shop-system` — Shop System
- [ ] `gold-economy` — Gold Economy v1

**Definition of Done**

- [ ] Treasure/Shrine/Shop 都能自然出现
- [ ] Gold 可消费
- [ ] Room reward 能改变 Build

#### Chest System

`id: chest-system`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:loot`, `area:world`, `priority:P0`  
Parent: `special-rooms-economy` — Special Rooms & Economy

建立可复用 Chest：RewardProfile/LootTable、opened state、交互和视觉状态。

**Blocked by**

- `wand-reward-api` — Unified Wand Reward API

**Definition of Done**

- [ ] 可生成 Wand/Spell/Gold/Health
- [ ] opened state 不重复领奖
- [ ] 可被 Treasure/Boss/Secret Room 复用

#### Treasure Room Gameplay

`id: treasure-room`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:world`, `area:loot`, `priority:P0`  
Parent: `special-rooms-economy` — Special Rooms & Economy

把 Mine Treasure 特殊结构转成明确探索奖励空间。

**Blocked by**

- `chest-system` — Chest System

**Definition of Done**

- [ ] 至少一个高价值 Chest
- [ ] V5.0 阶段高概率或必定提供 Wand
- [ ] 由世界生成自然出现

#### Game Modifiers / Perks v1

`id: run-modifiers`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:run`, `priority:P1`  
Parent: `special-rooms-economy` — Special Rooms & Economy

建立仅当前 Game 生效的轻量 Modifier/Perk，为 Shrine 提供 Buff 表达。

**Definition of Done**

- [ ] Modifier 有 id/display/icon/apply 语义
- [ ] 支持 Max HP/Flight/Fire Resist/Explosion Resist/Move Speed
- [ ] 不引入永久 Meta Progression

#### Shrine System

`id: shrine-system`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:world`, `area:run`, `priority:P1`  
Parent: `special-rooms-economy` — Special Rooms & Economy

提供 Shrine 的 Game Buff 选择与应用。

**Blocked by**

- `run-modifiers` — Game Modifiers / Perks v1

**Definition of Done**

- [ ] 玩家从有限候选中获得一个 Game Modifier
- [ ] Buff 清晰显示且仅持续当前 Run
- [ ] 不直接硬改资源文件

#### Shop System

`id: shop-system`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:world`, `area:loot`, `area:wand`, `area:spell`, `priority:P1`  
Parent: `special-rooms-economy` — Special Rooms & Economy

第一版 Shop 出售 Spell、Wand 和 Heal，让 Gold 形成消费端。

**Blocked by**

- `wand-reward-api` — Unified Wand Reward API
- `gold-economy` — Gold Economy v1

**Definition of Done**

- [ ] 支持 Spell/Wand/Heal
- [ ] 价格数据驱动
- [ ] 正确扣 Gold
- [ ] 兼容 WandPickup/SpellDef

#### Gold Economy v1

`id: gold-economy`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:loot`, `priority:P1`  
Parent: `special-rooms-economy` — Special Rooms & Economy

确定敌人 Gold、Wand/Spell/Heal 价格与一局内基础消费节奏。

**Blocked by**

- `enemy-loot-tables` — Enemy Loot Tables

**Definition of Done**

- [ ] 普通 Game 至少有数次有意义消费选择
- [ ] Gold 不因过量掉落失去意义
- [ ] 价格/掉落数据可配置

### Mine Boss & Exit

`id: mine-boss-exit`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:combat`, `area:world`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

建立 Boss framework、Mine Boss、Arena、Major Reward 与 Game Exit/Victory。

**Blocked by**

- `run-foundation` — Game Foundation
- `mine-enemy-set` — Mine Enemy Set
- `wand-reward-api` — Unified Wand Reward API

**Children**

- [ ] `boss-framework` — Boss Framework
- [ ] `boss-arena` — Boss Arena Special Chunk
- [ ] `mine-boss` — Mine Boss
- [ ] `boss-major-reward` — Boss Major Reward
- [ ] `exit-victory` — Exit / Victory Flow

**Definition of Done**

- [ ] Boss 战完整可重复
- [ ] 至少一种攻击改变像素世界
- [ ] 击败后产生重大奖励
- [ ] 可进入 Exit/Victory

#### Boss Framework

`id: boss-framework`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:tech`, `area:combat`, `area:enemy`, `priority:P0`  
Parent: `mine-boss-exit` — Mine Boss & Exit

建立 Boss HP、Phase、Attack State、Death、Boss HUD 与 Arena 协作基础。

**Blocked by**

- `run-manager-state` — GameManager and Game State
- `enemy-architecture` — Unified Enemy Architecture

**Definition of Done**

- [ ] 支持多 Phase
- [ ] Boss HUD 数据/逻辑分离
- [ ] 不强行复用普通敌人大脚本
- [ ] 死亡事件能驱动 Reward/Exit

#### Boss Arena Special Chunk

`id: boss-arena`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:world`, `priority:P0`  
Parent: `mine-boss-exit` — Mine Boss & Exit

建立 Mine Boss Arena 的世界结构、入口、Boss spawn 与胜利后 Exit activation。

**Blocked by**

- `boss-framework` — Boss Framework

**Definition of Done**

- [ ] Arena 稳定生成
- [ ] Boss 正确生成一次
- [ ] 兼容 Streaming 生命周期
- [ ] 胜利后出口状态正确

#### Mine Boss

`id: mine-boss`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:content`, `area:enemy`, `area:combat`, `area:material`, `priority:P0`  
Parent: `mine-boss-exit` — Mine Boss & Exit

实现第一只正式 Mine Boss，核心机制至少一项操纵像素环境。

**Blocked by**

- `boss-framework` — Boss Framework
- `boss-arena` — Boss Arena Special Chunk

**Definition of Done**

- [ ] 至少两个明显战斗阶段/攻击状态
- [ ] 至少一种攻击生成/破坏/改变 Material
- [ ] 不是纯 HP sponge
- [ ] 死亡与胜利反馈清晰

#### Boss Major Reward

`id: boss-major-reward`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:loot`, `area:wand`, `priority:P1`  
Parent: `mine-boss-exit` — Mine Boss & Exit

Boss 死亡后提供明显高于普通 Encounter 的重大 Game 奖励。

**Blocked by**

- `wand-reward-api` — Unified Wand Reward API
- `mine-boss` — Mine Boss

**Definition of Done**

- [ ] 支持 Rare Wand / Rare Spell / Game Modifier 至少一种
- [ ] Reward profile 可配置
- [ ] 奖励领取状态可靠

#### Exit / Victory Flow

`id: exit-victory`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:run`, `area:world`, `area:ui`, `priority:P0`  
Parent: `mine-boss-exit` — Mine Boss & Exit

Boss 完成后激活 Portal/Exit，并进入 TRANSITION 或 V5.0 Victory。

**Blocked by**

- `run-manager-state` — GameManager and Game State
- `mine-boss` — Mine Boss

**Definition of Done**

- [ ] Exit 只在条件满足后激活
- [ ] 进入后切换 RunState
- [ ] V5.0 可直接 Victory，不被 Snow 阻塞
- [ ] 未来可扩 Mine→Snow

### Alpha Balance Pass

`id: alpha-balance-pass`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:epic`, `area:combat`, `priority:P0`  
Parent: `first-playable-run` — First Playable Game

完整 Game 可玩后做第一轮数值、掉落、难度与战斗反馈收敛。

**Blocked by**

- `run-foundation` — Game Foundation
- `wand-loot-generation` — Wand Loot & Generation
- `mine-enemy-set` — Mine Enemy Set
- `special-rooms-economy` — Special Rooms & Economy
- `mine-boss-exit` — Mine Boss & Exit

**Children**

- [ ] `player-balance` — Player Survivability Balance
- [ ] `enemy-balance` — Enemy Composition and Damage Balance
- [ ] `wand-generation-balance` — Wand Generation Balance
- [ ] `loot-economy-balance` — Loot and Economy Balance
- [ ] `spell-baseline` — Core Spell Baseline
- [ ] `combat-feedback` — Combat Feedback Pass

**Definition of Done**

- [ ] 完整 Game 难度曲线可接受
- [ ] 有数次构筑/消费决策
- [ ] 基础 Spell 各有用途
- [ ] Boss 前后成长可感知

#### Player Survivability Balance

`id: player-balance`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:combat`, `priority:P0`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

调整 HP、Damage、Flight、Movement、Healing。

**Blocked by**

- `mine-boss` — Mine Boss

**Definition of Done**

- [ ] 基础敌人不瞬间秒杀新玩家
- [ ] 恢复资源不无限
- [ ] Flight/Movement 不破坏主要关卡约束

#### Enemy Composition and Damage Balance

`id: enemy-balance`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:enemy`, `priority:P0`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

调整 Enemy density、budget、attack rate、damage 与组合。

**Blocked by**

- `encounter-spawner` — Encounter Spawner and Difficulty Budget
- `mine-boss` — Mine Boss

**Definition of Done**

- [ ] 深度提升可感知且不依赖数值膨胀
- [ ] 组合形成战术变化
- [ ] 性能压力处于目标范围

#### Wand Generation Balance

`id: wand-generation-balance`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:wand`, `priority:P0`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

调整 capacity、mana、recharge、shuffle chance、spell quality 与 rarity progression。

**Blocked by**

- `runtime-wand-generator` — Runtime Wand Generator
- `world-wand-pickup` — World Wand Pickup

**Definition of Done**

- [ ] 早期 Wand 不轻易压倒所有内容
- [ ] 深度/稀有度有真实提升
- [ ] Bad roll 与 OP roll 有边界

#### Loot and Economy Balance

`id: loot-economy-balance`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:loot`, `priority:P0`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

统一 Gold、Wand、Spell、Chest、Shop 的奖励节奏。

**Blocked by**

- `gold-economy` — Gold Economy v1
- `treasure-room` — Treasure Room Gameplay
- `shop-system` — Shop System

**Definition of Done**

- [ ] 探索和战斗都有意义奖励
- [ ] 普通敌人不会淹没世界于 Spell Pickup
- [ ] Treasure/Shop/Boss 层级清晰

#### Core Spell Baseline

`id: spell-baseline`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:balance`, `area:spell`, `priority:P1`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

确保 Spark/Dig/Fire/Bomb 等基础 Spell 有明确 Combat/Dig/Environment 定位。

**Blocked by**

- `basic-dig-resistance` — Basic Dig Power and Terrain Hardness

**Definition of Done**

- [ ] 不只是 damage 数字不同
- [ ] 至少 Combat/Dig/Environment 三种用途明确
- [ ] Mana/Delay/Damage 在 Wand 生成范围内可用

#### Combat Feedback Pass

`id: combat-feedback`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:combat`, `area:ui`, `priority:P1`  
Parent: `alpha-balance-pass` — Alpha Balance Pass

补齐 hit/death/damage feedback，达到 Alpha 可玩标准。

**Blocked by**

- `mine-enemy-set` — Mine Enemy Set

**Definition of Done**

- [ ] 命中/受伤/死亡反馈可读
- [ ] 不依赖高成本后处理
- [ ] 保持像素视觉语言

### Basic Dig Power and Terrain Hardness

`id: basic-dig-resistance`

Milestone: **V5.0 — First Playable Game**  
Labels: `type:feature`, `area:material`, `area:spell`, `priority:P1`  
Parent: `first-playable-run` — First Playable Game

提供 V5.0 最小挖掘强度/地形硬度，避免低级 Spell 无成本穿透所有结构。

**Definition of Done**

- [ ] 区分普通可挖和高硬度/不可轻易挖材质
- [ ] Dig/Bomb 等 Spell 有基本 dig_power
- [ ] 不要求完整 hardness hierarchy

**Non-goals**

- 复杂部分破坏
- 完整 resistance matrix
- 电导/湿润耦合

## 7. V5.0 关键依赖

```text
Game Foundation
      │
      ├──────────────┐
      ↓              ↓
Wand Loot        Mine Enemy Set
      │              │
      └──────┬───────┘
             ↓
 Special Rooms & Economy
             │
             ↓
     Mine Boss & Exit
             │
             ↓
     Alpha Balance Pass
```

`Basic Dig Power and Terrain Hardness` 是横向 P1：不阻塞 Game Foundation/Wand Loot 的起步，但应在最终 Alpha Balance 前完成。

### V5.0 并行策略

- **第一并行组**：Game Foundation + Runtime Wand Generator + Enemy Architecture。
- **第二并行组**：WandPickup/Compare + Enemy concrete content + Piece Spawn Anchors。
- **第三并行组**：Encounter + Chest/Treasure/Gold Economy。
- **第四并行组**：Shrine/Shop + Boss Framework/Arena。
- **最后收敛**：Mine Boss → Exit/Victory → Alpha Balance。

## 8. V5.1+ 远期内容

### Wand & Material Gameplay

`id: wand-material-gameplay`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:epic`, `area:wand`, `area:material`, `priority:P1`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

在 First Playable Game 成立后深化 Wand 构筑和 Material Gameplay。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `wand-system-expansion` — Wand System Expansion
- [ ] `material-gameplay-expansion` — Material Gameplay Expansion

**Definition of Done**

- [ ] 支持嵌套/延迟/条件 Cast
- [ ] 地形硬度与导电/湿润交互进入正式 Gameplay

#### Wand System Expansion

`id: wand-system-expansion`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:epic`, `area:wand`, `area:spell`, `priority:P1`  
Parent: `wand-material-gameplay` — Wand & Material Gameplay

扩展真正影响 Cast Graph 的高级 Wand/Spell 机制。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `trigger-cast-architecture` — Trigger Cast Architecture
- [ ] `trigger-spells` — Trigger Spells
- [ ] `timer-spells` — Timer Spells
- [ ] `conditional-casts` — Conditional Casts
- [ ] `homing-modifier` — Homing Modifier
- [ ] `orbit-modifier` — Orbit Modifier
- [ ] `trail-modifier` — Trail Modifier

##### Trigger Cast Architecture

`id: trigger-cast-architecture`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:tech`, `area:wand`, `area:spell`, `priority:P1`  
Parent: `wand-system-expansion` — Wand System Expansion

扩展 SpellCastState/CastContext 支持 impact/death 等事件触发嵌套 cast。

##### Trigger Spells

`id: trigger-spells`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `priority:P1`  
Parent: `wand-system-expansion` — Wand System Expansion

实现 On Hit / Trigger 类 Spell。

**Blocked by**

- `trigger-cast-architecture` — Trigger Cast Architecture

##### Timer Spells

`id: timer-spells`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `priority:P1`  
Parent: `wand-system-expansion` — Wand System Expansion

实现延迟后触发后续 Cast 的 Timer Spell。

**Blocked by**

- `trigger-cast-architecture` — Trigger Cast Architecture

##### Conditional Casts

`id: conditional-casts`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `priority:P2`  
Parent: `wand-system-expansion` — Wand System Expansion

实现基于命中、状态或环境条件的后续 Cast。

**Blocked by**

- `trigger-cast-architecture` — Trigger Cast Architecture

##### Homing Modifier

`id: homing-modifier`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `priority:P2`  
Parent: `wand-system-expansion` — Wand System Expansion

增加 Homing projectile modifier。

##### Orbit Modifier

`id: orbit-modifier`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `priority:P2`  
Parent: `wand-system-expansion` — Wand System Expansion

增加 Orbit cast/projectile modifier。

##### Trail Modifier

`id: trail-modifier`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:spell`, `area:material`, `priority:P2`  
Parent: `wand-system-expansion` — Wand System Expansion

增加 Trail modifier，并允许受控 Material/VFX trail。

#### Material Gameplay Expansion

`id: material-gameplay-expansion`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:epic`, `area:material`, `priority:P1`  
Parent: `wand-material-gameplay` — Wand & Material Gameplay

把 Sand Material 从模拟底座进一步提升为正式战斗/探索规则。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `material-gameplay-metadata` — Material Gameplay Metadata
- [ ] `full-dig-hardness` — Full Dig Power and Hardness
- [ ] `conductivity-system` — Material Conductivity
- [ ] `wet-electricity` — Wet and Electricity Interaction
- [ ] `advanced-material-reactions` — Advanced Material Reactions

##### Material Gameplay Metadata

`id: material-gameplay-metadata`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:tech`, `area:material`, `priority:P1`  
Parent: `material-gameplay-expansion` — Material Gameplay Expansion

统一 hardness/contact damage/flammability/conductivity/toxicity 等 Gameplay metadata。

##### Full Dig Power and Hardness

`id: full-dig-hardness`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:material`, `area:spell`, `priority:P1`  
Parent: `material-gameplay-expansion` — Material Gameplay Expansion

在 V5.0 基础版上建立完整 hardness hierarchy、Spell digging profile 和特殊材质 resistance。

**Blocked by**

- `basic-dig-resistance` — Basic Dig Power and Terrain Hardness
- `material-gameplay-metadata` — Material Gameplay Metadata

##### Material Conductivity

`id: conductivity-system`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:material`, `priority:P1`  
Parent: `material-gameplay-expansion` — Material Gameplay Expansion

让 Water/Metal 等材质具备统一 conductivity 规则。

**Blocked by**

- `material-gameplay-metadata` — Material Gameplay Metadata

##### Wet and Electricity Interaction

`id: wet-electricity`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:material`, `area:combat`, `area:spell`, `priority:P1`  
Parent: `material-gameplay-expansion` — Material Gameplay Expansion

Lightning 与 Water/Wet actor 产生系统性导电/伤害互动。

**Blocked by**

- `conductivity-system` — Material Conductivity

##### Advanced Material Reactions

`id: advanced-material-reactions`

Milestone: **V5.1 — Wand & Material Gameplay**  
Labels: `type:feature`, `area:material`, `priority:P2`  
Parent: `material-gameplay-expansion` — Material Gameplay Expansion

扩展 Fire/Oil/Water/Acid/Crystal 等更深入 Gameplay reaction。

**Blocked by**

- `material-gameplay-metadata` — Material Gameplay Metadata

### Snow Biome Gameplay

`id: snow-biome-gameplay`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:epic`, `area:world`, `priority:P1`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

把 Snow 做到与 Mine 同等级的完整 Gameplay Biome。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `snow-enemy-set` — Snow Enemy Set
- [ ] `snow-encounters` — Snow Encounter Profile
- [ ] `snow-hazards` — Snow Environmental Hazards
- [ ] `snow-loot-profile` — Snow Loot Profile
- [ ] `snow-special-rooms` — Snow Special Rooms
- [ ] `snow-boss` — Snow Boss
- [ ] `mine-snow-progression` — Mine to Snow Progression

**Definition of Done**

- [ ] Snow 有独立敌人/Encounter/危险/奖励/Boss
- [ ] 不是 Mine 内容换色
- [ ] Mine→Snow Progression 成立

#### Snow Enemy Set

`id: snow-enemy-set`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:epic`, `area:enemy`, `area:world`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

设计并实现 Snow 正式敌人生态。

#### Snow Encounter Profile

`id: snow-encounters`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:feature`, `area:enemy`, `area:world`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

建立 Snow difficulty budget 与 encounter composition。

**Blocked by**

- `snow-enemy-set` — Snow Enemy Set

#### Snow Environmental Hazards

`id: snow-hazards`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:content`, `area:material`, `area:world`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

建立 Snow 独特环境危险与 Material interaction。

#### Snow Loot Profile

`id: snow-loot-profile`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:feature`, `area:loot`, `area:wand`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

定义 Snow depth/rarity 对 Wand/Spell/Loot 的影响。

#### Snow Special Rooms

`id: snow-special-rooms`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:content`, `area:world`, `area:loot`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

实现 Snow Treasure/Shrine/Shop variation。

#### Snow Boss

`id: snow-boss`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:content`, `area:enemy`, `area:combat`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

实现 Snow Boss 与 Arena。

#### Mine to Snow Progression

`id: mine-snow-progression`

Milestone: **V5.2 — Snow Biome Gameplay**  
Labels: `type:feature`, `area:run`, `area:world`, `priority:P1`  
Parent: `snow-biome-gameplay` — Snow Biome Gameplay

把 V5.0 Exit 从 Victory 扩展为 Mine→Snow Transition。

**Blocked by**

- `snow-boss` — Snow Boss

### Creative Developer Toolkit

`id: creative-developer-toolkit`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:epic`, `area:creative`, `priority:P2`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

把 Creative Mode 提升为可快速搭建、复现和保存 Gameplay 测试场景的开发工具。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `scenario-presets` — Scenario Presets
- [ ] `wand-presets` — Creative Wand Presets
- [ ] `entity-spawn-sets` — Entity Spawn Sets
- [ ] `simulation-debugging` — Simulation Debugging Tools
- [ ] `terrain-editing-history` — Terrain Editing History

#### Scenario Presets

`id: scenario-presets`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `priority:P1`  
Parent: `creative-developer-toolkit` — Creative Developer Toolkit

提供 Fire/Oil、Water/Electricity、Enemy Composition、Wand DPS、Boss Arena 等一键测试场景。

#### Creative Wand Presets

`id: wand-presets`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `area:wand`, `priority:P2`  
Parent: `creative-developer-toolkit` — Creative Developer Toolkit

保存/加载可复现测试 Wand。

#### Entity Spawn Sets

`id: entity-spawn-sets`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `area:enemy`, `priority:P2`  
Parent: `creative-developer-toolkit` — Creative Developer Toolkit

一次生成 encounter profile / enemy group / loot scenario。

#### Simulation Debugging Tools

`id: simulation-debugging`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `area:native`, `priority:P2`  
Parent: `creative-developer-toolkit` — Creative Developer Toolkit

扩展 active-block/material inspector/simulation visualization 等工具。

#### Terrain Editing History

`id: terrain-editing-history`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:epic`, `area:creative`, `area:native`, `priority:P2`  
Parent: `creative-developer-toolkit` — Creative Developer Toolkit

在 Native snapshot/restore 基础上实现高性能 Terrain Undo/Redo 与 World Snapshot。

**Children**

- [ ] `native-region-snapshot` — Native Region Snapshot
- [ ] `native-region-restore` — Native Region Restore
- [ ] `terrain-edit-command` — Terrain Edit Command Model
- [ ] `terrain-undo-redo` — Creative Terrain Undo and Redo
- [ ] `world-snapshot` — Creative World Snapshot

##### Native Region Snapshot

`id: native-region-snapshot`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:tech`, `area:native`, `priority:P1`  
Parent: `terrain-editing-history` — Terrain Editing History

为 fallingsand 增加批量 capture_region，避免 GDScript 逐像素读取。

##### Native Region Restore

`id: native-region-restore`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:tech`, `area:native`, `priority:P1`  
Parent: `terrain-editing-history` — Terrain Editing History

为 fallingsand 增加批量 restore_region，并正确传播 simulation/visual/collision dirty。

**Blocked by**

- `native-region-snapshot` — Native Region Snapshot

##### Terrain Edit Command Model

`id: terrain-edit-command`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:tech`, `area:creative`, `priority:P2`  
Parent: `terrain-editing-history` — Terrain Editing History

用 region + before/after snapshot 表达一次编辑命令，并设置内存预算。

**Blocked by**

- `native-region-restore` — Native Region Restore

##### Creative Terrain Undo and Redo

`id: terrain-undo-redo`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `priority:P2`  
Parent: `terrain-editing-history` — Terrain Editing History

实现 Ctrl+Z / Ctrl+Y、跨 Chunk restore 和历史栈预算。

**Blocked by**

- `terrain-edit-command` — Terrain Edit Command Model

##### Creative World Snapshot

`id: world-snapshot`

Milestone: **V5.3 — Creative Developer Toolkit**  
Labels: `type:feature`, `area:creative`, `area:world`, `priority:P3`  
Parent: `terrain-editing-history` — Terrain Editing History

保存/恢复用于开发测试的有限世界区域快照。

**Blocked by**

- `native-region-restore` — Native Region Restore

### Engine & Platform Hardening

`id: engine-platform-hardening`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:epic`, `area:native`, `area:platform`, `priority:P2`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

在 Gameplay 主循环稳定后系统做性能、长期稳定性和平台覆盖。

**Blocked by**

- `first-playable-run` — First Playable Game

**Children**

- [ ] `engine-performance-hardening` — Engine Performance Hardening
- [ ] `platform-coverage` — Platform Coverage

#### Engine Performance Hardening

`id: engine-performance-hardening`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:epic`, `area:native`, `area:world`, `priority:P2`  
Parent: `engine-platform-hardening` — Engine & Platform Hardening

集中处理 Ghost Halo、Sector/Streaming/Native Sand、内存和长期运行性能。

**Children**

- [ ] `ghost-halo` — Ghost Halo
- [ ] `visual-sector-profiling` — Visual Sector Profiling
- [ ] `collision-sector-profiling` — Collision Sector Profiling
- [ ] `streaming-profiling` — Streaming Profiling
- [ ] `native-sand-profiling` — Native Sand Profiling
- [ ] `memory-longrun-stability` — Memory and Long-run Stability

##### Ghost Halo

`id: ghost-halo`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:native`, `area:world`, `priority:P3`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

评估并实现跨 Chunk ghost halo / seam 优化。

##### Visual Sector Profiling

`id: visual-sector-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:world`, `priority:P2`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

系统 profiling Visual Sector partial updates 与 GPU copy path。

##### Collision Sector Profiling

`id: collision-sector-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:world`, `priority:P2`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

系统 profiling 动态 Collision Sector rebuild。

##### Streaming Profiling

`id: streaming-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:world`, `priority:P2`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

分析 Streaming worker、Chunk 生命周期和卡顿峰值。

##### Native Sand Profiling

`id: native-sand-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:native`, `priority:P2`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

分析 fallingsand step、active blocks、跨 Chunk flow 等热点。

##### Memory and Long-run Stability

`id: memory-longrun-stability`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:native`, `area:world`, `priority:P2`  
Parent: `engine-performance-hardening` — Engine Performance Hardening

进行长时间 Game 的内存增长、资源生命周期与稳定性测试。

#### Platform Coverage

`id: platform-coverage`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:epic`, `area:platform`, `priority:P2`  
Parent: `engine-platform-hardening` — Engine & Platform Hardening

补齐 Native binary 与真实设备 profiling。

**Children**

- [ ] `linux-native-binary` — Linux Native Binary
- [ ] `macos-native-binary` — macOS Native Binary
- [ ] `android-platform-coverage` — Android Platform Coverage
- [ ] `web-platform-profiling` — Web Platform Profiling
- [ ] `mobile-hardware-profiling` — Mobile Hardware Profiling
- [ ] `desktop-hardware-profiling` — Desktop Hardware Profiling
- [ ] `runtime-profile-tuning` — Runtime Profile Tuning

##### Linux Native Binary

`id: linux-native-binary`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `area:native`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

补齐 Linux fallingsand native build / validation。

##### macOS Native Binary

`id: macos-native-binary`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `area:native`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

补齐 macOS fallingsand native build / validation。

##### Android Platform Coverage

`id: android-platform-coverage`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

评估 Android ABI 覆盖与真实设备兼容。

##### Web Platform Profiling

`id: web-platform-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

验证 Web/WASM 下 Sand/Streaming/Gameplay 性能。

##### Mobile Hardware Profiling

`id: mobile-hardware-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

在真实移动设备验证 Runtime Profile。

##### Desktop Hardware Profiling

`id: desktop-hardware-profiling`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:tech`, `area:platform`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

在不同桌面硬件档位验证 CPU/GPU/内存表现。

##### Runtime Profile Tuning

`id: runtime-profile-tuning`

Milestone: **V5.4 — Engine & Platform Hardening**  
Labels: `type:balance`, `area:platform`, `area:world`, `priority:P2`  
Parent: `platform-coverage` — Platform Coverage

基于真实 profiling 调整 PC/Mobile Runtime Profile。

### World & Progression Expansion

`id: world-progression-expansion`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:epic`, `area:world`, `area:run`, `priority:P3`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

扩展多 Biome Run、Deep、Elite、Boss archetypes、Discovery 与特殊房间。

**Blocked by**

- `snow-biome-gameplay` — Snow Biome Gameplay

**Children**

- [ ] `deep-biome` — Deep Biome Gameplay
- [ ] `multi-biome-run` — Multi-biome Complete Run
- [ ] `elite-modifiers` — Elite Enemy Modifiers
- [ ] `boss-archetypes` — Additional Boss Archetypes
- [ ] `discovery-collection` — Discovery and Collection
- [ ] `expanded-special-rooms` — Expanded Special Rooms

#### Deep Biome Gameplay

`id: deep-biome`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:epic`, `area:world`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

把 Deep 做成完整 Gameplay Biome。

#### Multi-biome Complete Run

`id: multi-biome-run`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:feature`, `area:run`, `area:world`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

形成跨多个完整 Biome 的正式长 Game。

#### Elite Enemy Modifiers

`id: elite-modifiers`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:feature`, `area:enemy`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

增加 Burning/Shielded/Fast/Explosive/Regenerating 等 Elite modifier。

#### Additional Boss Archetypes

`id: boss-archetypes`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:content`, `area:enemy`, `area:combat`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

扩展更多利用 Material/世界规则的 Boss archetype。

#### Discovery and Collection

`id: discovery-collection`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:feature`, `area:run`, `area:ui`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

记录 Spell/Enemy/Biome discovery，不直接提供永久数值成长。

#### Expanded Special Rooms

`id: expanded-special-rooms`

Milestone: **V6.0 — World & Progression Expansion**  
Labels: `type:content`, `area:world`, `area:loot`, `priority:P3`  
Parent: `world-progression-expansion` — World & Progression Expansion

增加更多复杂特殊房间和选择事件。

### Meta Progression

`id: meta-progression`

Milestone: **V6.1 — Meta Progression**  
Labels: `type:epic`, `area:run`, `priority:P3`  
Parent: `roadmap-alpha` — Gameplay Alpha Roadmap

仅在确认基础 Game 本身足够好玩后评估局外成长；当前保持 tentative。

**Blocked by**

- `world-progression-expansion` — World & Progression Expansion

**Children**

- [ ] `meta-progression-framework` — Meta Progression Framework
- [ ] `persistent-unlocks` — Persistent Unlocks
- [ ] `meta-balance-guard` — Meta Progression Balance Guard

**Non-goals**

- 用永久 +HP/+Damage 掩盖基础 Game 平衡问题

#### Meta Progression Framework

`id: meta-progression-framework`

Milestone: **V6.1 — Meta Progression**  
Labels: `type:tech`, `area:run`, `priority:P3`  
Parent: `meta-progression` — Meta Progression

建立可撤销/可配置的局外成长框架。

#### Persistent Unlocks

`id: persistent-unlocks`

Milestone: **V6.1 — Meta Progression**  
Labels: `type:feature`, `area:run`, `priority:P3`  
Parent: `meta-progression` — Meta Progression

评估并实现非破坏性 Unlock/Discovery progression。

#### Meta Progression Balance Guard

`id: meta-balance-guard`

Milestone: **V6.1 — Meta Progression**  
Labels: `type:balance`, `area:run`, `priority:P3`  
Parent: `meta-progression` — Meta Progression

确保局外成长不替代核心 Wand/Environment skill progression。

## 9. 推荐的第一次 GitHub 创建批次

虽然 Manifest 定义了 105 个 Issue 节点，但**第一次真正创建时只建议建立骨架**：

1. Labels（Type / Area / Priority）。
2. Milestones：先创建 V5.0–V5.4；V6.x 可以继续只存在于 Manifest。
3. `Gameplay Alpha Roadmap`。
4. `First Playable Game`。
5. `Game Foundation`。
6. `Wand Loot & Generation`。
7. `Mine Enemy Set`。
8. `Special Rooms & Economy`。
9. `Mine Boss & Exit`。
10. `Alpha Balance Pass`。
11. `Basic Dig Power and Terrain Hardness`。

然后只进一步创建下一轮真正要开发的 concrete tasks：

- `GameManager and Game State`
- `Game Death and Restart Flow`
- `Game Start, Death, Victory and Summary UI`
- `Clean Session Reset`
- `Runtime Wand Generator`
- `Deterministic Wand Generation`
- `World Wand Pickup`
- `Wand Comparison UI`
- `Unified Wand Reward API`

这样 GitHub 里不会一开始就堆满 100 个长期 Open Issue，但路线也不会丢。

## 10. 创建后的父子关系策略

真正创建后，用 GitHub Sub-issues / Tasklist 表达父子关系；YAML 中的稳定 `id` 会映射到 GitHub issue number。建议额外生成一个本地映射：

```yaml
roadmap-alpha: 120
first-playable-run: 121
run-foundation: 122
run-manager-state: 130
```

后续更新 Manifest 时始终使用稳定 `id`，避免 Issue number 或标题变化影响依赖表达。

## 11. 统一 Issue Body 模板

```markdown
## 目标
为什么需要这个任务。

## 玩家体验 / 开发体验
完成后玩家或开发者实际获得什么。

## 技术范围
涉及哪些现有系统、资源与接口。

## 不包含
明确本 Issue 不处理的内容。

## 子任务
- [ ] ...

## 验收标准
- [ ] ...

## 依赖
Blocked by: ...
Blocks: ...

## 测试重点
- [ ] Runtime
- [ ] 生命周期 / Streaming
- [ ] UI / 输入（如适用）

## 性能约束
如果涉及 Sand / Streaming / Projectile / UI rebuild，明确预算并禁止低性能旁路。
```

## 12. 数量与完整性

- Label 定义：**23**
- Milestone 定义：**7**
- Issue 定义：**105**
- V5.0 Issue 定义：**43**
- 所有 `parent`、`children`、`blocked_by` 引用已做一致性检查。
- V6.1 明确标记为 `tentative`，不应在基础 Game 未验证前自动推进。

完整机器可读结构请参见 `GITHUB_ROADMAP_MANIFEST.yaml`。