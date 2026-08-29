class_name RewardProfile
extends Resource

## Composes reward sources without knowing the consumer (enemy, chest, shrine,
## encounter, boss...). Future reward executors should consume this Resource.
@export var reward_id: StringName = &""
@export var loot_table: LootTableDef
@export var wand_generation_profile_id: StringName = &""
@export_range(0, 16, 1) var wand_roll_count: int = 0


func is_valid(wand_catalog: WandGenerationCatalog) -> bool:
	if reward_id == &"":
		return false
	if loot_table != null and not loot_table.is_valid():
		return false
	if wand_roll_count > 0:
		return wand_generation_profile_id != &"" \
			and wand_catalog != null \
			and wand_catalog.get_profile(wand_generation_profile_id) != null
	return true
