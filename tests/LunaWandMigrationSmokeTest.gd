extends Node

func _ready() -> void:
	var double_cast := load("res://resources/gameplay/spells/multicast/double_cast.tres") as SpellDef
	var fireball := load("res://resources/gameplay/spells/luna/fireball.tres") as SpellDef
	var spark := load("res://resources/gameplay/spells/luna/spark.tres") as SpellDef
	var cards: Array[Resource] = [double_cast, fireball, spark]
	var deck := SpellDeckRuntime.new(cards, false)
	var result := deck.draw(1)
	var actions: Array = result.get("actions", [])
	assert(actions.size() == 2)
	assert((actions[0].get("spell") as SpellDef).spell_id == &"fireball")
	assert((actions[1].get("spell") as SpellDef).spell_id == &"spark")
	assert((actions[0].get("modifiers") as Array).size() == 1)
	assert((actions[0].get("modifiers") as Array)[0] == double_cast)

	for path: String in [
		"res://resources/gameplay/spells/spark_bolt.tres",
		"res://resources/gameplay/spells/dig_bolt.tres",
		"res://resources/gameplay/spells/fire_bolt.tres",
		"res://resources/gameplay/spells/bomb.tres",
		"res://resources/gameplay/spells/luna/black_hole.tres",
		"res://resources/gameplay/spells/luna/lightning.tres",
		"res://resources/gameplay/spells/luna/teleport_bolt.tres",
	]:
		assert(ResourceLoader.exists(path), "Missing spell resource: %s" % path)

	print("Luna Wand Migration Smoke Test: PASS")
	get_tree().quit()
