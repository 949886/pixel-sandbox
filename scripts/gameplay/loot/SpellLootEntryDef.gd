class_name SpellLootEntryDef
extends LootEntryDef

@export_range(0, 99, 1) var maximum_tier: int = 99


func is_valid() -> bool:
	return super.is_valid() and payload_property != &""


func roll_payload(content: GameplayContentDB, rng: RandomNumberGenerator) -> Variant:
	if content == null or content.spell_catalog == null:
		return null
	return content.spell_catalog.random_spell(rng, maximum_tier)
