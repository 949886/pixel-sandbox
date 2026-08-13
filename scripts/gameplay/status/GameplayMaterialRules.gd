class_name GameplayMaterialRules
extends RefCounted

## Native sand-slide IDs that matter to the first gameplay slice. Palette-backed
## materials are also recognized by StringName so custom IDs remain portable.
const WATER_ID := 3
const FIRE_ID := 5
const LAVA_ID := 20
const ACID_ID := 21
const BLUE_FIRE_ID := 24
const OIL_ID := 30
const BURNING_OIL_ID := 50

static func tags_for(element_id: int, entry: MaterialEntry = null) -> Dictionary:
	var tags := {
		"liquid": false,
		"water": false,
		"oil": false,
		"fire": false,
		"lava": false,
		"toxic": false,
	}
	if entry != null:
		tags["liquid"] = entry.liquid
		match entry.id:
			&"water":
				tags["water"] = true
			&"oil":
				tags["oil"] = true
			&"lava":
				tags["lava"] = true
	match element_id:
		WATER_ID:
			tags["water"] = true
			tags["liquid"] = true
		OIL_ID:
			tags["oil"] = true
			tags["liquid"] = true
		LAVA_ID:
			tags["lava"] = true
			tags["fire"] = true
			tags["liquid"] = true
		FIRE_ID, BLUE_FIRE_ID, BURNING_OIL_ID:
			tags["fire"] = true
		ACID_ID:
			tags["toxic"] = true
			tags["liquid"] = true
	return tags
