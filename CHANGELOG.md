> **Gameplay V5.0 SpecialChunk Bottom Palette：** 为独立 `ChunkLayer` 增加类似 TileMap 的底部 SpecialChunk 画笔面板。面板使用 Godot 4.7 transient bottom `EditorDock`，仅在选中 `ChunkLayer` 时打开；以缩略图网格展示 `palette_chunks`，支持名称/ID/Biome/Tag 搜索、多 Tag 的 Any/All 筛选、选中即进入 Paint、Pick 反向同步、双击/Inspect 打开 `SpecialChunkDef`。Palette 内容只来自 `ChunkLayer.palette_chunks`，不扫描目录、不硬编码资源路径。插件版本更新为 2.4.0。详见 `docs/SPECIAL_CHUNK_PALETTE_AUTHORING.md`。

> **Gameplay V5.0 Chunk Grid Selection Hotfix：** 调整 World Layout 编辑器 Overlay 的显示语义。固定 SpecialChunk 的完整色块、透明预览、footprint 边框和标签仍会在 WorldLayout 打开后默认显示，但橙色 Chunk 网格现在只在 Scene Tree 中选中对应 `ChunkLayer` 时绘制；选中 BiomeLayer、Anchor 或 WorldLayout 根节点时不会再显示网格。Dock 文案同步为 “Fixed chunks (grid when selected)”，插件版本更新为 2.3.3。

> **Gameplay V5.0 Chunk Overlay Default Visibility Hotfix：** 修复固定 Chunk 屏幕空间 Overlay 只有在 `ChunkLayer` 成为当前编辑对象后才开始绘制、打开 WorldLayout 时默认看不到 Chunk 的问题。World Layout Editor 现在启用 Godot 的 force canvas overlay forwarding，并通过 `_forward_canvas_force_draw_over_viewport()` 在 WorldLayout 打开后立即绘制固定 Chunk、网格、边框和标签，不依赖当前选中节点；`ChunkLayer` 仍保持纯 `Node2D` placement data。插件版本更新为 2.3.2。

> **Gameplay V5.0 Chunk Overlay Zoom Hotfix：** 修复固定 SpecialChunk 在 World Layout 缩放后只显示材质 PNG 的局部不透明区域、边框随缩放变细或被 CanvasItem bounds 裁剪的问题。固定 Chunk 的完整色块、透明预览图、边框、标签、选中手柄和 Hover footprint 全部迁移到 EditorPlugin 的屏幕空间 Overlay；每个 authored footprint 始终先绘制完整 `editor_color` 背板，再叠加透明美术预览，网格和边框维持稳定屏幕像素宽度。`ChunkLayer` 保持纯 `Node2D` placement data，插件版本更新为 2.3.1。

> **Gameplay V5.0 World Layout Scale / Surface Simulation Refinement：** `ChunkLayer` 的网格从 Node2D 世界绘制迁移到 EditorPlugin 的屏幕空间 Overlay，线宽不再随缩放衰减，并按当前 2D 视口裁剪后完整覆盖 `BiomeLayer` authored bounds；默认地表 18,585 个装饰草像素改用独立 `surface_foliage` 惰性材质，保留可燃表现但不再触发 autonomous 生长；默认地下宏观地图从 49 行压缩为 26 行，并同步下移/更新 Mine、Snow、Deep 过渡和 `main_path_end` Anchor。World Layout Editor 版本更新为 2.3.0。

> **Gameplay V5.0 Surface / World Layout Usability Fix：** 修复地表矿井入口装饰支撑梁阻断玩家碰撞体的问题，入口从地表到 `OPEN_LARGE` 底部 Socket 现在具有连续安全净空；默认世界背景改为紫灰色系，与蓝青色 Water 明显区分。World Layout 编辑器不再在选中 `BiomeLayer` 时强制恢复可见性，Scene Tree 眼睛与 Dock Overlay 会双向同步；`ChunkLayer` Select 模式现在可点击固定 Chunk，高亮 footprint、在 Dock 显示 ID/Origin/Size/Biomes/Tags/Resource，并支持双击或按钮打开 `SpecialChunkDef` Inspector。插件版本更新为 2.2.0。

> **Gameplay V5.0 Surface Opening Pass：** 地表出生段改为真正的美术预制像素世界。`SpecialChunkDef` 新增数据驱动 `material_layout`，固定 Surface Chunk 直接消费 512×512 / 512×1024 精确材质色图，不再由运行时公式临时生成；默认世界现在由 Left Boundary / Ground / Grove / Approach / Spawn / East Ground / 1×2 Mine Entrance 七个固定 Chunk 连成连续地表，入口底部与 `OPEN_LARGE` Piece Socket 精确对齐。新增 `WorldPresentationProfile + WorldBackdrop`，用 Resource 控制天空、地下渐变和远近山体轮廓。美术布局在主线程转换为 `Image` 后交给 Worker，后台线程不读取 Texture2D。

> **Gameplay V5.0 World Layout Tool-Mode Hotfix：** 修复 `ChunkPaintPlacementDef` 在编辑器中被加载为 placeholder、导致 `ChunkLayer._draw_placement()` 调用 `is_valid()` 失败的问题。World Layout 编辑器执行链上的数据脚本现在全部显式声明 `@tool`（WorldGenConfig / WorldDefinition / BiomeConfig / BiomeTileBinding / WorldLayoutPreset / ChunkPaintPlacementDef / SpecialChunkDef / SpawnAnchorDef / WorldStructureProfile / WorldLayoutSnapshot 等）；ChunkLayer 增加 placeholder 防御检查，Smoke Test 增加 `Script.is_tool()` 闭包断言，插件版本更新为 2.1.1。应用后需完整重启 Godot 以清除已缓存的 placeholder 实例。

> **Gameplay V5.0 World Layout Editor Hotfix：** 修复 Godot 4.7 warnings-as-errors 下的三组项目解析失败（WeakRef 类型推导、SpecialSpellRuntime 测试参数迁移、ChunkLayer/TileMap 类型断言）；World Layout 插件迁移到 Godot 4.7 `EditorDock + add_dock()`，加载后主动显示 Dock，并在 Main/World 的 2D 顶部工具栏始终提供 Open / Biomes / Fixed Chunks / Anchors / Validate 入口。Main 中央画布仍是运行时 Bootstrap，世界地图通过数据链打开，不嵌入 Main。

> **Gameplay V5.0 World Layout Editor Pass：** 完成 World Layout 的编辑器工作流。新增全局 World Layout Dock 与 Tools 菜单入口，可从 Main/World 的 `WorldGenConfig -> WorldDefinition` 数据链自动解析并打开当前 Layout；Layout 内提供 Biome / Fixed Chunk / Anchor / Validate 快捷模式与统一 Overlay。默认 Biome 已真正序列化进 `TileMapLayer.tile_map_data`，不再依赖 bootstrap 才可见；`ChunkLayer` 继续保持独立 Node2D authored placement 内核；WorldAnchor 增加常驻编辑器标记与标签。

> **Gameplay V5.0 World Layout Foundation：** 世界宏观结构改为可视化二维 Authoring。新增 `WorldDefinition / WorldLayout / BiomeLayer / ChunkLayer / WorldAnchor / WorldLayoutSnapshot`；Biome 不再通过深度上下界选择，而由 TileMapLayer 直接绘制 Chunk 级二维分区，空格即 VOID；ChunkLayer 可放置多格 Fixed SpecialChunk，未覆盖区域继续按 Biome 程序生成。默认世界加入 Surface、固定出生地与 1×2 右下矿井入口，并通过线程只读 Snapshot 接入现有 Piece/Streaming/SpecialChunk 管线。`WorldStructureProfile` 不再保存第二套世界边界。详见 `WORLD_LAYOUT_AUTHORING.md`。

> **Gameplay V4.5.3 Creative Sandbox Tools：** 创造模式补齐 Entity Sandbox 与 Simulation Lab。新增 ENTITIES 页，可生成 Cave Eye、Gold Pickup、Fireball Pickup，并使用 DELETE/CLEAR SPAWNED 只清理创造模式生成实体；WORLD 页新增 Sand Simulation 暂停、单 Tick 步进与 0.25x/0.5x/1x/2x/4x 速度。Entity 工具沿用 Gameplay Input Arbitration，不会在放置/删除实体时误发 Wand。Terrain Undo/Redo 暂不使用 GDScript 逐像素快照的低性能方案，等待 fallingsand 增加 Native region snapshot/restore。详见 `docs/GAMEPLAY_V4_5_3_CREATIVE_SANDBOX_TOOLS.md`。

> **Gameplay V4.5.2 Scene UI + Creative Input Arbitration：** 修复 Creative MATERIALS 绘制时仍会同时发射 Wand 的输入冲突；`GameModeManager` 现在负责 Gameplay/Creative primary-action 仲裁，Material Brush 选中时独占左键。与此同时，GameplayUI 与 CreativeUI 的固定界面已迁移到 `.tscn`，SpellSlot、WandGlyph、Wand Row、Wand Quick Slot、Material Tile、Creative Spell Tile 都改为可复用 PackedScene；UI 脚本只负责数据绑定、显隐、信号与拖拽逻辑，不再通过 `Button.new()/PanelContainer.new()/Label.new()` 构建界面。详见 `docs/GAMEPLAY_V4_5_2_SCENE_UI_INPUT_ARBITRATION.md`。

> **Gameplay V4.5.1 Painting Creative UI：** Creative Mode 的视觉层已完全切换到项目 `painting` 模块的 UI 家族：直接复用 `painting/ui/_theme/theme.tres`、Poppins、灰紫面板、4px 圆角、Painting 按钮/Toggle/ScrollBar，以及橙色选中反馈；Brush / Erase / Pick 复用 Painting 图标。MATERIALS、SPELLS、WANDS、PLAYER、WORLD 的功能仍沿用 V4.5 的 Native Brush / 无限 Spell Library / Runtime Wand Lab 架构，Normal Gameplay UI 继续保持原 Noita-like 风格。详见 `docs/GAMEPLAY_V4_5_1_PAINTING_CREATIVE_UI.md`。

> **Gameplay V4.5 Creative Sandbox + Wand Lab：** 新增正式 `GameModeManager / GameRules`，F8 可在开发阶段切换 Normal / Creative。Creative Mode 使用参考 Painting 模块的底部 Dock：MATERIALS 提供 Native 圆刷/擦除/取样，SPELLS 提供无限 SpellCatalog 与拖拽到当前 Wand，WANDS 可创建/复制/删除 runtime Wand 并实时编辑 Mana、Recharge、Cast Delay、Capacity、Spread、Multicast、Shuffle，PLAYER 可切换无敌、无限 Mana/Flight 与无碰撞自由飞行。创造模式不修改原始 `.tres`，地图批量绘制走 fallingsand Native circle replacement，避免逐像素 GDScript 绘制。详见 `docs/GAMEPLAY_V4_5_CREATIVE_SANDBOX_WAND_LAB.md`。

> **Gameplay V4.4.3 Wand Visual / Native Refresh：** 修复 `WandGlyph.gd` 在 warnings-as-errors 下的类型推导编译错误；WANDS 快捷栏与展开 Wand 编辑行重新统一读取 `WandDef.visual_texture`，详情图标框固定为正方形并放大 Glyph；所有 Gameplay 版本文档迁入 `docs/`；`bin/fallingsand/` 已替换为最新提供的 Windows x86_64、Android arm64 与 Web wasm 编译产物。详见 `docs/GAMEPLAY_V4_4_3_WAND_VISUAL_NATIVE_REFRESH.md`。

> **Gameplay V4.3 Wand Editor / Inventory / Spell Pickup UI：** Player 身上的临时 HUD 已完全移除，`World.tscn` 现在挂载独立 `GameplayUI` CanvasLayer。新 UI 提供 HP/Mana/Flight/Gold/Status、实时 Wand Deck、Recharge、死亡提示、Spell Pickup toast，以及可暂停 Gameplay 的 Wand Editor + 24 格 Spell Inventory。新增 `PlayerInventory`（4 Wand slots）、Spell 拖拽/点选交换、运行中 Deck 即时重建、638 张 16×16 Spell atlas 图标接入、世界 Spell Pickup 和 Cave Eye 随机法术掉落。`Tab/I` 打开编辑器，`Esc` 关闭。详见 `docs/GAMEPLAY_V4_3_WAND_EDITOR_INVENTORY_UI.md`。

> **Gameplay V4.1 Wand & Pixel Spells：** 法杖参数已从 `Player.gd` 迁移到 `WandController / WandDef / SpellDef / GameplayEffect / ProjectileDef` 数据链。Starter Wand 默认提供 Spark Bolt、Dig Bolt、Fire Bolt、Bomb 四个验证法术，并新增 Mana HUD、1–4/鼠标滚轮切换。弹丸与施法特效采用整数像素对齐的方形核心、离散像素尾迹、枪口碎粒与撞击碎粒；Fire Bolt 还会向 SandSimulation 写入少量真实 Fire 像素，Bomb 同时作用于 Actor 与可破坏地形。视觉目标是低分辨率、模拟世界一致的像素颗粒感，而不是复刻 Noita 的具体贴图/特效资产。详见 `docs/GAMEPLAY_V4_1_WAND_PIXEL_SPELLS.md`。

> **Gameplay V4.0 Foundation：** 当前主线切换到 Gameplay。新增统一 DamagePacket / HealthComponent / FactionComponent、Player HP 与死亡重生、共享 GameplayProjectile、Cave Eye 第一只远程敌人、Gold Pickup，以及 Water/Oil/Fire/Lava/Acid 驱动的 Wet/Oiled/Burning/Toxic 环境状态。Gameplay 通过 `WorldGameplayService` 访问像素世界，不依赖 Chunk/Sector 内部细节。详见 `docs/GAMEPLAY_V4_0_FOUNDATION.md`。

> **V3.9.1 Native Block API Cleanup：** `SandSimulation` 的 16×16 Simulation Blocks 现在只暴露 `get_block()` / `set_block_size()`；旧 `get_chunk()` / `set_chunk_size()` 已从 C++ 与 GDScript API 中彻底删除。Active Block 调度逻辑保持 V3.9 不变。稳定的 INERT/MOVABLE 区域会在 4 个 quiet tick 后睡眠，`set_cell()`、爆炸、地形破坏与 API 9 Native Seam 会自动唤醒本 Block 与 3×3 邻域；REACTIVE/AUTONOMOUS 材料使用保守 Activity Policy 防止反应睡死。PC 的 3×3 simulation radius 现在统一使用 60Hz，依靠 Active Blocks 降低实际扫描量。请重新编译 `extensions/sand-slide`，并在 F1 确认 `native yes(api 11)` 与 `Active blocks: yes`。详见 `docs/NATIVE_BLOCK_API_CLEANUP_V3_9_1.md` 与 `docs/NATIVE_ACTIVE_BLOCKS_V3_9.md`。

> **V3.8.1 Native Cross-Chunk Flow：** 液体、气体与显式 Powder 现在通过 API 9 Native Seam Bridge 跨 Chunk；移动端保留 `simulation_radius = 0`，正交邻居只保持 Warm，真实跨边界后临时唤醒。请重新编译 `extensions/sand-slide`，并在 F1 确认 `Native flow: yes` / `api 9`。V3.8.1 额外修复 MSVC 对 `std::min(int, int64_t)` 的严格模板推导错误；运行时 Native API 仍为 9。详见 `docs/NATIVE_CROSS_CHUNK_FLOW_V3_8.md` 与 `docs/MSVC_BUILD_FIX_V3_8_1.md`。

> **V3.7.3 移动端 PC 预算测试：** 移动端的流水线、模拟、碰撞构建与 Sector 提交预算已统一到 PC 档；加载范围、模拟频率、纹理缩放和对象池仍保留移动端设置。详见 `docs/MOBILE_PC_BUDGETS_V3_7_3.md`。

> **V3.7.2 燃烧性能修复：** 动态碰撞采用紧凑 Sector 占用位图、删除/新增分级同步与保守快照渐进提交。请重新编译 `extensions/sand-slide`，并在 F1 HUD 确认 `native yes(api 8)`。详见 `docs/COLLISION_BURNING_PERFORMANCE_V3_7_2.md`。
