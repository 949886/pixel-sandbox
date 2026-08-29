extends Node

func _ready() -> void:
	var content := load("res://resources/gameplay/gameplay_content.tres") as GameplayContentDB
	assert(content != null)
	assert(content.is_valid())
	assert(content.flow_catalog.get_flow(content.default_flow_id) != null)
	assert(content.spell_catalog.all_spells().size() >= 32)

	var cave_eye := content.enemy_catalog.get_enemy(&"cave_eye")
	assert(cave_eye != null)
	assert(cave_eye.scene != null)
	assert(cave_eye.placement_tags.has(&"air"))

	var encounter := content.encounter_catalog.get_encounter(&"mine_cave_eye")
	assert(encounter != null)
	assert(encounter.is_valid(content.enemy_catalog))
	assert(encounter.entries[0].enemy_id == cave_eye.enemy_id)

	var wand_profile := content.wand_generation_catalog.get_profile(&"mine_common")
	assert(wand_profile != null and wand_profile.is_valid())
	var reward := content.reward_catalog.get_reward(&"cave_eye_reward")
	assert(reward != null and reward.is_valid(content.wand_generation_catalog))

	var enemy_instance := cave_eye.scene.instantiate() as CaveEye
	assert(enemy_instance != null)
	assert(enemy_instance.tuning != null and enemy_instance.tuning.is_valid())
	assert(enemy_instance.tuning.loot_table != null and enemy_instance.tuning.loot_table.is_valid())
	enemy_instance.free()

	var palette := load("res://resources/materials/default_material_palette.tres") as MaterialPalette
	assert(palette != null)
	palette.rebuild_cache()
	assert(palette.gameplay_tags_for_element_id(3).has(&"water"))
	assert(palette.gameplay_tags_for_element_id(20).has(&"lava"))
	assert(palette.gameplay_tags_for_element_id(30).has(&"oil"))

	var world_config := load("res://resources/world_gen/default_world_gen_config.tres") as WorldGenConfig
	assert(world_config != null and world_config.is_valid())
	assert(world_config.get_biome_config(&"mine") != null)
	assert(world_config.get_biome_config(&"snow") != null)
	assert(world_config.get_biome_config(&"deep") != null)

	print("Gameplay Content Smoke Test: PASS")
	get_tree().quit()
