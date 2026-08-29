extends Node


func _ready() -> void:
	_test_explicit_zero_seed()
	_test_world_config_isolation()
	_test_material_palette_isolation()
	_test_starting_loadout_preserves_wand_decks()
	_test_multiplayer_shaped_readiness()
	print("Game Bootstrap Smoke Test: PASS")
	get_tree().quit()


func _test_explicit_zero_seed() -> void:
	var config := GameConfig.create_with_seed(0, &"test")
	assert(config != null)
	assert(config.is_valid())
	assert(config.seed == 0)


func _test_world_config_isolation() -> void:
	var template := WorldGenConfig.new()
	template.world_seed = 20260706
	var shared_library := PieceLibrary.new()
	template.piece_library = shared_library

	var runtime := GameBootstrap.create_runtime_world_config(template, 42)
	var second_runtime := GameBootstrap.create_runtime_world_config(template, 42)
	assert(runtime != null)
	assert(second_runtime != null)
	assert(runtime != template)
	assert(second_runtime != template)
	assert(second_runtime != runtime)
	assert(runtime.world_seed == 42)
	assert(second_runtime.world_seed == 42)
	assert(template.world_seed == 20260706)
	assert(runtime.piece_library == shared_library)
	assert(second_runtime.piece_library == shared_library)
	assert(template.piece_library == shared_library)


func _test_material_palette_isolation() -> void:
	var template := MaterialPalette.new()
	var runtime := GameBootstrap.create_runtime_material_palette(template)
	var second_runtime := GameBootstrap.create_runtime_material_palette(template)
	assert(runtime != null)
	assert(second_runtime != null)
	assert(runtime != template)
	assert(second_runtime != template)
	assert(second_runtime != runtime)

	# MaterialPalette owns mutable lookup caches. Building a runtime cache must
	# not mutate the shared .tres/template instance or another Game's copy.
	runtime.rebuild_cache()
	assert(runtime._cache_ready)
	assert(not template._cache_ready)
	assert(not second_runtime._cache_ready)


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

	# Bootstrap applies loadout before Player enters the SceneTree. Exercise that
	# public Player API directly so it cannot accidentally depend on @onready.
	var player := Player.new()
	var controller := WandController.new()
	controller.name = "WandController"
	player.add_child(controller)
	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	player.add_child(inventory)

	assert(player.apply_starting_loadout(loadout))
	assert(player.is_starting_loadout_applied())
	assert(player.starting_gold == 123)
	assert(player.gold == 123)
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

	player.free()


func _test_multiplayer_shaped_readiness() -> void:
	var bootstrap := GameBootstrap.new()
	var player_ids: Array[int] = [1, 2]
	assert(bootstrap._reset_readiness(player_ids))
	assert(not bootstrap._is_gameplay_ready())
	bootstrap._mark_world_ready()
	assert(not bootstrap._is_gameplay_ready())
	assert(bootstrap._mark_player_ready(1))
	assert(bootstrap._mark_player_ready(1))
	assert(not bootstrap._is_gameplay_ready())
	assert(not bootstrap._mark_player_ready(999))
	assert(bootstrap._mark_player_ready(2))
	assert(bootstrap._is_gameplay_ready())

	# Resetting for a new startup clears prior world/player readiness and keeps
	# the required player IDs order-independent.
	var reversed_player_ids: Array[int] = [2, 1]
	assert(bootstrap._reset_readiness(reversed_player_ids))
	assert(not bootstrap._is_gameplay_ready())
	assert(bootstrap._mark_player_ready(2))
	assert(bootstrap._mark_player_ready(1))
	assert(not bootstrap._is_gameplay_ready())
	bootstrap._mark_world_ready()
	assert(bootstrap._is_gameplay_ready())
	bootstrap.free()
