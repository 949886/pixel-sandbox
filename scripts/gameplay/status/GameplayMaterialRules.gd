class_name GameplayMaterialRules
extends RefCounted

## Gameplay systems consume semantic tags. Native sand-slide element IDs are
## mapped to these tags by MaterialPalette resources, never in gameplay code.
const LIQUID: StringName = &"liquid"
const WATER: StringName = &"water"
const OIL: StringName = &"oil"
const FIRE: StringName = &"fire"
const LAVA: StringName = &"lava"
const TOXIC: StringName = &"toxic"


static func tags_for(tags: Array[StringName]) -> Dictionary:
	return {
		"liquid": tags.has(LIQUID),
		"water": tags.has(WATER),
		"oil": tags.has(OIL),
		"fire": tags.has(FIRE),
		"lava": tags.has(LAVA),
		"toxic": tags.has(TOXIC),
	}
