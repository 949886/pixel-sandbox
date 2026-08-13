extends Node

func _ready() -> void:
	var rules: GameRules = load("res://resources/gameplay/modes/creative_rules.tres") as GameRules
	assert(rules != null)
	assert(rules.invulnerable)
	assert(rules.infinite_mana)
	assert(rules.infinite_flight)
	assert(rules.creative_fly)
	assert(rules.allow_world_editing)
	assert(rules.allow_wand_lab)
	var spells: Array[SpellDef] = SpellCatalog.all_spells()
	assert(spells.size() >= 32)
	var wand_service: CreativeWandService = CreativeWandService.new()
	assert(wand_service != null)
	print("Creative Mode Smoke Test: PASS")
	get_tree().quit()
