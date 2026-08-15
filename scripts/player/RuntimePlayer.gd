class_name RuntimePlayer
extends "res://scripts/player/Player.gd"

signal authoritative_player_died(player_id: int, context: Variant)

var runtime_player_id: int = 1


func configure_runtime_player_id(player_id: int) -> bool:
	if player_id <= 0 or is_inside_tree():
		return false
	runtime_player_id = player_id
	return true


func get_spawn_position() -> Vector2:
	return _spawn_position


func respawn_at(position: Vector2) -> bool:
	if not _dead or health_component == null:
		return false
	global_position = position
	velocity = Vector2.ZERO
	if status_component != null:
		status_component.clear_all()
	health_component.reset_health()
	_set_flight_fuel(maximum_flight_fuel)
	_flying_reset()
	_dead = false
	return true


func heal(amount: float) -> float:
	if _dead:
		return 0.0
	return super.heal(amount)


func _on_player_died(packet) -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	flying = false
	player_died.emit()
	authoritative_player_died.emit(runtime_player_id, packet)


func _flying_reset() -> void:
	flying = false
	_flight_input_active = false
	_jump_fly_was_pressed = false
