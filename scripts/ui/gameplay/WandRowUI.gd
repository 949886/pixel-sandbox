class_name WandRowUI
extends PanelContainer

signal row_pressed(index: int)
signal hover_changed(index: int, hovering: bool)
signal slot_pressed(location: Dictionary)
signal spell_dropped(source: Dictionary, target: Dictionary)
signal slot_hover_changed(spell: SpellDef, location: Dictionary, hovering: bool)
signal quick_move_requested(location: Dictionary)
signal drag_visual_started(spell: SpellDef)

const SPELL_SLOT_SCENE: PackedScene = preload("res://scenes/ui/shared/SpellSlot.tscn")

var wand_index: int = 0
var wand: WandDef
var inventory: PlayerInventory
var active: bool = false
var equipped: bool = false
var selected_location: Dictionary = {}

@onready var _glyph_frame: PanelContainer = %GlyphFrame
@onready var _glyph: WandGlyph = %WandGlyph
@onready var _title: Label = %Title
@onready var _shuffle: Label = %Shuffle
@onready var _cast_count: Label = %CastCount
@onready var _spell_grid: GridContainer = %SpellGrid

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()

func setup(index: int, definition: WandDef, player_inventory: PlayerInventory, is_active: bool, is_equipped: bool, selected: Dictionary) -> void:
	wand_index = index
	wand = definition
	inventory = player_inventory
	active = is_active
	equipped = is_equipped
	selected_location = selected.duplicate(true)
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if wand == null or inventory == null:
		return
	add_theme_stylebox_override("panel", NoitaUITheme.highlighted_box() if active else NoitaUITheme.box(NoitaUITheme.BG, NoitaUITheme.BORDER, 1))
	_glyph_frame.add_theme_stylebox_override("panel", NoitaUITheme.box(NoitaUITheme.BG_SLOT, NoitaUITheme.AMBER if equipped else NoitaUITheme.BORDER_DIM, 1))
	_glyph.setup(wand, equipped)
	_title.text = "%d  %s" % [wand_index + 1, wand.display_name]
	_shuffle.text = "Shuffle       %s" % ("Yes" if wand.shuffle else "No")
	_cast_count.text = "Spells/Cast   %d" % maxi(1, wand.multicast)
	_clear_children(_spell_grid)
	for slot_index: int in range(inventory.wand_capacity(wand_index)):
		var location: Dictionary = {"area": &"wand", "wand": wand_index, "slot": slot_index}
		var slot: SpellSlot = SPELL_SLOT_SCENE.instantiate() as SpellSlot
		slot.setup(location, inventory.wand_slot_spell(wand_index, slot_index), "", false)
		slot.set_selected(not selected_location.is_empty() and _same_location(selected_location, location))
		slot.slot_pressed.connect(func(loc: Dictionary) -> void: slot_pressed.emit(loc))
		slot.spell_dropped.connect(func(source: Dictionary, target: Dictionary) -> void: spell_dropped.emit(source, target))
		slot.hover_changed.connect(func(spell: SpellDef, loc: Dictionary, hovering: bool) -> void: slot_hover_changed.emit(spell, loc, hovering))
		slot.quick_move_requested.connect(func(loc: Dictionary) -> void: quick_move_requested.emit(loc))
		slot.drag_visual_started.connect(func(spell: SpellDef) -> void: drag_visual_started.emit(spell))
		_spell_grid.add_child(slot)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			row_pressed.emit(wand_index)

func _on_mouse_entered() -> void:
	hover_changed.emit(wand_index, true)

func _on_mouse_exited() -> void:
	hover_changed.emit(wand_index, false)

func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _same_location(a: Dictionary, b: Dictionary) -> bool:
	return StringName(a.get("area", &"")) == StringName(b.get("area", &"")) and int(a.get("slot", -1)) == int(b.get("slot", -1)) and int(a.get("wand", -1)) == int(b.get("wand", -1))
