class_name PlayerState
extends Node

signal peer_id_changed(previous: int, current: int)
signal alive_changed(previous: bool, current: bool)

const INVALID_PLAYER_ID: int = 0
const UNBOUND_PEER_ID: int = 0

var _initialized: bool = false
var _player_id: int = INVALID_PLAYER_ID
var _peer_id: int = UNBOUND_PEER_ID
var _alive: bool = true

var player_id: int:
	get:
		return _player_id
	set(_value):
		push_error("PlayerState.player_id is read-only after initialize().")

var peer_id: int:
	get:
		return _peer_id
	set(_value):
		push_error("PlayerState.peer_id is read-only; use set_peer_id().")

var alive: bool:
	get:
		return _alive
	set(_value):
		push_error("PlayerState.alive is read-only; use set_alive().")


func initialize(player_id_value: int, peer_id_value: int = UNBOUND_PEER_ID) -> bool:
	if _initialized:
		return false
	if player_id_value <= INVALID_PLAYER_ID:
		return false
	if peer_id_value < UNBOUND_PEER_ID:
		return false

	_player_id = player_id_value
	_peer_id = peer_id_value
	_initialized = true
	return true


func is_initialized() -> bool:
	return _initialized


func set_peer_id(next_peer_id: int) -> bool:
	if not _initialized or next_peer_id < UNBOUND_PEER_ID:
		return false
	if _peer_id == next_peer_id:
		return true

	var previous: int = _peer_id
	_peer_id = next_peer_id
	peer_id_changed.emit(previous, _peer_id)
	return true


func set_alive(next_alive: bool) -> bool:
	if not _initialized:
		return false
	if _alive == next_alive:
		return true

	var previous: bool = _alive
	_alive = next_alive
	alive_changed.emit(previous, _alive)
	return true


func to_dictionary() -> Dictionary:
	return {
		"player_id": _player_id,
		"peer_id": _peer_id,
		"alive": _alive,
	}
