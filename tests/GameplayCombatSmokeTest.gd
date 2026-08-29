extends Node

## Pure gameplay smoke test. It does not require the native sand simulation and
## can be run headlessly once a Godot executable is available.
var failures: Array[String] = []

func _ready() -> void:
	_test_damage_and_health()
	_test_factions()
	_test_status_rules()
	_test_wand_spell_data()
	if failures.is_empty():
		print("GameplayCombatSmokeTest: PASS")
	else:
		for failure: String in failures:
			push_error("GameplayCombatSmokeTest: %s" % failure)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures.is_empty() else 1)

func _test_damage_and_health() -> void:
	var actor := Node2D.new()
	add_child(actor)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.maximum_health = 100.0
	health.hit_invulnerability_seconds = 0.0
	actor.add_child(health)
	health.reset_health()
	var packet := DamagePacket.create(12.0, DamageTypes.Type.PROJECTILE, self, self)
	var applied := health.take_damage(packet)
	_expect(is_equal_approx(applied, 12.0), "damage packet should apply 12 damage")
	_expect(is_equal_approx(health.current_health, 88.0), "health should be 88 after hit")
	var healed := health.heal(5.0)
	_expect(is_equal_approx(healed, 5.0), "heal should apply 5")
	_expect(is_equal_approx(health.current_health, 93.0), "health should be 93 after heal")
	actor.queue_free()

func _test_factions() -> void:
	var player := FactionComponent.new()
	player.faction = FactionComponent.Faction.PLAYER
	var ally := FactionComponent.new()
	ally.faction = FactionComponent.Faction.PLAYER
	var enemy := FactionComponent.new()
	enemy.faction = FactionComponent.Faction.ENEMY
	_expect(not FactionComponent.can_damage(player, ally), "same faction should be protected")
	_expect(FactionComponent.can_damage(player, enemy), "player should damage enemy")
	_expect(FactionComponent.can_damage(enemy, player), "enemy should damage player")

func _test_status_rules() -> void:
	var actor := Node2D.new()
	add_child(actor)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.hit_invulnerability_seconds = 0.0
	actor.add_child(health)
	health.reset_health()
	var status := StatusComponent.new()
	status.name = "StatusComponent"
	status.rules = load("res://resources/gameplay/status_rules.tres") as StatusRulesDef
	actor.add_child(status)
	status.expose_wet(1.0)
	_expect(not status.ignite(2.0), "wet should prevent ignition")
	status.clear_all()
	status.expose_oil(2.0)
	_expect(status.ignite(1.0), "oiled actor should ignite")
	_expect(status.burning_remaining > 1.0, "oil should extend burning duration")
	actor.queue_free()

func _test_wand_spell_data() -> void:
	var wand := load("res://resources/gameplay/wands/starter_wand.tres") as WandDef
	_expect(wand != null, "starter wand should load")
	if wand == null:
		return
	_expect(wand.spells.size() == 4, "starter wand should contain four validation spells")
	var expected := [&"spark_bolt", &"dig_bolt", &"fire_bolt", &"bomb"]
	for index: int in range(mini(expected.size(), wand.spells.size())):
		var spell := wand.spells[index] as SpellDef
		_expect(spell != null, "wand spell %d should be SpellDef" % index)
		if spell != null:
			_expect(spell.spell_id == expected[index], "unexpected spell order at slot %d" % index)
			_expect(not spell.cast_effects.is_empty(), "%s should have a cast effect" % spell.display_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
