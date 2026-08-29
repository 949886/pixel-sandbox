class_name CreativeUI
extends CanvasLayer

@export var material_tile_scene: PackedScene
@export var spell_tile_scene: PackedScene
@export var spell_slot_scene: PackedScene
@export var entity_tile_scene: PackedScene

const EXPANDED_HEIGHT: float = 316.0
const COLLAPSED_HEIGHT: float = 64.0

var _active: bool = false
var _collapsed: bool = false
var _active_tab: StringName = &"materials"
var _selected_wand_index: int = 0
var _spell_filter_kind: int = -1
var _stats_updating: bool = false

var _gameplay_content: GameplayContentDB
var _mode_manager: GameModeManager
var _player: Node
var _inventory: PlayerInventory
var _wand_controller: WandController
var _brush: CreativeBrushController
var _world_service: WorldGameplayService
var _entity_controller: CreativeEntityController
var _wand_service: CreativeWandService = CreativeWandService.new()

@onready var _dock: PanelContainer = %Dock
@onready var _collapse_button: Button = %CollapseButton
@onready var _materials_panel: Control = %MaterialsPanel
@onready var _spells_panel: Control = %SpellsPanel
@onready var _wands_panel: Control = %WandsPanel
@onready var _entities_panel: Control = %EntitiesPanel
@onready var _player_panel: Control = %PlayerPanel
@onready var _world_panel: Control = %WorldPanel

@onready var _materials_tab: Button = %MaterialsTab
@onready var _spells_tab: Button = %SpellsTab
@onready var _wands_tab: Button = %WandsTab
@onready var _entities_tab: Button = %EntitiesTab
@onready var _player_tab: Button = %PlayerTab
@onready var _world_tab: Button = %WorldTab

@onready var _brush_button: Button = %BrushButton
@onready var _erase_button: Button = %EraseButton
@onready var _pick_button: Button = %PickButton
@onready var _brush_size: SpinBox = %BrushSize
@onready var _selected_material_label: Label = %SelectedMaterialLabel
@onready var _material_grid: GridContainer = %MaterialGrid

@onready var _spell_search: LineEdit = %SpellSearch
@onready var _spell_kind: OptionButton = %SpellKind
@onready var _spell_grid: GridContainer = %SpellGrid
@onready var _target_wand_label: Label = %TargetWandLabel
@onready var _target_deck_grid: GridContainer = %TargetDeckGrid
@onready var _spell_wand_buttons: Array[Button] = [%SpellWand1, %SpellWand2, %SpellWand3, %SpellWand4]

@onready var _wand_buttons: Array[Button] = [%Wand1, %Wand2, %Wand3, %Wand4]
@onready var _equip_button: Button = %EquipButton
@onready var _new_button: Button = %NewButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _delete_button: Button = %DeleteButton
@onready var _clear_button: Button = %ClearButton
@onready var _empty_wand_label: Label = %EmptyWandLabel
@onready var _wand_stats: Control = %WandStats
@onready var _mana_max_spin: SpinBox = %ManaMax
@onready var _mana_recharge_spin: SpinBox = %ManaRecharge
@onready var _cast_delay_spin: SpinBox = %CastDelay
@onready var _recharge_spin: SpinBox = %Recharge
@onready var _capacity_spin: SpinBox = %Capacity
@onready var _spread_spin: SpinBox = %Spread
@onready var _multicast_spin: SpinBox = %Multicast
@onready var _shuffle_check: CheckButton = %Shuffle
@onready var _wand_deck_label: Label = %WandDeckLabel
@onready var _wand_deck_scroll: ScrollContainer = %WandDeckScroll
@onready var _wand_deck_grid: GridContainer = %WandDeckGrid


@onready var _entity_spawn_button: Button = %EntitySpawnButton
@onready var _entity_delete_button: Button = %EntityDeleteButton
@onready var _clear_spawned_button: Button = %ClearSpawnedButton
@onready var _selected_entity_label: Label = %SelectedEntityLabel
@onready var _entity_grid: GridContainer = %EntityGrid

@onready var _pause_simulation: CheckButton = %PauseSimulation
@onready var _step_simulation: Button = %StepSimulation
@onready var _simulation_speed: OptionButton = %SimulationSpeed
@onready var _simulation_status: Label = %SimulationStatus

@onready var _invulnerable_toggle: CheckButton = %Invulnerable
@onready var _infinite_mana_toggle: CheckButton = %InfiniteMana
@onready var _infinite_flight_toggle: CheckButton = %InfiniteFlight
@onready var _creative_fly_toggle: CheckButton = %CreativeFly
@onready var _heal_button: Button = %HealButton
@onready var _clear_status_button: Button = %ClearStatusButton

@onready var _drag_panel: PanelContainer = %DragPanel
@onready var _drag_icon: TextureRect = %DragIcon

var _tab_buttons: Dictionary = {}
var _material_tiles: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _entity_tiles: Dictionary = {}

func _ready() -> void:
	layer = 70
	add_to_group(&"creative_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_scene_controls()
	_connect_scene_signals()
	call_deferred("_bind_dependencies")
	set_creative_active(false)

func _register_scene_controls() -> void:
	_tab_buttons = {
		&"materials": _materials_tab,
		&"spells": _spells_tab,
		&"wands": _wands_tab,
		&"entities": _entities_tab,
		&"player": _player_tab,
		&"world": _world_tab,
	}
	_tool_buttons = {
		CreativeBrushController.Tool.BRUSH: _brush_button,
		CreativeBrushController.Tool.ERASE: _erase_button,
		CreativeBrushController.Tool.PICKER: _pick_button,
	}
	_spell_kind.clear()
	_spell_kind.add_item("ALL")
	_spell_kind.add_item("PROJECTILE", SpellDef.Kind.PROJECTILE)
	_spell_kind.add_item("MATERIAL", SpellDef.Kind.MATERIAL)
	_spell_kind.add_item("UTILITY", SpellDef.Kind.UTILITY)
	_spell_kind.add_item("MODIFIER", SpellDef.Kind.MODIFIER)
	_spell_kind.add_item("MULTICAST", SpellDef.Kind.MULTICAST)
	_simulation_speed.clear()
	for multiplier: float in [0.25, 0.5, 1.0, 2.0, 4.0]:
		var speed_index: int = _simulation_speed.item_count
		_simulation_speed.add_item("%.2fx" % multiplier)
		_simulation_speed.set_item_metadata(speed_index, multiplier)
	_simulation_speed.select(2)
	for spin: SpinBox in [_brush_size, _mana_max_spin, _mana_recharge_spin, _cast_delay_spin, _recharge_spin, _capacity_spin, _spread_spin, _multicast_spin]:
		PaintingCreativeStyle.style_spin_box(spin, spin.custom_minimum_size.x)
	PaintingCreativeStyle.style_line_edit(_spell_search, 15)
	_refresh_tab_styles()

func _connect_scene_signals() -> void:
	_materials_tab.pressed.connect(_select_tab.bind(&"materials"))
	_spells_tab.pressed.connect(_select_tab.bind(&"spells"))
	_wands_tab.pressed.connect(_select_tab.bind(&"wands"))
	_entities_tab.pressed.connect(_select_tab.bind(&"entities"))
	_player_tab.pressed.connect(_select_tab.bind(&"player"))
	_world_tab.pressed.connect(_select_tab.bind(&"world"))
	_collapse_button.pressed.connect(_toggle_collapsed)

	_brush_button.pressed.connect(_select_brush_tool.bind(CreativeBrushController.Tool.BRUSH))
	_erase_button.pressed.connect(_select_brush_tool.bind(CreativeBrushController.Tool.ERASE))
	_pick_button.pressed.connect(_select_brush_tool.bind(CreativeBrushController.Tool.PICKER))
	_brush_size.value_changed.connect(_on_brush_size_changed)

	_spell_search.text_changed.connect(_on_spell_search_changed)
	_spell_kind.item_selected.connect(_on_spell_kind_selected)
	for index: int in range(_spell_wand_buttons.size()):
		_spell_wand_buttons[index].pressed.connect(_select_creative_wand.bind(index))
	for index: int in range(_wand_buttons.size()):
		_wand_buttons[index].pressed.connect(_select_creative_wand.bind(index))

	_equip_button.pressed.connect(_wand_action.bind(&"equip"))
	_new_button.pressed.connect(_wand_action.bind(&"new"))
	_duplicate_button.pressed.connect(_wand_action.bind(&"duplicate"))
	_delete_button.pressed.connect(_wand_action.bind(&"delete"))
	_clear_button.pressed.connect(_wand_action.bind(&"clear"))

	for spin: SpinBox in [_mana_max_spin, _mana_recharge_spin, _cast_delay_spin, _recharge_spin, _spread_spin, _multicast_spin]:
		spin.value_changed.connect(_on_wand_stat_changed_float)
	_capacity_spin.value_changed.connect(_on_wand_capacity_changed)
	_shuffle_check.toggled.connect(_on_wand_stat_changed_bool)

	_invulnerable_toggle.toggled.connect(_toggle_rule.bind(&"invulnerable"))
	_infinite_mana_toggle.toggled.connect(_toggle_rule.bind(&"infinite_mana"))
	_infinite_flight_toggle.toggled.connect(_toggle_rule.bind(&"infinite_flight"))
	_creative_fly_toggle.toggled.connect(_toggle_rule.bind(&"creative_fly"))
	_heal_button.pressed.connect(_heal_player)
	_clear_status_button.pressed.connect(_clear_player_status)
	_entity_spawn_button.pressed.connect(_select_entity_tool.bind(CreativeEntityController.Tool.SPAWN))
	_entity_delete_button.pressed.connect(_select_entity_tool.bind(CreativeEntityController.Tool.DELETE))
	_clear_spawned_button.pressed.connect(_clear_spawned_entities)
	_pause_simulation.toggled.connect(_on_simulation_paused_changed)
	_step_simulation.pressed.connect(_step_world_simulation)
	_simulation_speed.item_selected.connect(_on_simulation_speed_selected)

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"inventory_toggle"):
		_toggle_collapsed()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _active or not _drag_panel.visible:
		return
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.gui_is_dragging():
		_drag_panel.position = viewport.get_mouse_position() + Vector2(14.0, 14.0)
	else:
		_drag_panel.visible = false

func set_creative_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	set_process(enabled)
	_update_creative_interaction_state()
	if enabled:
		_refresh_active_panel()

func _bind_dependencies() -> void:
	_gameplay_content = GameplayContentAccess.find_from(self)
	_mode_manager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	_player = get_tree().get_first_node_in_group(&"player")
	if _player != null:
		_inventory = _player.get_node_or_null("PlayerInventory") as PlayerInventory
		_wand_controller = _player.get_node_or_null("WandController") as WandController
		_wand_service.configure(
			_inventory,
			_wand_controller,
			_gameplay_content.creative_wand_template if _gameplay_content != null else null,
		)
	var world: Node = get_parent()
	_world_service = world.get_node_or_null("GameplayWorld") as WorldGameplayService if world != null else null
	_brush = world.get_node_or_null("CreativeBrush") as CreativeBrushController if world != null else null
	_entity_controller = world.get_node_or_null("CreativeEntities") as CreativeEntityController if world != null else null
	if _brush != null:
		if not _brush.material_picked.is_connected(_on_material_picked):
			_brush.material_picked.connect(_on_material_picked)
		_brush_size.value = _brush.brush_radius
	if _mode_manager != null:
		set_creative_active(_mode_manager.is_creative())
	_refresh_material_grid()
	_refresh_entity_grid()
	_refresh_active_panel()

func _select_tab(tab_name: StringName) -> void:
	_active_tab = tab_name
	if _collapsed:
		_collapsed = false
		_apply_collapsed_state()
	_refresh_tab_styles()
	_refresh_active_panel()
	_update_creative_interaction_state()

func _refresh_tab_styles() -> void:
	for key: Variant in _tab_buttons.keys():
		var tab_name: StringName = StringName(key)
		var button: Button = _tab_buttons.get(tab_name, null) as Button
		if button != null:
			PaintingCreativeStyle.style_tab_button(button, tab_name == _active_tab)

func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_apply_collapsed_state()

func _apply_collapsed_state() -> void:
	%PanelHost.visible = not _collapsed
	_dock.offset_top = -COLLAPSED_HEIGHT if _collapsed else -EXPANDED_HEIGHT
	_collapse_button.text = "▲" if _collapsed else "▼"
	_update_creative_interaction_state()

func _refresh_active_panel() -> void:
	_materials_panel.visible = _active_tab == &"materials"
	_spells_panel.visible = _active_tab == &"spells"
	_wands_panel.visible = _active_tab == &"wands"
	_entities_panel.visible = _active_tab == &"entities"
	_player_panel.visible = _active_tab == &"player"
	_world_panel.visible = _active_tab == &"world"
	match _active_tab:
		&"materials":
			_refresh_material_panel()
		&"spells":
			_refresh_spell_panel()
		&"wands":
			_refresh_wand_panel()
		&"entities":
			_refresh_entity_panel()
		&"player":
			_refresh_player_panel()
		&"world":
			_refresh_world_panel()

func _update_creative_interaction_state() -> void:
	if _brush != null:
		# The material tool owns primary pointer input only while its workspace is
		# selected. This is also the central gate that prevents wand firing.
		_brush.set_interaction_enabled(_active and _active_tab == &"materials")
	if _entity_controller != null:
		_entity_controller.set_interaction_enabled(_active and _active_tab == &"entities")

func _select_brush_tool(tool: int) -> void:
	if _brush == null:
		return
	_brush.set_tool(tool)
	_refresh_tool_button_styles()

func _on_brush_size_changed(value: float) -> void:
	if _brush != null:
		_brush.set_brush_radius(value)

func _refresh_material_panel() -> void:
	if _brush == null:
		return
	_selected_material_label.text = _material_label_for_id(_brush.selected_element_id)
	_refresh_material_button_styles()
	_refresh_tool_button_styles()

func _refresh_material_grid() -> void:
	_clear_children(_material_grid)
	_material_tiles.clear()
	var palette: MaterialPalette = _world_service.material_palette() if _world_service != null else null
	if palette == null:
		return
	for entry: MaterialEntry in palette.entries:
		if entry == null or entry.engine_element_id == 0:
			continue
		var tile: CreativeMaterialTile = material_tile_scene.instantiate() as CreativeMaterialTile
		tile.setup(entry)
		tile.material_selected.connect(_select_material)
		_material_grid.add_child(tile)
		_material_tiles[entry.engine_element_id] = tile
	_refresh_material_button_styles()

func _select_material(element_id: int) -> void:
	if _brush != null:
		_brush.set_paint_element(element_id)
	_selected_material_label.text = _material_label_for_id(element_id)
	_refresh_material_button_styles()
	_refresh_tool_button_styles()

func _on_material_picked(element_id: int) -> void:
	_selected_material_label.text = _material_label_for_id(element_id)
	_refresh_material_button_styles()
	_refresh_tool_button_styles()

func _refresh_tool_button_styles() -> void:
	if _brush == null:
		return
	for key: Variant in _tool_buttons.keys():
		var tool_id: int = int(key)
		var button: Button = _tool_buttons.get(tool_id, null) as Button
		if button != null:
			PaintingCreativeStyle.style_tab_button(button, tool_id == _brush.selected_tool)

func _refresh_material_button_styles() -> void:
	if _brush == null:
		return
	for key: Variant in _material_tiles.keys():
		var element_id: int = int(key)
		var tile: CreativeMaterialTile = _material_tiles.get(element_id, null) as CreativeMaterialTile
		if tile != null:
			tile.set_selected_state(element_id == _brush.selected_element_id and _brush.selected_tool == CreativeBrushController.Tool.BRUSH)

func _material_label_for_id(element_id: int) -> String:
	if _world_service == null:
		return "MATERIAL %d" % element_id
	var palette: MaterialPalette = _world_service.material_palette()
	var entry: MaterialEntry = palette.entry_for_element_id(element_id) if palette != null else null
	if entry != null:
		return "SELECTED: %s" % String(entry.id).replace("_", " ").to_upper()
	return "SELECTED: ELEMENT %d" % element_id

func _creative_spells() -> Array[SpellDef]:
	if _gameplay_content == null or _gameplay_content.spell_catalog == null:
		return []
	return _gameplay_content.spell_catalog.all_spells()


func _creative_entities() -> Array[CreativeEntityDef]:
	if _gameplay_content == null or _gameplay_content.creative_entity_catalog == null:
		return []
	return _gameplay_content.creative_entity_catalog.all_entities()


func _refresh_spell_panel() -> void:
	_refresh_spell_wand_buttons()
	_refresh_spell_grid()
	_refresh_target_deck()

func _on_spell_search_changed(_text: String) -> void:
	_refresh_spell_grid()

func _on_spell_kind_selected(index: int) -> void:
	_spell_filter_kind = -1 if index == 0 else _spell_kind.get_item_id(index)
	_refresh_spell_grid()

func _refresh_spell_grid() -> void:
	_clear_children(_spell_grid)
	var query: String = _spell_search.text.strip_edges().to_lower()
	for spell: SpellDef in _creative_spells():
		if spell == null:
			continue
		if _spell_filter_kind >= 0 and spell.kind != _spell_filter_kind:
			continue
		if not query.is_empty():
			var haystack: String = (spell.display_name + " " + String(spell.spell_id) + " " + " ".join(spell.tags)).to_lower()
			if query not in haystack:
				continue
		var tile: CreativeSpellTile = spell_tile_scene.instantiate() as CreativeSpellTile
		tile.setup(spell)
		tile.spell_activated.connect(_add_creative_spell)
		tile.drag_visual_started.connect(_show_drag_visual)
		_spell_grid.add_child(tile)

func _refresh_spell_wand_buttons() -> void:
	for index: int in range(_spell_wand_buttons.size()):
		PaintingCreativeStyle.style_tab_button(_spell_wand_buttons[index], index == _selected_wand_index)

func _refresh_target_deck() -> void:
	_clear_children(_target_deck_grid)
	var wand: WandDef = _selected_wand()
	_target_wand_label.text = "TARGET WAND %d  •  %s" % [_selected_wand_index + 1, wand.display_name if wand != null else "EMPTY"]
	if wand == null:
		return
	if _inventory != null:
		_inventory.normalize_wand_runtime(wand)
	for slot_index: int in range(wand.capacity):
		_add_creative_wand_slot(_target_deck_grid, wand, slot_index, "")

func _add_creative_spell(spell: SpellDef) -> void:
	if _wand_service.add_spell_first_empty(_selected_wand_index, spell):
		_refresh_target_deck()
		if _active_tab == &"wands":
			_refresh_wand_panel()

func _refresh_wand_panel() -> void:
	_refresh_wand_selector_buttons()
	var wand: WandDef = _selected_wand()
	var has_wand: bool = wand != null
	_empty_wand_label.visible = not has_wand
	_wand_stats.visible = has_wand
	_wand_deck_label.visible = has_wand
	_wand_deck_scroll.visible = has_wand
	if not has_wand:
		_clear_children(_wand_deck_grid)
		return
	_stats_updating = true
	_mana_max_spin.value = wand.mana_max
	_mana_recharge_spin.value = wand.mana_recharge_per_second
	_cast_delay_spin.value = wand.cast_delay
	_recharge_spin.value = wand.recharge_time
	_capacity_spin.value = wand.capacity
	_spread_spin.value = wand.spread_degrees
	_multicast_spin.value = wand.multicast
	_shuffle_check.button_pressed = wand.shuffle
	_stats_updating = false
	_refresh_wand_deck()

func _refresh_wand_selector_buttons() -> void:
	for index: int in range(_wand_buttons.size()):
		var wand: WandDef = _inventory.wands[index] if _inventory != null and index < _inventory.wands.size() else null
		_wand_buttons[index].text = "%d  %s" % [index + 1, wand.display_name if wand != null else "EMPTY"]
		PaintingCreativeStyle.style_tab_button(_wand_buttons[index], index == _selected_wand_index)

func _refresh_wand_deck() -> void:
	_clear_children(_wand_deck_grid)
	var wand: WandDef = _selected_wand()
	if wand == null:
		return
	if _inventory != null:
		_inventory.normalize_wand_runtime(wand)
	for slot_index: int in range(wand.capacity):
		_add_creative_wand_slot(_wand_deck_grid, wand, slot_index, str(slot_index + 1))

func _add_creative_wand_slot(parent: Control, wand: WandDef, slot_index: int, index_text: String) -> void:
	var resource: Resource = wand.spells[slot_index] if slot_index < wand.spells.size() else null
	var spell: SpellDef = resource as SpellDef if resource is SpellDef else null
	var slot: SpellSlot = spell_slot_scene.instantiate() as SpellSlot
	slot.setup({"area": &"wand", "wand": _selected_wand_index, "slot": slot_index}, spell, index_text, index_text.is_empty(), true)
	slot.spell_dropped.connect(_on_wand_spell_moved)
	slot.creative_spell_dropped.connect(_on_creative_spell_dropped)
	slot.drag_visual_started.connect(_show_drag_visual)
	parent.add_child(slot)

func _on_wand_stat_changed_float(_value: float) -> void:
	_apply_wand_stats()

func _on_wand_stat_changed_bool(_value: bool) -> void:
	_apply_wand_stats()

func _on_wand_capacity_changed(_value: float) -> void:
	_apply_wand_stats()
	call_deferred("_refresh_wand_deck")
	call_deferred("_refresh_target_deck")

func _apply_wand_stats() -> void:
	if _stats_updating or _selected_wand() == null:
		return
	_wand_service.update_stats(
		_selected_wand_index,
		_mana_max_spin.value,
		_mana_recharge_spin.value,
		_cast_delay_spin.value,
		_recharge_spin.value,
		int(_capacity_spin.value),
		_spread_spin.value,
		int(_multicast_spin.value),
		_shuffle_check.button_pressed
	)

func _select_creative_wand(index: int) -> void:
	_selected_wand_index = clampi(index, 0, 3)
	_refresh_spell_wand_buttons()
	if _active_tab == &"spells":
		_refresh_target_deck()
	if _active_tab == &"wands":
		_refresh_wand_panel()

func _wand_action(action: StringName) -> void:
	match action:
		&"equip":
			if _inventory != null:
				_inventory.equip_wand(_selected_wand_index)
		&"new":
			if _selected_wand() == null:
				_wand_service.create_blank_wand(_selected_wand_index)
		&"duplicate":
			var target: int = _first_empty_wand_slot()
			if target >= 0 and _selected_wand() != null:
				_wand_service.duplicate_wand(_selected_wand_index, target)
				_selected_wand_index = target
		&"delete":
			_wand_service.delete_wand(_selected_wand_index)
		&"clear":
			_wand_service.clear_spells(_selected_wand_index)
	_refresh_wand_panel()
	_refresh_spell_wand_buttons()

func _first_empty_wand_slot() -> int:
	if _inventory == null:
		return -1
	for index: int in range(_inventory.wands.size()):
		if _inventory.wands[index] == null:
			return index
	return -1

func _selected_wand() -> WandDef:
	if _inventory == null or _selected_wand_index < 0 or _selected_wand_index >= _inventory.wands.size():
		return null
	return _inventory.wands[_selected_wand_index]

func _on_wand_spell_moved(source: Dictionary, target: Dictionary) -> void:
	if _inventory != null and _inventory.move_spell(source, target):
		call_deferred("_refresh_wand_deck")
		call_deferred("_refresh_target_deck")

func _on_creative_spell_dropped(spell: SpellDef, target: Dictionary) -> void:
	if StringName(target.get("area", &"")) != &"wand":
		return
	var wand_index: int = int(target.get("wand", _selected_wand_index))
	var slot_index: int = int(target.get("slot", -1))
	if _wand_service.set_spell(wand_index, slot_index, spell):
		call_deferred("_refresh_wand_deck")
		call_deferred("_refresh_target_deck")

func _refresh_entity_grid() -> void:
	_clear_children(_entity_grid)
	_entity_tiles.clear()
	for definition: CreativeEntityDef in _creative_entities():
		if definition == null:
			continue
		var tile: CreativeEntityTile = entity_tile_scene.instantiate() as CreativeEntityTile
		tile.setup(definition)
		tile.entity_activated.connect(_select_entity_definition)
		_entity_grid.add_child(tile)
		_entity_tiles[definition.entity_id] = tile
	_refresh_entity_panel()

func _refresh_entity_panel() -> void:
	if _entity_controller == null:
		return
	var definition: CreativeEntityDef = _entity_controller.selected_entity
	_selected_entity_label.text = "SELECTED: %s" % (definition.display_name.to_upper() if definition != null else "NONE")
	PaintingCreativeStyle.style_tab_button(_entity_spawn_button, _entity_controller.selected_tool == CreativeEntityController.Tool.SPAWN)
	PaintingCreativeStyle.style_tab_button(_entity_delete_button, _entity_controller.selected_tool == CreativeEntityController.Tool.DELETE)
	for key: Variant in _entity_tiles.keys():
		var tile: CreativeEntityTile = _entity_tiles.get(key, null) as CreativeEntityTile
		if tile != null:
			tile.set_selected_state(definition != null and StringName(key) == definition.entity_id and _entity_controller.selected_tool == CreativeEntityController.Tool.SPAWN)

func _select_entity_tool(tool: int) -> void:
	if _entity_controller == null:
		return
	_entity_controller.set_tool(tool)
	_refresh_entity_panel()

func _select_entity_definition(definition: CreativeEntityDef) -> void:
	if _entity_controller == null:
		return
	_entity_controller.set_selected_entity(definition)
	_refresh_entity_panel()

func _clear_spawned_entities() -> void:
	if _entity_controller != null:
		_entity_controller.clear_spawned_entities()

func _refresh_world_panel() -> void:
	if _world_service == null:
		return
	var paused: bool = _world_service.is_simulation_paused()
	var speed: float = _world_service.simulation_speed()
	_pause_simulation.set_pressed_no_signal(paused)
	_step_simulation.disabled = not paused
	for index: int in range(_simulation_speed.item_count):
		var metadata: Variant = _simulation_speed.get_item_metadata(index)
		if metadata is float and is_equal_approx(float(metadata), speed):
			_simulation_speed.select(index)
			break
	_simulation_status.text = "%s • %.2fx" % ["PAUSED" if paused else "LIVE", speed]

func _on_simulation_paused_changed(paused: bool) -> void:
	if _world_service == null:
		return
	_world_service.set_simulation_paused(paused)
	_refresh_world_panel()

func _step_world_simulation() -> void:
	if _world_service == null:
		return
	_world_service.step_simulation()
	_refresh_world_panel()

func _on_simulation_speed_selected(index: int) -> void:
	if _world_service == null or index < 0 or index >= _simulation_speed.item_count:
		return
	var metadata: Variant = _simulation_speed.get_item_metadata(index)
	if metadata is float:
		_world_service.set_simulation_speed(float(metadata))
	_refresh_world_panel()

func _refresh_player_panel() -> void:
	var rules: GameRules = _mode_manager.active_rules() if _mode_manager != null else null
	if rules == null:
		return
	_invulnerable_toggle.set_pressed_no_signal(rules.invulnerable)
	_infinite_mana_toggle.set_pressed_no_signal(rules.infinite_mana)
	_infinite_flight_toggle.set_pressed_no_signal(rules.infinite_flight)
	_creative_fly_toggle.set_pressed_no_signal(rules.creative_fly)

func _toggle_rule(enabled: bool, property_name: StringName) -> void:
	if _mode_manager != null:
		_mode_manager.set_rule(property_name, enabled)

func _heal_player() -> void:
	if _player != null and _player.has_method("heal"):
		_player.call("heal", 100000.0)

func _clear_player_status() -> void:
	if _player == null:
		return
	var status: StatusComponent = _player.get_node_or_null("StatusComponent") as StatusComponent
	if status != null:
		status.clear_all()

func _show_drag_visual(spell: SpellDef) -> void:
	if spell == null:
		return
	_drag_icon.texture = SpellIconRegistry.texture_for_spell(spell)
	_drag_panel.visible = true
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_drag_panel.position = viewport.get_mouse_position() + Vector2(14.0, 14.0)

func _clear_children(control: Node) -> void:
	for child: Node in control.get_children():
		control.remove_child(child)
		child.queue_free()
