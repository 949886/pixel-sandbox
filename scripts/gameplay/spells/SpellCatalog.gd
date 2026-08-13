class_name SpellCatalog
extends RefCounted

const SPELL_PATHS: PackedStringArray = [
	"res://resources/gameplay/spells/spark_bolt.tres",
	"res://resources/gameplay/spells/dig_bolt.tres",
	"res://resources/gameplay/spells/fire_bolt.tres",
	"res://resources/gameplay/spells/bomb.tres",
	"res://resources/gameplay/spells/luna/acid_splash.tres",
	"res://resources/gameplay/spells/luna/black_hole.tres",
	"res://resources/gameplay/spells/luna/chainsaw.tres",
	"res://resources/gameplay/spells/luna/death_cross.tres",
	"res://resources/gameplay/spells/luna/dragon_breath.tres",
	"res://resources/gameplay/spells/luna/dynamite.tres",
	"res://resources/gameplay/spells/luna/energy_sphere.tres",
	"res://resources/gameplay/spells/luna/explosive_bomb.tres",
	"res://resources/gameplay/spells/luna/fireball.tres",
	"res://resources/gameplay/spells/luna/glue_ball.tres",
	"res://resources/gameplay/spells/luna/ice_bolt.tres",
	"res://resources/gameplay/spells/luna/lightning.tres",
	"res://resources/gameplay/spells/luna/lightning_bolt.tres",
	"res://resources/gameplay/spells/luna/magic_arrow.tres",
	"res://resources/gameplay/spells/luna/spark.tres",
	"res://resources/gameplay/spells/luna/teleport_bolt.tres",
	"res://resources/gameplay/spells/modifiers/damage_plus.tres",
	"res://resources/gameplay/spells/modifiers/fixed_angle.tres",
	"res://resources/gameplay/spells/modifiers/light.tres",
	"res://resources/gameplay/spells/modifiers/long_distance_cast.tres",
	"res://resources/gameplay/spells/modifiers/spread.tres",
	"res://resources/gameplay/spells/multicast/double_cast.tres",
	"res://resources/gameplay/spells/multicast/double_scatter.tres",
	"res://resources/gameplay/spells/multicast/formation.tres",
	"res://resources/gameplay/spells/multicast/formation_back_front.tres",
	"res://resources/gameplay/spells/multicast/octuple_cast.tres",
	"res://resources/gameplay/spells/multicast/quadruple_cast.tres",
	"res://resources/gameplay/spells/multicast/triple_cast.tres",
]

static func all_spells() -> Array[SpellDef]:
	var result: Array[SpellDef] = []
	for path: String in SPELL_PATHS:
		var resource := load(path)
		if resource is SpellDef:
			result.append(resource as SpellDef)
	return result

static func random_spell(rng: RandomNumberGenerator = null, max_tier: int = 99) -> SpellDef:
	var candidates: Array[SpellDef] = []
	for spell: SpellDef in all_spells():
		if spell.tier <= max_tier:
			candidates.append(spell)
	if candidates.is_empty():
		return null
	var source_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		source_rng.randomize()
	return candidates[source_rng.randi_range(0, candidates.size() - 1)]
