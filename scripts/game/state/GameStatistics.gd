class_name GameStatistics
extends RefCounted

var _enemies_killed: int = 0
var _wands_collected: int = 0
var _spells_collected: int = 0

var enemies_killed: int:
	get:
		return _enemies_killed
	set(_value):
		push_error("GameStatistics.enemies_killed is read-only; use record_enemy_killed().")

var wands_collected: int:
	get:
		return _wands_collected
	set(_value):
		push_error("GameStatistics.wands_collected is read-only; use record_wand_collected().")

var spells_collected: int:
	get:
		return _spells_collected
	set(_value):
		push_error("GameStatistics.spells_collected is read-only; use record_spell_collected().")


func record_enemy_killed(count: int = 1) -> bool:
	if count <= 0:
		return false
	_enemies_killed += count
	return true


func record_wand_collected(count: int = 1) -> bool:
	if count <= 0:
		return false
	_wands_collected += count
	return true


func record_spell_collected(count: int = 1) -> bool:
	if count <= 0:
		return false
	_spells_collected += count
	return true


func to_dictionary() -> Dictionary:
	return {
		"enemies_killed": _enemies_killed,
		"wands_collected": _wands_collected,
		"spells_collected": _spells_collected,
	}
