class_name CreativeWandService
extends RefCounted

const DEFAULT_WAND_TEXTURE: Texture2D = preload("res://assets/player/wand.png")

var inventory: PlayerInventory
var wand_controller: WandController

func configure(player_inventory: PlayerInventory, controller: WandController) -> void:
	inventory = player_inventory
	wand_controller = controller

func create_blank_wand(slot_index: int) -> WandDef:
	if inventory == null or slot_index < 0 or slot_index >= inventory.wands.size():
		return null
	var wand: WandDef = WandDef.new()
	wand.wand_id = StringName("creative_wand_%d" % (slot_index + 1))
	wand.display_name = "Creative Wand %d" % (slot_index + 1)
	wand.visual_texture = DEFAULT_WAND_TEXTURE
	wand.visual_modulate = Color(0.70, 0.95, 1.0, 1.0)
	wand.mana_max = 1000.0
	wand.mana_recharge_per_second = 500.0
	wand.cast_delay = 0.05
	wand.recharge_time = 0.15
	wand.multicast = 1
	wand.capacity = 12
	wand.shuffle = false
	wand.spread_degrees = 0.0
	wand.spells = []
	inventory.set_wand_runtime(slot_index, wand)
	return wand

func duplicate_wand(source_index: int, target_index: int) -> bool:
	if inventory == null:
		return false
	return inventory.duplicate_wand_to_slot(source_index, target_index)

func delete_wand(slot_index: int) -> bool:
	if inventory == null:
		return false
	return inventory.remove_wand(slot_index)

func clear_spells(slot_index: int) -> void:
	var wand: WandDef = _wand(slot_index)
	if wand == null:
		return
	wand.spells.clear()
	inventory.normalize_wand_runtime(wand)
	inventory.notify_wand_runtime_changed(slot_index, false)

func set_spell(slot_index: int, spell_index: int, spell: SpellDef) -> bool:
	if inventory == null:
		return false
	return inventory.set_wand_spell_runtime(slot_index, spell_index, spell)

func add_spell_first_empty(slot_index: int, spell: SpellDef) -> bool:
	if spell == null:
		return false
	var wand: WandDef = _wand(slot_index)
	if wand == null:
		return false
	inventory.normalize_wand_runtime(wand)
	for index: int in range(wand.spells.size()):
		if wand.spells[index] == null:
			wand.spells[index] = spell
			inventory.notify_wand_runtime_changed(slot_index, true)
			return true
	return false

func update_stats(
	slot_index: int,
	mana_max: float,
	mana_recharge: float,
	cast_delay: float,
	recharge_time: float,
	capacity: int,
	spread_degrees: float,
	multicast: int,
	shuffle: bool
) -> void:
	var wand: WandDef = _wand(slot_index)
	if wand == null:
		return
	wand.mana_max = maxf(0.0, mana_max)
	wand.mana_recharge_per_second = maxf(0.0, mana_recharge)
	wand.cast_delay = maxf(0.0, cast_delay)
	wand.recharge_time = maxf(0.0, recharge_time)
	wand.capacity = clampi(capacity, 1, 64)
	wand.spread_degrees = clampf(spread_degrees, -180.0, 180.0)
	wand.multicast = clampi(multicast, 1, 16)
	wand.shuffle = shuffle
	inventory.normalize_wand_runtime(wand)
	if slot_index == inventory.equipped_wand_index and wand_controller != null:
		wand_controller.refresh_definition(true)
	inventory.wand_slots_changed.emit()

func _wand(slot_index: int) -> WandDef:
	if inventory == null or slot_index < 0 or slot_index >= inventory.wands.size():
		return null
	return inventory.wands[slot_index]
