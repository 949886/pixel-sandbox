class_name StartingLoadoutDef
extends Resource

@export var primary_wand: WandDef
@export var primary_spells: Array[Resource] = []
@export var extra_wands: Array[WandDef] = []
@export var inventory_spells: Array[Resource] = []
@export_range(0, 999999, 1) var starting_gold: int = 0


func is_valid() -> bool:
	if primary_wand == null:
		return false
	if starting_gold < 0:
		return false
	if primary_spells.size() > maxi(1, primary_wand.capacity):
		return false
	for spell_resource: Resource in primary_spells:
		if spell_resource != null and not spell_resource is SpellDef:
			return false
	for wand: WandDef in extra_wands:
		if wand == null:
			return false
	for spell_resource: Resource in inventory_spells:
		if spell_resource != null and not spell_resource is SpellDef:
			return false
	return true
