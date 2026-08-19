class_name StartingLoadoutDef
extends Resource

@export var wands: Array[Resource] = []
@export var spells: Array[Resource] = []
@export_range(0, 999999, 1) var gold: int = 0


func is_valid() -> bool:
	if wands.is_empty():
		return false
	if gold < 0:
		return false
	for wand_resource: Resource in wands:
		if not wand_resource is WandDef:
			return false
	for spell_resource: Resource in spells:
		if spell_resource != null and not spell_resource is SpellDef:
			return false
	return true
