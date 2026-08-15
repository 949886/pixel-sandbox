class_name StartingLoadoutApplicator
extends RefCounted

const WAND_CONTROLLER_PATH := NodePath("WandController")
const INVENTORY_PATH := NodePath("PlayerInventory")


static func apply_to_player(player: Node, loadout: StartingLoadoutDef) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if loadout == null or not loadout.is_valid():
		return false

	var wand_controller := player.get_node_or_null(WAND_CONTROLLER_PATH) as WandController
	var inventory := player.get_node_or_null(INVENTORY_PATH) as PlayerInventory
	if wand_controller == null or inventory == null:
		return false
	if inventory.wands.size() < loadout.starting_wands.size():
		return false
	if inventory.spell_inventory.size() < loadout.starting_spells.size():
		return false
	if not _inventory_is_empty(inventory) or wand_controller.wand_def != null:
		return false
	if not _has_property(player, &"gold") or int(player.get("gold")) != 0:
		return false
	if loadout.starting_gold > 0 and not player.has_method(&"add_gold"):
		return false

	for wand: WandDef in loadout.starting_wands:
		if not inventory.add_wand(wand):
			return false

	if not loadout.starting_wands.is_empty() and not inventory.equip_wand(0):
		return false

	for spell: SpellDef in loadout.starting_spells:
		if not inventory.add_spell(spell):
			return false

	if loadout.starting_gold > 0:
		player.call(&"add_gold", loadout.starting_gold)

	return int(player.get("gold")) == loadout.starting_gold


static func _inventory_is_empty(inventory: PlayerInventory) -> bool:
	for wand: WandDef in inventory.wands:
		if wand != null:
			return false
	for spell: SpellDef in inventory.spell_inventory:
		if spell != null:
			return false
	return true


static func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
