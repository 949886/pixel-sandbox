class_name GameStatistics
extends Node

signal enemies_killed_changed(total: int)
signal wands_collected_changed(total: int)
signal spells_collected_changed(total: int)

var _enemies_killed: int = 0
var _wands_collected: int = 0
var _spells_collected: int = 0

var enemies_killed: int:
	get:
		return _enemies_killed
	set(value):
		set_enemies_killed(value)

var wands_collected: int:
	get:
		return _wands_collected
	set(value):
		set_wands_collected(value)

var spells_collected: int:
	get:
		return _spells_collected
	set(value):
		set_spells_collected(value)


func set_enemies_killed(total: int) -> bool:
	if total < 0:
		return false
	if _enemies_killed == total:
		return true
	_enemies_killed = total
	enemies_killed_changed.emit(_enemies_killed)
	return true


func set_wands_collected(total: int) -> bool:
	if total < 0:
		return false
	if _wands_collected == total:
		return true
	_wands_collected = total
	wands_collected_changed.emit(_wands_collected)
	return true


func set_spells_collected(total: int) -> bool:
	if total < 0:
		return false
	if _spells_collected == total:
		return true
	_spells_collected = total
	spells_collected_changed.emit(_spells_collected)
	return true


func record_enemy_killed(count: int = 1) -> bool:
	if count <= 0:
		return false
	return set_enemies_killed(_enemies_killed + count)


func record_wand_collected(count: int = 1) -> bool:
	if count <= 0:
		return false
	return set_wands_collected(_wands_collected + count)


func record_spell_collected(count: int = 1) -> bool:
	if count <= 0:
		return false
	return set_spells_collected(_spells_collected + count)


func to_dictionary() -> Dictionary:
	return {
		"enemies_killed": _enemies_killed,
		"wands_collected": _wands_collected,
		"spells_collected": _spells_collected,
	}
