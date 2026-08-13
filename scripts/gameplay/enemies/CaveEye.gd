class_name CaveEye
extends CharacterBody2D

## First combat enemy: a flying ranged enemy deliberately avoids dynamic-navmesh
## dependencies so it remains robust while terrain is continuously destroyed.
@export var move_speed: float = 72.0
@export var acceleration: float = 240.0
@export var detection_range: float = 360.0
@export var preferred_distance: float = 145.0
@export var attack_range: float = 285.0
@export var shots_per_second: float = 0.85
@export var projectile_speed: float = 245.0
@export var projectile_damage: float = 8.0
@export var gold_drop_min: int = 3
@export var gold_drop_max: int = 7
@export_range(0.0, 1.0, 0.05) var spell_drop_chance: float = 0.35
@export_range(0, 10, 1) var spell_drop_max_tier: int = 3

@onready var health: HealthComponent = $HealthComponent
@onready var faction: FactionComponent = $FactionComponent
@onready var status: StatusComponent = $StatusComponent
@onready var environment_sensor: EnvironmentSensor = $EnvironmentSensor

var target: Node2D
var world_manager: Node
var world_interface: Node
var _fire_cooldown: float = 0.5
var _hover_phase: float = 0.0
var _dead: bool = false
var _spawn_ready: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_hover_phase = _rng.randf_range(0.0, TAU)
	_find_world_context()
	target = get_tree().get_first_node_in_group("player") as Node2D
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	queue_redraw()
	call_deferred("_ensure_spawn_in_air")


func _ensure_spawn_in_air() -> void:
	for _attempt: int in range(12):
		await get_tree().create_timer(0.15).timeout
		if _dead or world_interface == null or not is_instance_valid(world_interface) or not is_inside_tree():
			return
		if world_interface.has_method("is_world_position_loaded") and not bool(world_interface.call("is_world_position_loaded", global_position)):
			continue
		if _position_is_open(global_position):
			_spawn_ready = true
			return
		var origin := global_position
		for radius: float in [24.0, 48.0, 72.0, 96.0, 128.0]:
			for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
				var candidate := origin + direction * radius
				if world_interface.has_method("is_world_position_loaded") and not bool(world_interface.call("is_world_position_loaded", candidate)):
					continue
				if _position_is_open(candidate):
					global_position = candidate
					_spawn_ready = true
					return
	_spawn_ready = true

func _position_is_open(position: Vector2) -> bool:
	if world_interface == null or not is_instance_valid(world_interface) or not world_interface.has_method("get_element_id_at_world_position"):
		return false
	for offset: Vector2 in [Vector2.ZERO, Vector2(-7, 0), Vector2(7, 0), Vector2(0, -7), Vector2(0, 7)]:
		if int(world_interface.call("get_element_id_at_world_position", position + offset)) != 0:
			return false
	return true

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _spawn_ready:
		velocity = Vector2.ZERO
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
	_update_environment()
	if status != null and status.is_stunned():
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
	var status_speed_scale := status.movement_speed_multiplier() if status != null else 1.0
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_hover_phase += delta * 2.1
	var to_target := target.global_position + Vector2(0.0, -8.0) - global_position
	var distance := to_target.length()
	var has_los := distance <= detection_range and _has_line_of_sight(target.global_position)
	var desired := Vector2.ZERO
	if has_los:
		var direction_to_target := to_target.normalized() if distance > 0.001 else Vector2.RIGHT
		if distance > preferred_distance + 22.0:
			desired = direction_to_target * move_speed * status_speed_scale
		elif distance < preferred_distance - 22.0:
			desired = -direction_to_target * move_speed * 0.8 * status_speed_scale
		desired.y += sin(_hover_phase) * 20.0
		if distance <= attack_range and _fire_cooldown <= 0.0:
			_fire(direction_to_target)
	else:
		desired = Vector2(sin(_hover_phase * 0.55) * 24.0, sin(_hover_phase) * 12.0)
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()
	rotation = lerp_angle(rotation, clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * 0.12, delta * 5.0)

func _update_environment() -> void:
	if world_interface == null or not is_instance_valid(world_interface):
		world_interface = null
		return
	var points: Array[Vector2] = [
		global_position,
		global_position + Vector2(-6.0, 0.0),
		global_position + Vector2(6.0, 0.0),
		global_position + Vector2(0.0, 6.0),
	]
	environment_sensor.sample_points(world_interface, points)
	status.apply_environment(environment_sensor, world_interface)

func _has_line_of_sight(target_position: Vector2) -> bool:
	if global_position.distance_squared_to(target_position) <= 0.0001:
		return true
	var world := get_world_2d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 1)
	query.exclude = [get_rid()]
	return world.direct_space_state.intersect_ray(query).is_empty()

func _fire(direction_to_target: Vector2) -> void:
	_fire_cooldown = 1.0 / maxf(0.1, shots_per_second)
	var projectile_parent := world_manager if world_manager != null and is_instance_valid(world_manager) else get_parent()
	if projectile_parent == null or not is_instance_valid(projectile_parent) or projectile_parent.is_queued_for_deletion():
		return
	var projectile := GameplayProjectile.new()
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position + direction_to_target * 10.0
	projectile.setup(
		direction_to_target,
		self,
		world_interface,
		projectile_speed,
		2.5,
		0.0,
		projectile_damage,
		DamageTypes.Type.PROJECTILE,
		3,
		Color(1.0, 0.35, 0.42, 1.0)
	)

func _on_damaged(_amount: float, _packet) -> void:
	queue_redraw()

func _on_died(_packet) -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	collision_mask = 0
	_spawn_gold()
	_spawn_spell()
	queue_free()

func _spawn_gold() -> void:
	var pickup_parent := world_manager if world_manager != null and is_instance_valid(world_manager) else get_parent()
	if pickup_parent == null or not is_instance_valid(pickup_parent) or pickup_parent.is_queued_for_deletion():
		return
	var pickup := GoldPickup.new()
	var minimum := mini(gold_drop_min, gold_drop_max)
	var maximum := maxi(gold_drop_min, gold_drop_max)
	pickup.value = maxi(1, _rng.randi_range(minimum, maximum))
	pickup_parent.add_child(pickup)
	pickup.global_position = global_position

func _spawn_spell() -> void:
	if _rng.randf() > clampf(spell_drop_chance, 0.0, 1.0):
		return
	var pickup_parent := world_manager if world_manager != null and is_instance_valid(world_manager) else get_parent()
	if pickup_parent == null or not is_instance_valid(pickup_parent) or pickup_parent.is_queued_for_deletion():
		return
	var dropped_spell := SpellCatalog.random_spell(_rng, spell_drop_max_tier)
	if dropped_spell == null:
		return
	var pickup := SpellPickup.new()
	pickup.spell = dropped_spell
	pickup_parent.add_child(pickup)
	pickup.global_position = global_position + Vector2(_rng.randf_range(-5.0, 5.0), -8.0)

func _find_world_context() -> void:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_element_id_at_world_position") and current.has_method("erase_material_circle"):
			world_manager = current
			break
		current = current.get_parent()
	if world_manager != null:
		world_interface = world_manager.get_node_or_null("GameplayWorld")
		if world_interface == null:
			world_interface = world_manager

func _draw() -> void:
	var ratio := health.health_ratio() if health != null else 1.0
	draw_circle(Vector2.ZERO, 9.0, Color(0.35, 0.08, 0.14, 1.0))
	draw_circle(Vector2.ZERO, 6.0, Color(0.94, 0.72, 0.68, 1.0))
	draw_circle(Vector2(1.5, 0.0), 3.0, Color(0.12, 0.03, 0.05, 1.0))
	draw_circle(Vector2(2.5, -1.0), 1.0, Color.WHITE)
	if ratio < 1.0:
		draw_rect(Rect2(-10.0, -14.0, 20.0, 2.0), Color(0.12, 0.12, 0.12, 0.9))
		draw_rect(Rect2(-10.0, -14.0, 20.0 * ratio, 2.0), Color(0.9, 0.2, 0.25, 1.0))
