class_name CreativeEntityCatalog
extends RefCounted

const CAVE_EYE: CreativeEntityDef = preload("res://resources/gameplay/creative/entities/cave_eye.tres")
const GOLD_PICKUP: CreativeEntityDef = preload("res://resources/gameplay/creative/entities/gold_pickup.tres")
const FIREBALL_PICKUP: CreativeEntityDef = preload("res://resources/gameplay/creative/entities/fireball_pickup.tres")

static var _cached: Array[CreativeEntityDef] = []

static func all_entities() -> Array[CreativeEntityDef]:
	if _cached.is_empty():
		_cached = [CAVE_EYE, GOLD_PICKUP, FIREBALL_PICKUP]
	return _cached.duplicate()
