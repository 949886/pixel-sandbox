# Gameplay 数据驱动与硬编码约束

> 适用项目：Pixel Sandbox（Godot 4.7）  
> 目标：Gameplay 内容通过 Resource / Scene 组合，运行时代码只实现行为，不维护内容注册表、资源路径映射或策划数值表。

## 1. 核心原则

### 1.1 内容属于数据，行为属于代码

凡是“新增一种内容时，策划/开发者应该只改资源而不改注册代码”的信息，都必须进入 `.tres` / `.tscn`：

- Spell、Wand、Enemy、Loot、Game Flow、Starting Loadout。
- Biome、Special Chunk、Material gameplay semantic。
- Creative 可生成实体、Creative 默认规则、Creative Wand 模板。
- Gameplay 状态数值、敌人平衡参数、世界生成内容参数。
- PackedScene / Texture / Audio / Resource 等内容依赖。

代码只负责：

- 算法与状态机。
- Resource schema / validator。
- 通用执行器（例如 LootSpawner）。
- Godot/引擎协议适配。
- 不携带具体内容身份的安全边界与数学常量。

### 1.2 Runtime 不主动“找内容”

Runtime 不允许通过路径、目录、字符串映射寻找 Gameplay 内容。

依赖方向统一为：

```text
Main / Bootstrap / Scene Composition
            ↓
    GameplayContentDB
            ↓
 Catalog / Profile / Def / Rules
            ↓
      Runtime Behavior
```

场景局部内容可以直接由 `.tscn` 注入 Profile/Def；跨系统共享内容必须从 `GameplayContentDB` 或其 Catalog 获取。

### 1.3 缺少必需数据时应显式失败

禁止为了“能跑”偷偷回退到某个硬编码资源路径或某个具体内容 ID。

正确方式：

```gdscript
if gameplay_content == null or not gameplay_content.is_valid():
    push_error("GameplayContentDB is missing or invalid.")
    return
```

错误方式：

```gdscript
if gameplay_content == null:
    gameplay_content = load("res://resources/gameplay/default.tres")
```

---

## 2. 强制规则

### Rule A — 第一方 GDScript 禁止硬编码脚本路径

第一方 Runtime / Gameplay 代码中禁止：

```gdscript
preload("res://scripts/xxx/Foo.gd")
load("res://scripts/xxx/Foo.gd")
```

项目内部脚本依赖应使用 `class_name`、类型注解、节点组合或 Resource 注入。

允许第三方 addon 保持其原始实现；不要为了满足本项目规则直接修改 vendored addon。

### Rule B — Runtime GDScript 禁止硬编码 Gameplay 资源路径

禁止：

```gdscript
const SPELLS = [
    "res://resources/gameplay/spells/a.tres",
    "res://resources/gameplay/spells/b.tres",
]
```

禁止：

```gdscript
var scene := preload("res://scenes/gameplay/CaveEye.tscn")
```

允许 `.tres` / `.tscn` 自身通过 `ExtResource` 序列化资源引用，因为这是数据组合，不是代码注册。

### Rule C — 禁止代码侧内容注册表

以下形式均禁止：

```gdscript
match flow_id:
    &"normal": return NormalGameFlow.new()
    &"daily": return DailyGameFlow.new()
```

```gdscript
if biome_id == &"snow":
    return Color(...)
```

```gdscript
if enemy_id == &"cave_eye":
    return preload(...)
```

应改为：

```text
GameFlowCatalog.tres
EnemyCatalog.tres
BiomeConfig.tres
MaterialPalette.tres
```

### Rule D — 内容 ID 只能用于查数据，不能决定具体实现映射

允许：

```gdscript
var enemy_def := content.enemy_catalog.get_enemy(enemy_id)
```

禁止：

```gdscript
if enemy_id == &"cave_eye":
    return CaveEye.new()
```

ID 是数据主键，不是隐藏的代码分支注册机制。

### Rule E — Gameplay tuning 必须由 Def / Profile / Rules 或 Scene 数据提供

例如以下内容不能只存在于 Runtime 脚本中的默认数值：

- Enemy move speed / attack range / fire rate / projectile data。
- Loot chance / reward amount / reward scene。
- Status damage / duration / reaction multiplier。
- Biome-specific generation chance / visual colors。
- Special chunk generated visual colors。

如果数值属于某一具体内容，应放在该内容的 Resource / Scene 中。

### Rule F — 原生 ID 必须先映射成 Gameplay 语义

例如 sand-slide 的 element id 不应该散落在 Gameplay 代码里：

```gdscript
if element_id == 20: # lava
```

统一由 `MaterialPalette` 的 gameplay binding 把 native id 映射为 semantic tag：

```text
20 -> [lava, fire, liquid]
```

Gameplay 系统只消费：

```text
water / oil / fire / lava / toxic / liquid
```

### Rule G — 随机内容必须接收 RNG / Seed

影响一局 Run 的随机结果禁止在深层系统中隐藏地 `randomize()` 后自行决定内容。

Catalog / Generator / Loot / Encounter 应优先接收外部 `RandomNumberGenerator` 或 deterministic seed。

纯表现随机（粒子抖动、视觉噪声等）可以使用本地 RNG，只要它不改变 Gameplay 结果。

### Rule H — 共享 Resource 不允许承载每局可变状态

`.tres` 是模板数据。

运行时如果需要修改：

```gdscript
var runtime_rules := authored_rules.duplicate(false)
```

不要直接修改 `GameplayContentDB` 中共享的 authored Resource。

### Rule I — Catalog 必须校验唯一 ID

Catalog 至少应保证：

- ID 非空。
- ID 唯一。
- 必需 Resource / PackedScene 非空。
- 条目自身 `is_valid()`。

发现重复或无效内容应显式报错，而不是“最后一个覆盖前一个”。

### Rule J — 不允许隐式目录扫描作为正式内容注册方式

允许“编辑器导入工具”扫描目录来生成 Catalog Resource。

正式 Runtime 不应该依赖：

```gdscript
DirAccess.open("res://some/content/directory")
```

来决定当前版本有哪些 Spell / Enemy / Loot / Piece。

Runtime 应读取已经保存好的 Catalog / Library。

---

## 3. 什么可以留在代码里

数据驱动不意味着“代码中不能有数字或字符串”。以下通常属于实现协议，可以保留：

- `TAU`、epsilon、最小除数、数组边界等数学/安全值。
- `top/right/bottom/left` 这种结构协议。
- enum 与 enum 分支。
- Node/Component 的稳定接口名称。
- group / input action 等项目级协议名称。
- 纯算法用的 iteration cap / 防死循环上限。
- Debug/Test 专用 fixture 的资源引用。
- Resource schema 中用于新建资源时的合理编辑器默认值。

判断标准：

> “新增或调整一种 Gameplay 内容时，是否需要修改这行代码？”

如果答案是“需要”，这行内容通常应该迁到 Resource / Scene。

---

## 4. 当前统一入口

### `GameplayContentDB`

当前全局 Gameplay 内容根：

```text
GameplayContentDB
├── default_flow_id
├── GameFlowCatalog
├── StartingLoadoutDef
├── SpellCatalog
├── EnemyCatalog
├── EncounterCatalog
├── WandGenerationCatalog
├── RewardCatalog
├── CreativeEntityCatalog
├── GameRules (Creative template)
├── StatusRulesDef
└── WandDef (Creative blank template)
```

`Main` 只注入这个根资源；`GameBootstrap` 把它继续传入本局 World。

需要共享内容的 Runtime 使用组合后的内容引用，禁止自己加载默认路径。

---

## 5. 当前已采用的数据模式

### Game Flow

```text
GameFlowDef.tres
    flow_id
    flow_scene
        ↓
GameFlowCatalog.tres
        ↓
GameplayContentDB
```

新增 Flow：新增 Scene + `GameFlowDef` + Catalog 条目，不改 `GameBootstrap`。

### Spell

```text
SpellDef.tres[]
      ↓
SpellCatalog.tres
      ↓
GameplayContentDB
```

新增 Spell：创建 `SpellDef.tres`，加入 Catalog；禁止新增脚本路径数组。

### Enemy

```text
EnemyDef.tres
├── enemy_id
├── scene
├── threat_cost
└── placement_tags
        ↓
EnemyCatalog.tres
        ↓
GameplayContentDB
```

Enemy-specific tuning 由其 Scene 注入专用 Profile，例如：

```text
CaveEye.tscn
    ↓
CaveEyeTuningDef.tres
├── movement
├── attack
├── ProjectileDef
├── LootTableDef
└── presentation
```

### Loot

```text
LootTableDef
└── LootEntryDef[]
    ├── chance
    ├── PackedScene
    ├── payload contract
    └── authored offset
```

不同 LootEntry 可以通过 Resource subclass 实现 payload 生成，例如 Gold / Spell。

Runtime `LootSpawner` 不知道任何资源路径，也不维护 `enemy -> drop` 映射。

### Material Gameplay

```text
MaterialPalette
└── MaterialGameplayBinding[]
    native element id -> semantic tags
```

`EnvironmentSensor` / Status 只使用 semantic tag。

### Biome / World generation

Biome 特有参数属于 `BiomeConfig.tres`：

- depth range
- openness
- generated glue colors
- main-path wander chance
- branch / loop / chamber probabilities
- chamber size pool

生成器禁止按 `mine/snow/deep` 名称写特殊分支。

### Special Chunk

`SpecialChunkDef.tres` 自己保存生成 fallback 所需的颜色/表现参数。

Builder 可以根据 `ChunkKind` 执行不同算法形态，但不能通过具体 SpecialChunk ID 或 biome ID 映射内容资源。

---

## 6. 新内容的标准流程

### 新增 Spell

1. 创建/组合 `SpellDef.tres`。
2. 加入 `spell_catalog.tres`。
3. 如 Creative 需要自动展示，Creative UI 直接读取该 Catalog，无额外注册代码。
4. 不修改任何资源路径数组。

### 新增 Enemy

1. 创建 Enemy Scene。
2. 行为脚本只实现行为逻辑。
3. 可调参数创建专用 Def/Profile Resource，并由 Scene 注入。
4. 创建 `EnemyDef.tres`。
5. 加入 `enemy_catalog.tres`。
6. Encounter / Creative / Debug 系统通过 Def/Catalog 引用，不按 ID 创建具体类。

### 新增 Loot

1. 创建或复用 `LootEntryDef`。
2. 在 `.tres` 中引用 Pickup Scene。
3. 组合为 `LootTableDef`。
4. Enemy / Chest / Reward Profile 引用 LootTable。
5. 不在 Enemy 脚本中 `GoldPickup.new()` / `SpellPickup.new()`。

### 新增 Biome

1. 创建 `BiomeConfig.tres`。
2. 配置 depth、openness、structure、generated visual 参数。
3. 加入 `WorldGenConfig.biome_configs`。
4. 禁止在 generator 中增加 `if biome_id == ...`。

---

## 7. Code Review Checklist

每个 Gameplay PR 检查：

- [ ] 第一方 Runtime GDScript 是否新增了 `res://`？如果是，为什么不是 Resource/Scene 注入？
- [ ] 是否新增了 `load/preload` 来注册 Gameplay 内容？
- [ ] 是否新增 `ID -> class/path/resource` 的 `match/if`？
- [ ] 是否把某个具体 Enemy/Spell/Biome 的数值写进了通用 Runtime？
- [ ] 是否新增了隐藏 fallback 路径？
- [ ] 新 Catalog ID 是否唯一并有 validator？
- [ ] Run-affecting RNG 是否由外部传入或可确定性复现？
- [ ] 是否直接修改了共享 `.tres` 模板？
- [ ] 新内容能否做到“只新增/编辑 Resource + Scene，不修改注册代码”？

---

## 8. 建议的静态检查

在仓库根目录执行：

```bash
# 第一方 Runtime 不应出现 res:// 硬编码资源路径
rg -n 'res://' scripts --glob '*.gd'

# 检查直接 load/preload；ResourceLoader 用于读取数据声明的路径需人工复核
rg -n '\b(load|preload)\s*\(' scripts --glob '*.gd'

# 检查容易演变为内容注册表的 ID 分支
rg -n 'match .*_id|==\s*&"|!=\s*&"' scripts/gameplay scripts/world scripts/world_structure
```

注意：这些 grep 是“审查入口”，不是机械判定器。协议字符串、空 ID 校验、方向 enum 等合理代码无需为了让 grep 为零而扭曲设计。

---

## 9. 例外规则

任何例外都必须满足以下至少一项：

1. 引擎/API 协议要求，且无法通过 Resource 合理表达。
2. 纯算法安全边界，不代表某个具体 Gameplay 内容。
3. Test fixture / migration tool / editor import tool，且不会参与正式 Runtime 内容注册。
4. 第三方 addon 原始代码。

如果例外会影响“新增一个内容是否需要改代码”，默认不批准，应先设计数据接口。

---

## 10. 后续扩展约束

Encounter / Wand Generator / Reward / Spawn Anchor 已预留统一 schema：

```text
EncounterDef / EncounterCatalog
WandGenerationProfile / WandGenerationCatalog
RewardProfile / RewardCatalog
SpawnAnchorDef (PieceDef / SpecialChunkDef)
```

实现对应 Runtime 时继续消费这些 Def/Profile，不新增 biome/enemy/resource 路径分支。

它们应该由 `BiomeConfig`、Piece/SpecialChunk 数据或 `GameplayContentDB` 的 Catalog/Profile 组合引用，而不是在 Spawner 中写：

```gdscript
if biome == &"mine":
    spawn(CaveEye)
```

最终目标是：

> **添加一个普通 Gameplay 内容，绝大多数情况下只新增 `.tres/.tscn`；只有新增“行为类型”时才新增 `.gd`。**

## World Layout specific constraints

The macro world uses `WorldDefinition -> WorldLayout -> BiomeLayer/ChunkLayer`. Do not add a parallel
Region abstraction unless it later gains a genuinely independent lifecycle and responsibilities.

- **Biome placement is authored in `BiomeLayer`.** Do not reintroduce `depth_min/depth_max` routing or
  `if y > ...` biome selection in world generation. `WorldStructureProfile` must not define a second
  `min_x/max_x/min_y/max_y` world rectangle either; topology is clipped by the authored layout itself.
- **Empty Biome cells mean VOID.** Runtime streaming/generation must respect the authored 2D shape.
- **Tile IDs are not content IDs.** Tile source/atlas/alternative IDs are resolved only through
  `BiomeTileBinding` / `ChunkTileBinding`; gameplay and generators must not compare numeric TileSet IDs.
- **ChunkLayer is an override, not a biome replacement.** A fixed chunk keeps the underlying Biome
  semantics and only owns its authored terrain/structure footprint.
- **No worker may read TileMapLayer.** Compile editor layers on the main thread into a thread-readable
  `WorldLayoutSnapshot` before starting background world generation.
- **Important world positions are anchors, not coordinates.** Spawn, entrance and main-path endpoints are
  selected by `WorldDefinition` anchor IDs and authored as `WorldAnchor` nodes.
- **Surface is content, not a code branch.** Surface ground/entrance behavior is selected by resource data
  (`SpecialChunkDef.layout_style` and fixed placement), never by hard-coded scene/resource paths.
