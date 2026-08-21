extends Node2D

@export var world_gen_config: WorldGenConfig
@export var material_palette: MaterialPalette
@export var override_seed: bool = false
@export var world_seed: int = 0

static var event_log: Array = []
static var _next_serial: int = 1

var instance_serial: int = 0
var mutable_marker: int = 0


func _init() -> void:
	instance_serial = _next_serial
	_next_serial += 1


func _ready() -> void:
	event_log.append("ready:%d" % instance_serial)


func _exit_tree() -> void:
	event_log.append("exit:%d" % instance_serial)


func is_world_position_loaded(_world_position: Vector2) -> bool:
	return true


func is_motion_collision_ready(
		_world_position: Vector2,
		_motion: Vector2,
		_half_extents: Vector2,
	) -> bool:
	return true


static func reset_probe() -> void:
	event_log.clear()
	_next_serial = 1
