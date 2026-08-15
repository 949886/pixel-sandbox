class_name BootstrapWorldManager
extends "res://scripts/world/WorldManager.gd"

signal world_runtime_started(seed: int)
signal initial_spawn_ready(spawn_position: Vector2)

var _bootstrap_configured: bool = false
var _world_started: bool = false
var _initial_spawn_is_ready: bool = false
var _configured_seed: int = 0
var _initial_spawn_position: Vector2 = Vector2.ZERO
var _runtime_world_gen_config: WorldGenConfig = null


func _ready() -> void:
	# Formal games are configured while this node is still off-tree. Generation
	# starts only through start_world(), never through scene sibling ready order.
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)


func configure(
		seed: int,
		config_template: WorldGenConfig,
		spawn_position: Vector2,
	) -> bool:
	if _bootstrap_configured or _world_started:
		return false
	if config_template == null or not spawn_position.is_finite():
		return false

	var runtime_config := config_template.duplicate(false) as WorldGenConfig
	if runtime_config == null:
		return false
	runtime_config.world_seed = seed

	_configured_seed = seed
	_initial_spawn_position = spawn_position
	_runtime_world_gen_config = runtime_config
	world_gen_config = runtime_config
	override_seed = false
	world_seed = seed
	_bootstrap_configured = true
	return true


func start_world() -> bool:
	if not _bootstrap_configured or _world_started or not is_inside_tree():
		return false

	super._ready()
	if active_config == null or generator == null or library == null or material_palette == null:
		return false
	if active_config != _runtime_world_gen_config:
		return false
	if world_seed != _configured_seed or active_config.world_seed != _configured_seed:
		return false

	_world_started = true
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	world_runtime_started.emit(world_seed)
	_check_initial_spawn_ready()
	return true


func _process(delta: float) -> void:
	if not _world_started:
		return
	super._process(delta)
	_check_initial_spawn_ready()


func _physics_process(delta: float) -> void:
	if not _world_started:
		return
	super._physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _world_started:
		return
	super._unhandled_input(event)


func is_bootstrap_configured() -> bool:
	return _bootstrap_configured


func is_world_started() -> bool:
	return _world_started


func is_initial_spawn_ready() -> bool:
	return _initial_spawn_is_ready


func get_runtime_world_gen_config() -> WorldGenConfig:
	return _runtime_world_gen_config


func _check_initial_spawn_ready() -> void:
	if _initial_spawn_is_ready or not _world_started:
		return
	var spawn_chunk: Vector2i = world_pos_to_chunk(_initial_spawn_position)
	if _canvas_for_chunk(spawn_chunk) == null:
		return
	if not is_motion_collision_ready(
			_initial_spawn_position,
			Vector2(0.0, 0.01),
			Vector2(8.0, 12.0),
		):
		return

	_initial_spawn_is_ready = true
	initial_spawn_ready.emit(_initial_spawn_position)
