class_name GameBootstrapReadiness
extends RefCounted

var _game_id: int = GameManager.INVALID_GAME_ID
var _world_ready: bool = false
var _required_player_ids: Dictionary = {}
var _ready_player_ids: Dictionary = {}


func reset(game_id: int, required_player_ids: Array[int]) -> bool:
	if game_id <= GameManager.INVALID_GAME_ID:
		return false
	var required: Dictionary = {}
	for player_id: int in required_player_ids:
		if player_id <= GameManager.INVALID_PLAYER_ID:
			return false
		required[player_id] = true

	_game_id = game_id
	_world_ready = false
	_required_player_ids = required
	_ready_player_ids.clear()
	return true


func mark_world_ready(game_id: int) -> bool:
	if game_id != _game_id:
		return false
	_world_ready = true
	return true


func mark_player_ready(game_id: int, player_id: int) -> bool:
	if game_id != _game_id:
		return false
	if not _required_player_ids.has(player_id):
		return false
	_ready_player_ids[player_id] = true
	return true


func is_world_ready(game_id: int) -> bool:
	return game_id == _game_id and _world_ready


func is_player_ready(game_id: int, player_id: int) -> bool:
	return game_id == _game_id \
		and _required_player_ids.has(player_id) \
		and _ready_player_ids.has(player_id)


func is_ready(game_id: int) -> bool:
	if game_id != _game_id or not _world_ready:
		return false
	for player_id_value: Variant in _required_player_ids.keys():
		if not _ready_player_ids.has(int(player_id_value)):
			return false
	return true


func get_required_player_ids() -> Array[int]:
	var result: Array[int] = []
	for player_id_value: Variant in _required_player_ids.keys():
		result.append(int(player_id_value))
	result.sort()
	return result
