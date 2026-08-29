class_name GoldLootEntryDef
extends LootEntryDef

@export_range(1, 999999, 1) var value_min: int = 1
@export_range(1, 999999, 1) var value_max: int = 1


func is_valid() -> bool:
	return super.is_valid() and payload_property != &"" and value_min > 0 and value_max > 0


func roll_payload(_content: GameplayContentDB, rng: RandomNumberGenerator) -> Variant:
	var low := mini(value_min, value_max)
	var high := maxi(value_min, value_max)
	return rng.randi_range(low, high) if rng != null else low
