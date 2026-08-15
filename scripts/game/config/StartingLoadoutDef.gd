class_name StartingLoadoutDef
extends Resource

@export var starting_wands: Array[WandDef] = []
@export var starting_spells: Array[SpellDef] = []
@export var starting_gold: int = 0


func is_valid() -> bool:
	if starting_gold < 0:
		return false
	for wand: WandDef in starting_wands:
		if wand == null:
			return false
	for spell: SpellDef in starting_spells:
		if spell == null:
			return false
	return true
