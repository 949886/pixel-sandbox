extends Node2D

const GOLD_DEF_PATH: String = "res://resources/gameplay/creative/entities/gold_pickup.tres"
const FIREBALL_DEF_PATH: String = "res://resources/gameplay/creative/entities/fireball_pickup.tres"
const TARGET: Vector2 = Vector2(137.0, 211.0)

func _ready() -> void:
	var gold_def: CreativeEntityDef = load(GOLD_DEF_PATH) as CreativeEntityDef
	var spell_def: CreativeEntityDef = load(FIREBALL_DEF_PATH) as CreativeEntityDef
	assert(gold_def != null)
	assert(spell_def != null)
	var gold: Node = gold_def.spawn(self, TARGET)
	var spell: Node = spell_def.spawn(self, TARGET + Vector2(24.0, 0.0))
	assert(gold is Node2D)
	assert(spell is Node2D)
	var gold_2d: Node2D = gold as Node2D
	var spell_2d: Node2D = spell as Node2D
	assert(gold_2d.global_position.distance_to(TARGET) < 0.01)
	assert(spell_2d.global_position.distance_to(TARGET + Vector2(24.0, 0.0)) < 0.01)
	await get_tree().physics_frame
	assert(absf(gold_2d.global_position.x - TARGET.x) < 0.01)
	assert(absf(gold_2d.global_position.y - TARGET.y) <= 2.1)
	assert(absf(spell_2d.global_position.x - (TARGET.x + 24.0)) < 0.01)
	assert(absf(spell_2d.global_position.y - TARGET.y) <= 2.1)
	print("Creative Entity Spawn Position Smoke Test: PASS")
	get_tree().quit()
