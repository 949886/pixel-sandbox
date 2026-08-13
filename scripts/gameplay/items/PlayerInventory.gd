class_name PlayerInventory
extends Node

signal inventory_changed
signal wand_slots_changed
signal equipped_wand_changed(index: int, wand: WandDef)
signal spell_added(spell: SpellDef)
signal spell_removed(spell: SpellDef)
signal inventory_full(spell: SpellDef)

@export_range(1, 8, 1) var wand_slot_count: int = 4
@export_range(4, 64, 1) var spell_inventory_capacity: int = 24
@export var secondary_test_wand: WandDef

var wands: Array[WandDef] = []
var spell_inventory: Array[SpellDef] = []
var equipped_wand_index: int = 0
var _wand_controller: WandController

func _ready() -> void:
	_resize_storage()

func initialize(wand_controller: WandController) -> void:
	_wand_controller = wand_controller
	_resize_storage()
	if _wand_controller == null:
		return
	if wands[0] == null and _wand_controller.wand_def != null:
		wands[0] = _duplicate_wand(_wand_controller.wand_def)
		equipped_wand_index = 0
		_wand_controller.set_wand_definition(wands[0], true)
	if wands.size() > 1 and wands[1] == null and secondary_test_wand != null:
		wands[1] = _duplicate_wand(secondary_test_wand)
	wand_slots_changed.emit()
	inventory_changed.emit()
	equipped_wand_changed.emit(equipped_wand_index, equipped_wand())

func equipped_wand() -> WandDef:
	if equipped_wand_index < 0 or equipped_wand_index >= wands.size():
		return null
	return wands[equipped_wand_index]

func equip_wand(index: int) -> bool:
	if index < 0 or index >= wands.size() or wands[index] == null:
		return false
	equipped_wand_index = index
	if _wand_controller != null:
		_wand_controller.set_wand_definition(wands[index], true)
	equipped_wand_changed.emit(index, wands[index])
	wand_slots_changed.emit()
	inventory_changed.emit()
	return true

func add_wand(wand: WandDef) -> bool:
	if wand == null:
		return false
	for index: int in range(wands.size()):
		if wands[index] == null:
			wands[index] = _duplicate_wand(wand)
			wand_slots_changed.emit()
			inventory_changed.emit()
			return true
	return false

func add_spell(spell: SpellDef) -> bool:
	if spell == null:
		return false
	for index: int in range(spell_inventory.size()):
		if spell_inventory[index] == null:
			spell_inventory[index] = spell
			spell_added.emit(spell)
			inventory_changed.emit()
			return true
	inventory_full.emit(spell)
	return false

func remove_inventory_spell(index: int) -> SpellDef:
	if index < 0 or index >= spell_inventory.size():
		return null
	var spell := spell_inventory[index]
	spell_inventory[index] = null
	if spell != null:
		spell_removed.emit(spell)
		inventory_changed.emit()
	return spell

func spell_at(location: Dictionary) -> SpellDef:
	var area := StringName(location.get("area", &""))
	var slot := int(location.get("slot", -1))
	if area == &"inventory":
		return spell_inventory[slot] if slot >= 0 and slot < spell_inventory.size() else null
	if area == &"wand":
		var wand_index := int(location.get("wand", equipped_wand_index))
		if wand_index < 0 or wand_index >= wands.size():
			return null
		var wand := wands[wand_index]
		if wand == null:
			return null
		_normalize_wand_slots(wand)
		if slot < 0 or slot >= wand.spells.size():
			return null
		var resource: Resource = wand.spells[slot]
		return resource as SpellDef if resource is SpellDef else null
	return null

func move_spell(source: Dictionary, target: Dictionary) -> bool:
	if not _location_valid(source) or not _location_valid(target):
		return false
	if source == target:
		return true
	var source_spell := spell_at(source)
	if source_spell == null:
		return false
	var target_spell := spell_at(target)
	if not _set_spell_at(source, target_spell):
		return false
	if not _set_spell_at(target, source_spell):
		_set_spell_at(source, source_spell)
		return false
	_refresh_wands_touched(source, target)
	inventory_changed.emit()
	return true

func clear_spell(location: Dictionary) -> SpellDef:
	var spell := spell_at(location)
	if spell == null:
		return null
	if not _set_spell_at(location, null):
		return null
	_refresh_wands_touched(location, {})
	inventory_changed.emit()
	return spell

func wand_slot_spell(wand_index: int, slot_index: int) -> SpellDef:
	return spell_at({"area": &"wand", "wand": wand_index, "slot": slot_index})

func inventory_spell(slot_index: int) -> SpellDef:
	return spell_at({"area": &"inventory", "slot": slot_index})

func wand_capacity(wand_index: int) -> int:
	if wand_index < 0 or wand_index >= wands.size() or wands[wand_index] == null:
		return 0
	return maxi(1, wands[wand_index].capacity)

func _set_spell_at(location: Dictionary, spell: SpellDef) -> bool:
	var area := StringName(location.get("area", &""))
	var slot := int(location.get("slot", -1))
	if area == &"inventory":
		if slot < 0 or slot >= spell_inventory.size():
			return false
		spell_inventory[slot] = spell
		return true
	if area == &"wand":
		var wand_index := int(location.get("wand", equipped_wand_index))
		if wand_index < 0 or wand_index >= wands.size():
			return false
		var wand := wands[wand_index]
		if wand == null:
			return false
		_normalize_wand_slots(wand)
		if slot < 0 or slot >= wand.spells.size():
			return false
		wand.spells[slot] = spell
		return true
	return false

func _location_valid(location: Dictionary) -> bool:
	var area := StringName(location.get("area", &""))
	var slot := int(location.get("slot", -1))
	if area == &"inventory":
		return slot >= 0 and slot < spell_inventory.size()
	if area == &"wand":
		var wand_index := int(location.get("wand", equipped_wand_index))
		return wand_index >= 0 and wand_index < wands.size() and wands[wand_index] != null and slot >= 0 and slot < wand_capacity(wand_index)
	return false

func _refresh_wands_touched(a: Dictionary, b: Dictionary) -> void:
	var touched: Dictionary = {}
	for location_variant: Variant in [a, b]:
		if not location_variant is Dictionary:
			continue
		var location: Dictionary = location_variant
		if StringName(location.get("area", &"")) == &"wand":
			touched[int(location.get("wand", equipped_wand_index))] = true
	for wand_index_variant in touched.keys():
		var wand_index := int(wand_index_variant)
		if wand_index == equipped_wand_index and _wand_controller != null:
			_wand_controller.refresh_definition(true)
	wand_slots_changed.emit()

func _resize_storage() -> void:
	while wands.size() < wand_slot_count:
		wands.append(null)
	if wands.size() > wand_slot_count:
		wands.resize(wand_slot_count)
	while spell_inventory.size() < spell_inventory_capacity:
		spell_inventory.append(null)
	if spell_inventory.size() > spell_inventory_capacity:
		spell_inventory.resize(spell_inventory_capacity)

func _normalize_wand_slots(wand: WandDef) -> void:
	if wand == null:
		return
	var capacity := maxi(1, wand.capacity)
	while wand.spells.size() < capacity:
		wand.spells.append(null)
	if wand.spells.size() > capacity:
		wand.spells.resize(capacity)

func _duplicate_wand(source: WandDef) -> WandDef:
	if source == null:
		return null
	# The wand itself is runtime-owned, but SpellDef resources remain immutable and
	# shared. This avoids duplicating the entire effect graph for every inventory slot.
	var clone := source.duplicate(false) as WandDef
	if clone == null:
		return source
	var spell_copy: Array[Resource] = []
	spell_copy.assign(source.spells)
	clone.spells = spell_copy
	var precast_copy: Array[Resource] = []
	precast_copy.assign(source.precast_spells)
	clone.precast_spells = precast_copy
	_normalize_wand_slots(clone)
	return clone

func set_wand_runtime(index: int, wand: WandDef) -> bool:
	if index < 0 or index >= wands.size():
		return false
	wands[index] = wand
	if wand != null:
		normalize_wand_runtime(wand)
	if index == equipped_wand_index and _wand_controller != null:
		if wand != null:
			_wand_controller.set_wand_definition(wand, true)
		else:
			var fallback: int = _first_available_wand_index()
			if fallback >= 0:
				equip_wand(fallback)
	wand_slots_changed.emit()
	inventory_changed.emit()
	return true

func duplicate_wand_to_slot(source_index: int, target_index: int) -> bool:
	if source_index < 0 or source_index >= wands.size() or target_index < 0 or target_index >= wands.size():
		return false
	var source: WandDef = wands[source_index]
	if source == null:
		return false
	return set_wand_runtime(target_index, _duplicate_wand(source))

func remove_wand(index: int) -> bool:
	if index < 0 or index >= wands.size() or wands[index] == null:
		return false
	var occupied: int = 0
	for wand: WandDef in wands:
		if wand != null:
			occupied += 1
	if occupied <= 1:
		return false
	wands[index] = null
	if equipped_wand_index == index:
		var fallback: int = _first_available_wand_index()
		if fallback >= 0:
			equip_wand(fallback)
	wand_slots_changed.emit()
	inventory_changed.emit()
	return true

func normalize_wand_runtime(wand: WandDef) -> void:
	_normalize_wand_slots(wand)

func set_wand_spell_runtime(wand_index: int, slot_index: int, spell: SpellDef) -> bool:
	if wand_index < 0 or wand_index >= wands.size():
		return false
	var wand: WandDef = wands[wand_index]
	if wand == null:
		return false
	_normalize_wand_slots(wand)
	if slot_index < 0 or slot_index >= wand.spells.size():
		return false
	wand.spells[slot_index] = spell
	notify_wand_runtime_changed(wand_index, true)
	return true

func notify_wand_runtime_changed(index: int, preserve_mana: bool = true) -> void:
	if index == equipped_wand_index and _wand_controller != null:
		_wand_controller.refresh_definition(preserve_mana)
	wand_slots_changed.emit()
	inventory_changed.emit()

func _first_available_wand_index() -> int:
	for index: int in range(wands.size()):
		if wands[index] != null:
			return index
	return -1
