class_name SpellCatalog
extends Resource

@export var spells: Array[SpellDef] = []

var _by_id: Dictionary = {}
var _cache_ready: bool = false


func all_spells() -> Array[SpellDef]:
	_ensure_cache()
	var result: Array[SpellDef] = []
	for spell: SpellDef in spells:
		if spell != null:
			result.append(spell)
	return result


func get_spell(spell_id: StringName) -> SpellDef:
	_ensure_cache()
	return _by_id.get(spell_id, null) as SpellDef


func random_spell(rng: RandomNumberGenerator = null, max_tier: int = 99) -> SpellDef:
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


func is_valid() -> bool:
	_ensure_cache()
	return not _by_id.is_empty() and _by_id.size() == _non_null_spell_count()


func invalidate_cache() -> void:
	_cache_ready = false
	_by_id.clear()


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for spell: SpellDef in spells:
		if spell == null:
			continue
		if spell.spell_id == &"":
			push_error("SpellCatalog contains a spell with an empty spell_id.")
			continue
		if _by_id.has(spell.spell_id):
			push_error("SpellCatalog contains duplicate spell id '%s'." % str(spell.spell_id))
			continue
		_by_id[spell.spell_id] = spell
	_cache_ready = true


func _non_null_spell_count() -> int:
	var count: int = 0
	for spell: SpellDef in spells:
		if spell != null:
			count += 1
	return count
