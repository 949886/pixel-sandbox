# GitHub Roadmap Manifest

> 本文件与 `GITHUB_ROADMAP_MANIFEST.yaml` 是项目 Roadmap 的版本化 source of truth。GitHub Issue / Milestone / Label 为执行视图；Manifest 负责保留长期结构与尚未创建的远期任务。

## 术语约定

- 一局游戏统一称为 **Game**，不再使用 Gameplay 语义的 `Run`。
- 核心管理类使用 `GameManager`，状态使用 `GameState`，随机种子使用 `Game seed`。
- 原 `area:run` 统一归入现有 `area:gameplay`。
- `Runtime` 与 `Long-run Stability` 是独立技术术语，保持原名。

## GitHub 管理规则

- Issue 标题保持纯任务名称，不包含版本号、类型或优先级前缀。
- 版本号只由 Milestone 表达。
- Type / Area / Priority 只由 Labels 表达。
- Issue 最深建议 4 层：Roadmap → Theme/Version Epic → System Epic → Concrete Task。
- 更细实现步骤留在具体 Issue checkbox，不继续无限拆 Issue。
- V5.0 Scope Guard：不能明显改善 `New Game → Explore → Fight → Loot → Build Wand → Special Room → Boss → End` 的工作，默认不属于 V5.0 blocker。

## 当前 GitHub 映射

- #1 — **GameManager and Game State** (`game-manager-state`)
- #2 — **Game Death and Restart Flow** (`game-death-restart`)
- #3 — **Game Start, Death, Victory and Summary UI** (`game-ui-summary`)
- #4 — **Clean Session Reset** (`session-reset`)
- #5 — **Game Foundation** (`game-foundation`)
- #6 — **Runtime Wand Generator** (`runtime-wand-generator`)
- #7 — **Deterministic Wand Generation** (`deterministic-wand-generation`)
- #8 — **World Wand Pickup** (`world-wand-pickup`)
- #9 — **Wand Comparison UI** (`wand-comparison-ui`)
- #10 — **Unified Wand Reward API** (`wand-reward-api`)
- #11 — **Wand Loot & Generation** (`wand-loot-generation`)
- #12 — **Mine Enemy Set** (`mine-enemy-set`)
- #13 — **Special Rooms & Economy** (`special-rooms-economy`)
- #14 — **Mine Boss & Exit** (`mine-boss-exit`)
- #15 — **Alpha Balance Pass** (`alpha-balance-pass`)
- #16 — **Basic Dig Power and Terrain Hardness** (`basic-dig-resistance`)
- #17 — **First Playable Game** (`first-playable-game`)
- #18 — **Wand & Material Gameplay** (`wand-material-gameplay`)
- #19 — **Snow Biome Gameplay** (`snow-biome-gameplay`)
- #20 — **Creative Developer Toolkit** (`creative-developer-toolkit`)
- #21 — **Engine & Platform Hardening** (`engine-platform-hardening`)
- #22 — **World & Progression Expansion** (`world-progression-expansion`)
- #23 — **Meta Progression** (`meta-progression`)
- #24 — **Gameplay Alpha Roadmap** (`roadmap-alpha`)

## Milestones

### V5.0 — First Playable Game

- 状态：`current`
- 目标：完成第一条从 New Game 到 Mine Boss / Victory 的完整可玩 Game。

### V5.1 — Wand & Material Gameplay

- 状态：`planned`
- 目标：深化 Wand 构筑，并让 Spell 更系统地操纵像素环境。

### V5.2 — Snow Biome Gameplay

- 状态：`planned`
- 目标：把 Snow 做到与 Mine 同等级的第二个完整 Gameplay Biome。

### V5.3 — Creative Developer Toolkit

- 状态：`planned`
- 目标：把 Creative Mode 提升为高效率 Gameplay 开发与复现工具。

### V5.4 — Engine & Platform Hardening

- 状态：`planned`
- 目标：在 Gameplay Loop 稳定后系统处理性能、稳定性和平台覆盖。

### V6.0 — World & Progression Expansion

- 状态：`future`
- 目标：扩展 Deep、多 Biome Game、Elite、更多 Boss 与世界进度。

### V6.1 — Meta Progression

- 状态：`tentative`
- 目标：仅在基础 Game 已被证明好玩后评估局外成长。

## 总体 Issue Tree

```text
Gameplay Alpha Roadmap  (#24)
├── First Playable Game  (#17)
│   ├── Game Foundation  (#5)
│   │   ├── GameManager and Game State  (#1)
│   │   ├── Game Death and Restart Flow  (#2)
│   │   ├── Game Start, Death, Victory and Summary UI  (#3)
│   │   └── Clean Session Reset  (#4)
│   ├── Wand Loot & Generation  (#11)
│   │   ├── Runtime Wand Generator  (#6)
│   │   ├── Deterministic Wand Generation  (#7)
│   │   ├── World Wand Pickup  (#8)
│   │   ├── Wand Comparison UI  (#9)
│   │   └── Unified Wand Reward API  (#10)
│   ├── Mine Enemy Set  (#12)
│   │   ├── Unified Enemy Architecture
│   │   ├── Cave Eye Production Pass
│   │   ├── Crawler
│   │   ├── Bomber
│   │   ├── Fire Slime
│   │   ├── Oil Slime
│   │   ├── Enemy Loot Tables
│   │   ├── Encounter Spawner and Difficulty Budget
│   │   └── Piece Spawn Anchors
│   ├── Special Rooms & Economy  (#13)
│   │   ├── Chest System
│   │   ├── Treasure Room Gameplay
│   │   ├── Game Modifiers / Perks v1
│   │   ├── Shrine System
│   │   ├── Shop System
│   │   └── Gold Economy v1
│   ├── Mine Boss & Exit  (#14)
│   │   ├── Boss Framework
│   │   ├── Boss Arena Special Chunk
│   │   ├── Mine Boss
│   │   ├── Boss Major Reward
│   │   └── Exit / Victory Flow
│   ├── Alpha Balance Pass  (#15)
│   │   ├── Player Survivability Balance
│   │   ├── Enemy Composition and Damage Balance
│   │   ├── Wand Generation Balance
│   │   ├── Loot and Economy Balance
│   │   ├── Core Spell Baseline
│   │   └── Combat Feedback Pass
│   └── Basic Dig Power and Terrain Hardness  (#16)
├── Wand & Material Gameplay  (#18)
│   ├── Wand System Expansion
│   │   ├── Trigger Cast Architecture
│   │   ├── Trigger Spells
│   │   ├── Timer Spells
│   │   ├── Conditional Casts
│   │   ├── Homing Modifier
│   │   ├── Orbit Modifier
│   │   └── Trail Modifier
│   └── Material Gameplay Expansion
│       ├── Material Gameplay Metadata
│       ├── Full Dig Power and Hardness
│       ├── Material Conductivity
│       ├── Wet and Electricity Interaction
│       └── Advanced Material Reactions
├── Snow Biome Gameplay  (#19)
│   ├── Snow Enemy Set
│   ├── Snow Encounter Profile
│   ├── Snow Environmental Hazards
│   ├── Snow Loot Profile
│   ├── Snow Special Rooms
│   ├── Snow Boss
│   └── Mine to Snow Progression
├── Creative Developer Toolkit  (#20)
│   ├── Scenario Presets
│   ├── Creative Wand Presets
│   ├── Entity Spawn Sets
│   ├── Simulation Debugging Tools
│   └── Terrain Editing History
│       ├── Native Region Snapshot
│       ├── Native Region Restore
│       ├── Terrain Edit Command Model
│       ├── Creative Terrain Undo and Redo
│       └── Creative World Snapshot
├── Engine & Platform Hardening  (#21)
│   ├── Engine Performance Hardening
│   │   ├── Ghost Halo
│   │   ├── Visual Sector Profiling
│   │   ├── Collision Sector Profiling
│   │   ├── Streaming Profiling
│   │   ├── Native Sand Profiling
│   │   └── Memory and Long-run Stability
│   └── Platform Coverage
│       ├── Linux Native Binary
│       ├── macOS Native Binary
│       ├── Android Platform Coverage
│       ├── Web Platform Profiling
│       ├── Mobile Hardware Profiling
│       ├── Desktop Hardware Profiling
│       └── Runtime Profile Tuning
├── World & Progression Expansion  (#22)
│   ├── Deep Biome Gameplay
│   ├── Multi-biome Complete Game
│   ├── Elite Enemy Modifiers
│   ├── Additional Boss Archetypes
│   ├── Discovery and Collection
│   └── Expanded Special Rooms
└── Meta Progression  (#23)
    ├── Meta Progression Framework
    ├── Persistent Unlocks
    └── Meta Progression Balance Guard
```

## V5.0 — First Playable Game

V5.0 的唯一发布目标是让第一条 Mine 游戏流程从开始到结束完整成立：

`New Game → Mine Exploration → Combat → Loot → Wand Improvement → Special Room → Boss → Game Over / Victory`

### V5.0 主 Tasklist

- [ ] #5 Game Foundation
- [ ] #11 Wand Loot & Generation
- [ ] #12 Mine Enemy Set
- [ ] #13 Special Rooms & Economy
- [ ] #14 Mine Boss & Exit
- [ ] #15 Alpha Balance Pass
- [ ] #16 Basic Dig Power and Terrain Hardness

### V5.0 Definition of Done

- [ ] GameManager / GameState / Game seed 生命周期完整。
- [ ] Normal Game 结束后 Restart 创建干净的新 Game。
- [ ] 世界中能自然获得 Wand / Spell / Gold，奖励能改变 Build。
- [ ] 至少 5 类正式 Mine 敌人，并有真实像素环境互动。
- [ ] Treasure / Shrine / Shop 均参与正常游戏流程。
- [ ] Gold 有明确消费端。
- [ ] Mine Boss、Major Reward 与 Exit / Victory 成立。
- [ ] Creative Mode 不参与 Normal progression。
- [ ] 完整 Game 不依赖开发者手工摆放关键奖励。

### 当前优先实现

**Game Foundation**

- #1 GameManager and Game State
- #2 Game Death and Restart Flow
- #3 Game Start, Death, Victory and Summary UI
- #4 Clean Session Reset

**Wand Loot & Generation**

- #6 Runtime Wand Generator
- #7 Deterministic Wand Generation
- #8 World Wand Pickup
- #9 Wand Comparison UI
- #10 Unified Wand Reward API

## V5.0 关键依赖

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

`Basic Dig Power and Terrain Hardness` 是 V5.0 横向 P1 任务：不阻塞最早的 GameManager/Wand 开发，但应在最终平衡前完成。

## 远期 Milestone 边界

- **V5.1 — Wand & Material Gameplay**：Trigger / Timer / Conditional Cast、Homing / Orbit / Trail、完整 Hardness、Conductivity、Wet + Electricity、更多 Material Reaction。
- **V5.2 — Snow Biome Gameplay**：Snow 敌人、Encounter、环境危险、Loot、Special Rooms、Boss、Mine→Snow Progression。
- **V5.3 — Creative Developer Toolkit**：Scenario/Wand Presets、Entity Spawn Sets、Simulation Debugging、Native Snapshot/Restore、Terrain Undo/Redo、World Snapshot。
- **V5.4 — Engine & Platform Hardening**：Ghost Halo、Sector/Streaming/Native profiling、长期稳定性、Linux/macOS、Android/Web、真实硬件 Runtime Profile。
- **V6.0 — World & Progression Expansion**：Deep、多 Biome Game、Elite、更多 Boss、Discovery/Collection、更多 Special Rooms。
- **V6.1 — Meta Progression**：tentative；只有基础 Game 已被证明好玩后再推进。

## Manifest 使用方式

- GitHub 已创建的节点通过 YAML 的 `github_issue` 映射。
- 尚未创建的节点只保留稳定 `id`、父子关系、Milestone、Labels 和依赖。
- 接近开发时再把对应节点提升为 GitHub Issue，并回填 `github_issue`。
- 标题发生变化时依赖稳定 `id`，不要使用标题作为机器依赖键。

## 文件职责

- `GITHUB_ROADMAP_MANIFEST.md`：开发者阅读、Scope/依赖/路线快速理解。
- `GITHUB_ROADMAP_MANIFEST.yaml`：机器读取、Issue 映射、父子关系和依赖源数据。
