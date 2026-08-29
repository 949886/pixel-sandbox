class_name LootTableDef
extends Resource

@export var loot_id: StringName = &""
@export var entries: Array[LootEntryDef] = []


func is_valid() -> bool:
	if loot_id == &"" or entries.is_empty():
		return false
	for entry: LootEntryDef in entries:
		if entry == null or not entry.is_valid():
			return false
	return true
