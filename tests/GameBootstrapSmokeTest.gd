extends Node


func _ready() -> void:
	_test_explicit_zero_seed()
	_test_world_config_isolation()
	_test_starting_loadout_preserves_wand_decks()
	_test_multiplayer_shaped_readiness()
	print("Game Bootstrap Smoke Test: PASS")
	get_tree().quit()


func _test_explicit_zero_seed() -> void:
	var config := GameConfig.create_with_seed(0)
	assert(config != null)
	assert(config.is_valid())
	assert(config.seed == 0)


func _test_world_config_isolation() -> void:
	var template := WorldGenConfig.new()
	template.world_seed = 20260706
	var shared_library := PieceLibrary.new()
	template.piece_library = shared_library

	var runtime := GameBootstrap.create_runtime_world_config(template, 42)
	assert(runtime != null)
	assert(runtime != template)
	assert(runtime.world_seed == 42)
	assert(template.world_seed == 20260706)
	assert(runtime.piece_library == shared_library)
	assert(template.piece_library == shared_library)


func _test_starting_loadout_preserves_wand_decks() -> void:
	var spell_a := SpellDef.new()
	var spell_b := SpellDef.new()
	var loose_spell := SpellDef.new()

	var source_primary := WandDef.new()
	source_primary.capacity = 2
	var primary_spells: Array[Resource] = [spell_a, spell_b]
	source_primary.spells = primary_spells

	var source_extra := WandDef.new()
	source_extra.capacity = 1
	var extra_spells: Array[Resource] = [spell_b]
	source_extra.spells = extra_spells

	var loadout := StartingLoadoutDef.new()
	var starting_wands: Array[Resource] = [source_primary, source_extra]
	loadout.wands = starting_wands
	var inventory_spells: Array[Resource] = [loose_spell]
	loadout.spells = inventory_spells
	loadout.gold = 123
	assert(loadout.is_valid())

	var controller := WandController.new()
	controller.name = "WandController"
	add_child(controller)
	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	add_child(inventory)
	inventory.initialize(controller)

	assert(inventory.apply_starting_loadout(loadout))
	var runtime_primary := inventory.wands[0]
	var runtime_extra := inventory.wands[1]
	assert(runtime_primary != null)
	assert(runtime_extra != null)
	assert(runtime_primary != source_primary)
	assert(runtime_extra != source_extra)
	assert(runtime_primary.spells.size() == 2)
	assert(runtime_primary.spells[0] == spell_a)
	assert(runtime_primary.spells[1] == spell_b)
	assert(runtime_extra.spells.size() == 1)
	assert(runtime_extra.spells[0] == spell_b)
	assert(inventory.inventory_spell(0) == loose_spell)
	assert(source_primary.spells.size() == 2)
	assert(source_primary.spells[0] == spell_a)
	assert(source_primary.spells[1] == spell_b)

	inventory.queue_free()
	controller.queue_free()


func _test_multiplayer_shaped_readiness() -> void:
	var readiness := GameBootstrapReadiness.new()
	var player_ids: Array[int] = [1, 2]
	assert(readiness.reset(77, player_ids))
	assert(not readiness.is_ready(77))
	assert(readiness.mark_world_ready(77))
	assert(not readiness.is_ready(77))
	assert(readiness.mark_player_ready(77, 1))
	assert(readiness.mark_player_ready(77, 1))
	assert(not readiness.is_ready(77))
	assert(not readiness.mark_player_ready(78, 2))
	assert(not readiness.mark_player_ready(77, 999))
	assert(readiness.mark_player_ready(77, 2))
	assert(readiness.is_ready(77))

	assert(readiness.reset(88, player_ids))
	assert(readiness.mark_player_ready(88, 2))
	assert(readiness.mark_player_ready(88, 1))
	assert(not readiness.is_ready(88))
	assert(readiness.mark_world_ready(88))
	assert(readiness.is_ready(88))
