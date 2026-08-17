class_name PlayerBootstrapAdapter
extends Node

const SPAWN_COLLISION_PROBE: Vector2 = Vector2(0.0, 1.0)

@export var player_id: int = GameManager.LOCAL_PLAYER_ID

var _loadout_applied: bool = false


func apply_starting_loadout(loadout: StartingLoadoutDef) -> bool:
	if _loadout_applied:
		return true
	if loadout == null or not loadout.is_valid():
		return false

	var player := get_parent() as CharacterBody2D
	if player == null:
		return false
	var inventory := _find_inventory(player)
	var wand_controller := _find_wand_controller(player)
	if inventory == null or wand_controller == null:
		return false
	# Safe even if Player._ready() has not run yet. initialize() only binds the
	# controller/storage; it no longer chooses any starting equipment.
	inventory.initialize(wand_controller)
	if not inventory.apply_starting_loadout(loadout):
		return false

	player.set(&"starting_gold", maxi(0, loadout.gold))
	player.set(&"gold", maxi(0, loadout.gold))
	if player.has_signal(&"gold_changed"):
		player.emit_signal(&"gold_changed", maxi(0, loadout.gold))

	_loadout_applied = true
	return true


func is_loadout_applied() -> bool:
	return _loadout_applied


func is_ready_for_gameplay() -> bool:
	if not _loadout_applied:
		return false
	var player := get_parent() as CharacterBody2D
	if player == null or not player.is_inside_tree():
		return false
	var world := player.get_parent()
	if world == null or not world.has_method(&"is_world_position_loaded"):
		return false
	if not bool(world.call(&"is_world_position_loaded", player.global_position)):
		return false
	if not world.has_method(&"is_motion_collision_ready"):
		return false

	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	return bool(world.call(
		&"is_motion_collision_ready",
		player.global_position + collision_shape.position,
		SPAWN_COLLISION_PROBE,
		rectangle.size * 0.5,
	))


func _find_inventory(player: Node) -> PlayerInventory:
	for child: Node in player.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null


func _find_wand_controller(player: Node) -> WandController:
	for child: Node in player.get_children():
		if child is WandController:
			return child as WandController
	return null
