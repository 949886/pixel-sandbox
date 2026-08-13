extends Node

func _ready() -> void:
	var wand_controller := WandController.new()
	wand_controller.wand_def = load("res://resources/gameplay/wands/starter_wand.tres") as WandDef
	add_child(wand_controller)
	var inventory := PlayerInventory.new()
	inventory.wand_slot_count = 4
	inventory.spell_inventory_capacity = 24
	inventory.secondary_test_wand = load("res://resources/gameplay/wands/high_performance_test_wand.tres") as WandDef
	add_child(inventory)
	inventory.initialize(wand_controller)

	assert(inventory.wands.size() == 4)
	assert(inventory.spell_inventory.size() == 24)
	assert(inventory.equipped_wand() != null)
	assert(inventory.wands[1] != null)
	assert(inventory.wands[1].wand_id == &"high_performance_test_wand")
	assert(inventory.wands[1].spells.size() == inventory.wands[1].capacity)
	assert(inventory.wands[1].visual_texture != null)
	assert(inventory.equipped_wand() != load("res://resources/gameplay/wands/starter_wand.tres"))
	assert(inventory.wand_capacity(0) == 24)
	assert(wand_controller.deck_size() == 24)

	var first_spell := inventory.wand_slot_spell(0, 0)
	assert(first_spell != null)
	assert(first_spell.spell_id == &"spark_bolt")
	var moved := inventory.move_spell(
		{"area": &"wand", "wand": 0, "slot": 0},
		{"area": &"inventory", "slot": 0}
	)
	assert(moved)
	assert(inventory.inventory_spell(0) == first_spell)
	assert(inventory.wand_slot_spell(0, 0) == null)
	assert(wand_controller.deck_size() == 23)

	var fireball := load("res://resources/gameplay/spells/luna/fireball.tres") as SpellDef
	assert(inventory.add_spell(fireball))
	assert(SpellIconRegistry.texture_for_spell(fireball) != null)
	assert(fireball.icon != null)
	assert(fireball.icon is AtlasTexture)
	assert(inventory.equip_wand(1))
	assert(wand_controller.wand_def == inventory.wands[1])
	assert(wand_controller.deck_size() == 0)
	assert(inventory.equip_wand(0))

	print("Gameplay UI / Inventory Smoke Test: PASS")
	get_tree().quit()
