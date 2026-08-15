extends Node


func _ready() -> void:
	_test_explicit_zero_seed()
	_test_world_config_isolation()
	_test_starting_loadout_replaces_wand_deck()
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


func _test_starting_loadout_replaces_wand_deck() -> void:
	var old_spell := SpellDef.new()
	var spell_a := SpellDef.new()
	var spell_b := SpellDef.new()
	var source_wand := WandDef.new()
	source_wand.capacity = 2
	var source_spells: Array[Resource] = [old_spell]
	source_wand.spells = source_spells

	var loadout := StartingLoadoutDef.new()
	loadout.primary_wand = source_wand
	var starting_spells: Array[Resource] = [spell_a, spell_b]
	loadout.primary_spells = starting_spells
	assert(loadout.is_valid())

	var controller := WandController.new()
	controller.name = "WandController"
	add_child(controller)
	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	add_child(inventory)
	inventory.initialize(controller)

	assert(inventory.apply_starting_loadout(loadout))
	var runtime_wand := inventory.equipped_wand()
	assert(runtime_wand != null)
	assert(runtime_wand != source_wand)
	assert(runtime_wand.spells.size() == 2)
	assert(runtime_wand.spells[0] == spell_a)
	assert(runtime_wand.spells[1] == spell_b)
	assert(source_wand.spells.size() == 1)
	assert(source_wand.spells[0] == old_spell)

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
