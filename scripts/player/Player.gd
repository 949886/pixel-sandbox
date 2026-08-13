extends CharacterBody2D

## Noita-inspired player controller.
##
## The character root is positioned at the feet. Movement uses normal Godot
## collision against the streamed pixel-world snapshots, while liquid sampling
## and wand digging call the public helpers exposed by WorldManager.

signal flight_fuel_changed(current: float, maximum: float)
signal wand_fired(origin: Vector2, direction: Vector2)
signal health_changed(current: float, maximum: float)
signal gold_changed(current: int)
signal player_died

const BODY_DEFAULT_ORIGIN := Vector2(31.0, 35.0)
const BODY_ORIGIN_OVERRIDES := {
	&"intro_stand_up": Vector2(10.0, 14.0),
	&"intro_sleep": Vector2(10.0, 14.0),
}
const ANIMATION_FALLBACKS := {
	&"intro_stand_up": &"stand",
}
const BASE_STANDING_COLLIDER_SIZE := Vector2(12.0, 22.0)
const BASE_CROUCHING_COLLIDER_SIZE := Vector2(14.0, 14.0)
const BASE_ARM_PIVOT_RIGHT := Vector2(-4.0, -5.0)
const BASE_ARM_PIVOT_LEFT := Vector2(4.0, -5.0)
const BASE_ARM_PIVOT_CROUCH_RIGHT := Vector2(-4.0, -3.0)
const BASE_ARM_PIVOT_CROUCH_LEFT := Vector2(4.0, -3.0)
const BASE_CEILING_LEFT_POSITION := Vector2(-5.0, -13.0)
const BASE_CEILING_RIGHT_POSITION := Vector2(5.0, -13.0)
const BASE_CEILING_TARGET := Vector2(0.0, -10.0)
const BASE_CAMERA_POSITION := Vector2(0.0, -28.0)

@export_category("Character size")
@export_range(0.25, 1.0, 0.05) var character_scale: float = 0.5

@export_category("Ground movement")
@export var walk_speed: float = 115.0
@export var sprint_speed: float = 165.0
@export var crouch_speed: float = 62.0
@export var ground_acceleration: float = 1050.0
@export var ground_deceleration: float = 1400.0
@export var air_acceleration: float = 520.0
@export var gravity: float = 760.0
@export var max_fall_speed: float = 440.0
@export var fast_fall_acceleration: float = 520.0
@export_range(0.0, 8.0, 0.25) var max_step_height: float = 3.0
@export_range(0.0, 8.0, 0.25) var step_floor_probe: float = 2.0

@export_category("Jump and levitation")
@export var jump_speed: float = 235.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var jetpack_acceleration: float = 660.0
@export var max_jetpack_rise_speed: float = 185.0
@export var maximum_flight_fuel: float = 1.0
@export var flight_fuel_burn_rate: float = 0.46
@export var grounded_fuel_recharge_rate: float = 1.7
@export var swimming_fuel_recharge_rate: float = 0.65

@export_category("Swimming")
@export var swim_speed: float = 92.0
@export var swim_acceleration: float = 580.0
@export var swim_gravity_scale: float = 0.12
@export var liquid_sample_radius: float = 6.0

@export_category("Combat")
@export var respawn_delay: float = 1.25
@export var starting_gold: int = 0

@export_category("Camera")
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.55
@export var max_zoom: float = 4.0

@export_category("Touch input")
@export_range(0.05, 0.9, 0.05) var virtual_aim_threshold: float = 0.18

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var arm_pivot: Node2D = $ArmPivot
@onready var arm_sprite: AnimatedSprite2D = $ArmPivot/ArmSprite
@onready var wand_sprite: Sprite2D = $ArmPivot/WandSprite
@onready var muzzle: Marker2D = $ArmPivot/Muzzle
@onready var camera: Camera2D = $Camera2D
@onready var ceiling_left: RayCast2D = $CeilingLeft
@onready var ceiling_right: RayCast2D = $CeilingRight
@onready var health_component: HealthComponent = $HealthComponent
@onready var faction_component: FactionComponent = $FactionComponent
@onready var status_component: StatusComponent = $StatusComponent
@onready var environment_sensor: EnvironmentSensor = $EnvironmentSensor
@onready var wand_controller: WandController = $WandController
@onready var inventory_component: PlayerInventory = $PlayerInventory

var world_manager: Node
var world_interface: Node
var flight_fuel: float
var aim_direction := Vector2.RIGHT
var facing_left: bool = false
var crouching: bool = false
var swimming: bool = false
var flying: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _kick_active: bool = false
var _landing_active: bool = false
var _action_animation: StringName = &""
var _alternate_kick: bool = false
var _horizontal_input: float = 0.0
var _was_on_floor: bool = false
var _flight_input_active: bool = false
var _jump_fly_was_pressed: bool = false
var _virtual_move_input := Vector2.ZERO
var _virtual_jump_pressed: bool = false
var _virtual_fire_pressed: bool = false
var _virtual_aim_direction := Vector2.RIGHT
var _virtual_controls_active: bool = false
var _rng := RandomNumberGenerator.new()
var _game_mode_manager: GameModeManager
var _dead: bool = false
var _spawn_position := Vector2.ZERO
var gold: int = 0
var creative_fly_enabled: bool = false
var infinite_flight_enabled: bool = false
@export var creative_fly_speed: float = 260.0
@export var creative_fly_fast_multiplier: float = 2.5

func _ready() -> void:
	_ensure_input_actions()
	world_manager = get_parent()
	_game_mode_manager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	world_interface = world_manager.get_node_or_null("GameplayWorld") if world_manager != null else null
	if world_interface == null:
		world_interface = world_manager
	_spawn_position = global_position
	gold = maxi(0, starting_gold)
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 3.0
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = false
	floor_constant_speed = true
	camera.make_current()
	_set_flight_fuel(maximum_flight_fuel)
	_rng.randomize()
	_configure_animated_sprites()
	_apply_character_scale()
	body_sprite.animation_finished.connect(_on_body_animation_finished)
	if health_component != null:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_player_died)
	if wand_controller != null:
		if not wand_controller.wand_changed.is_connected(_on_player_wand_changed):
			wand_controller.wand_changed.connect(_on_player_wand_changed)
		_on_player_wand_changed(wand_controller.wand_def)
	if inventory_component != null:
		inventory_component.initialize(wand_controller)
	_set_crouching(false, true)
	_play_body_animation(&"stand", true)
	arm_sprite.play(&"default")
	_update_aim()


func set_virtual_move_input(input_vector: Vector2) -> void:
	_virtual_move_input = input_vector.limit_length(1.0)


func set_virtual_jump_pressed(pressed: bool) -> void:
	_virtual_jump_pressed = pressed


# Backward-compatible alias for earlier touch-control scenes. The joystick's
# upper zone now owns the complete combined jump + active-flight input.
func set_virtual_jump_fly_pressed(pressed: bool) -> void:
	set_virtual_jump_pressed(pressed)


func set_virtual_hover_pressed(pressed: bool) -> void:
	# Older hover-zone scenes are upgraded to the new active jump/flight semantics.
	set_virtual_jump_pressed(pressed)


func set_virtual_fire_pressed(pressed: bool) -> void:
	_virtual_fire_pressed = pressed


func set_virtual_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() >= virtual_aim_threshold * virtual_aim_threshold:
		_virtual_aim_direction = direction.normalized()


func set_virtual_controls_active(active: bool) -> void:
	if active and not _virtual_controls_active:
		_virtual_aim_direction = aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	_virtual_controls_active = active
	if not active:
		_virtual_move_input = Vector2.ZERO
		_virtual_jump_pressed = false
		_virtual_fire_pressed = false


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_environment_state()
	if _dead:
		velocity = Vector2.ZERO
		flying = false
		return
	_update_aim()
	if creative_fly_enabled:
		_handle_creative_action_input()
		_handle_creative_fly(delta)
		_update_animation()
		return
	_handle_action_input()
	_handle_movement(delta)

	_was_on_floor = is_on_floor()
	var motion := velocity * delta
	var readiness_motion := motion
	if _was_on_floor and absf(motion.x) > 0.001:
		readiness_motion.y -= max_step_height
	if not readiness_motion.is_zero_approx() and not _motion_collision_is_ready(readiness_motion):
		velocity = Vector2.ZERO
		flying = false
		_update_animation()
		return

	var stepped_up := _try_step_up(delta)
	move_and_slide()
	if stepped_up:
		apply_floor_snap()
	if not _was_on_floor and is_on_floor():
		_start_landing()
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	_update_animation()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"zoom_in"):
		_set_zoom(camera.zoom.x + zoom_step)
	elif Input.is_action_just_pressed(&"zoom_out"):
		_set_zoom(camera.zoom.x - zoom_step)

func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if is_on_floor():
		_coyote_timer = coyote_time

func _handle_action_input() -> void:
	if status_component != null and status_component.is_stunned():
		_flight_input_active = false
		_jump_fly_was_pressed = false
		return
	# Keyboard/gamepad and the joystick's upper semicircular zone both provide
	# the same combined jump + active-lift control.
	var physical_jump_fly_pressed := Input.is_action_pressed(&"jump_fly")
	var jump_pressed := physical_jump_fly_pressed or _virtual_jump_pressed
	var jump_just_pressed := jump_pressed and not _jump_fly_was_pressed
	var jump_just_released := not jump_pressed and _jump_fly_was_pressed

	if jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	elif jump_just_released:
		# Releasing either the physical action or the joystick zone shortens a
		# normal upward jump without clearing the remaining flight fuel.
		if not flying and velocity.y < -jump_speed * 0.35:
			velocity.y *= 0.55

	_flight_input_active = jump_pressed
	_jump_fly_was_pressed = jump_pressed

	_handle_wand_selection_input()
	if (Input.is_action_pressed(&"wand_fire") or _virtual_fire_pressed) and not _kick_active:
		_fire_wand()
	if Input.is_action_just_pressed(&"kick") and not _kick_active:
		_start_kick()

func set_creative_fly_enabled(enabled: bool) -> void:
	creative_fly_enabled = enabled
	if enabled:
		_set_crouching(false, true)
		velocity = Vector2.ZERO

func set_infinite_flight_enabled(enabled: bool) -> void:
	infinite_flight_enabled = enabled
	if enabled:
		_set_flight_fuel(maximum_flight_fuel)

func _handle_creative_action_input() -> void:
	_handle_wand_selection_input()
	if (Input.is_action_pressed(&"wand_fire") or _virtual_fire_pressed) and not _kick_active:
		_fire_wand()

func _handle_creative_fly(delta: float) -> void:
	var input_vector: Vector2 = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"jump_fly", &"crouch")
	)
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()
	var speed_scale: float = creative_fly_fast_multiplier if Input.is_action_pressed(&"sprint") else 1.0
	velocity = input_vector * creative_fly_speed * speed_scale
	global_position += velocity * delta
	flying = input_vector.length_squared() > 0.0001
	if infinite_flight_enabled:
		_set_flight_fuel(maximum_flight_fuel)

func _handle_movement(delta: float) -> void:
	var physical_horizontal := Input.get_axis(&"move_left", &"move_right")
	_horizontal_input = _stronger_axis(physical_horizontal, _virtual_move_input.x)
	var grounded := is_on_floor()
	var wants_crouch := _is_crouch_pressed() and grounded and not swimming
	if crouching and not wants_crouch and not _can_stand():
		wants_crouch = true
	_set_crouching(wants_crouch)

	if swimming:
		_handle_swimming(delta)
	else:
		_handle_ground_and_air(delta, grounded)

func _handle_ground_and_air(delta: float, grounded: bool) -> void:
	var status_speed_scale := status_component.movement_speed_multiplier() if status_component != null else 1.0
	var target_speed := walk_speed * status_speed_scale
	if crouching:
		target_speed = crouch_speed * status_speed_scale
	elif Input.is_action_pressed(&"sprint"):
		target_speed = sprint_speed * status_speed_scale

	var target_x := _horizontal_input * target_speed
	var acceleration := ground_acceleration if grounded else air_acceleration
	if grounded and is_zero_approx(_horizontal_input):
		acceleration = ground_deceleration
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not crouching:
		velocity.y = -jump_speed
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		grounded = false

	flying = false
	if not grounded:
		var wants_active_lift: bool = _flight_input_active and (infinite_flight_enabled or flight_fuel > 0.0)
		if wants_active_lift:
			# Keyboard/gamepad and the touch jump/flight zone share full upward thrust.
			flying = true
			velocity.y = move_toward(
				velocity.y,
				-max_jetpack_rise_speed,
				jetpack_acceleration * delta
			)
			if not infinite_flight_enabled:
				_set_flight_fuel(flight_fuel - flight_fuel_burn_rate * delta)
		else:
			velocity.y = minf(max_fall_speed, velocity.y + gravity * delta)
		if _is_crouch_pressed():
			velocity.y = minf(max_fall_speed, velocity.y + fast_fall_acceleration * delta)
	else:
		_set_flight_fuel(flight_fuel + grounded_fuel_recharge_rate * delta)

func _handle_swimming(delta: float) -> void:
	flying = false
	_set_crouching(false)
	var physical_vertical := Input.get_axis(&"jump_fly", &"crouch")
	var virtual_vertical := _virtual_move_input.y
	if _virtual_jump_pressed:
		virtual_vertical = -1.0
	var vertical_input := _stronger_axis(physical_vertical, virtual_vertical)
	var target := Vector2(_horizontal_input, vertical_input)
	if target.length_squared() > 1.0:
		target = target.normalized()
	target *= swim_speed
	velocity.x = move_toward(velocity.x, target.x, swim_acceleration * delta)
	velocity.y = move_toward(velocity.y, target.y, swim_acceleration * delta)
	velocity.y = minf(swim_speed, velocity.y + gravity * swim_gravity_scale * delta)
	_set_flight_fuel(flight_fuel + swimming_fuel_recharge_rate * delta)


func _is_crouch_pressed() -> bool:
	return Input.is_action_pressed(&"crouch")


func _stronger_axis(physical_value: float, virtual_value: float) -> float:
	return virtual_value if absf(virtual_value) > absf(physical_value) else physical_value

func _update_environment_state() -> void:
	if world_interface == null or not is_instance_valid(world_interface) or environment_sensor == null:
		swimming = false
		return
	var samples: Array[Vector2] = [
		global_position + Vector2(0.0, -4.0) * character_scale,
		global_position + Vector2(-liquid_sample_radius, -11.0) * character_scale,
		global_position + Vector2(liquid_sample_radius, -11.0) * character_scale,
		global_position + Vector2(0.0, -18.0) * character_scale,
	]
	environment_sensor.sample_points(world_interface, samples)
	swimming = environment_sensor.swimming
	if status_component != null:
		status_component.apply_environment(environment_sensor, world_interface)

func _update_aim() -> void:
	if _virtual_controls_active:
		# The right directional fire control owns touch aiming. Preserve its last
		# direction when released, while ignoring browser-emulated mouse motion.
		if _virtual_aim_direction.length_squared() >= virtual_aim_threshold * virtual_aim_threshold:
			aim_direction = _virtual_aim_direction.normalized()
	else:
		var mouse_delta := get_global_mouse_position() - global_position
		if mouse_delta.length_squared() > 0.0001:
			aim_direction = mouse_delta.normalized()
	facing_left = aim_direction.x < 0.0
	body_sprite.flip_h = facing_left
	var base_arm_position: Vector2
	if crouching:
		base_arm_position = BASE_ARM_PIVOT_CROUCH_LEFT if facing_left else BASE_ARM_PIVOT_CROUCH_RIGHT
	else:
		base_arm_position = BASE_ARM_PIVOT_LEFT if facing_left else BASE_ARM_PIVOT_RIGHT
	arm_pivot.position = base_arm_position * character_scale
	arm_pivot.rotation = aim_direction.angle()
	arm_pivot.scale = Vector2(character_scale, -character_scale if facing_left else character_scale)
	var equipment_visible := not _kick_active
	arm_sprite.visible = equipment_visible
	wand_sprite.visible = equipment_visible


func _on_player_wand_changed(definition: WandDef) -> void:
	if wand_sprite == null:
		return
	if definition == null:
		wand_sprite.visible = false
		return
	if definition.visual_texture != null:
		wand_sprite.texture = definition.visual_texture
	wand_sprite.modulate = definition.visual_modulate
	wand_sprite.visible = not _kick_active

func _fire_wand() -> void:
	if _gameplay_action_blocked(&"wand_fire"):
		return
	if world_manager == null or not is_instance_valid(world_manager) or world_manager.is_queued_for_deletion() or wand_controller == null:
		return
	if wand_controller.try_cast(muzzle.global_position, aim_direction, self, world_interface, world_manager):
		wand_fired.emit(muzzle.global_position, aim_direction)


func _gameplay_action_blocked(action: StringName) -> bool:
	if _game_mode_manager == null or not is_instance_valid(_game_mode_manager):
		_game_mode_manager = get_tree().get_first_node_in_group(&"game_mode_manager") as GameModeManager
	return _game_mode_manager != null and _game_mode_manager.gameplay_action_blocked(action)

func _handle_wand_selection_input() -> void:
	if inventory_component == null:
		return
	if Input.is_action_just_pressed(&"wand_slot_1"):
		inventory_component.equip_wand(0)
	elif Input.is_action_just_pressed(&"wand_slot_2"):
		inventory_component.equip_wand(1)
	elif Input.is_action_just_pressed(&"wand_slot_3"):
		inventory_component.equip_wand(2)
	elif Input.is_action_just_pressed(&"wand_slot_4"):
		inventory_component.equip_wand(3)

func _unhandled_input(event: InputEvent) -> void:
	if inventory_component == null or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_cycle_wand(-1)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_cycle_wand(1)

func _cycle_wand(delta: int) -> void:
	if inventory_component == null or inventory_component.wands.is_empty():
		return
	var start := inventory_component.equipped_wand_index
	for offset: int in range(1, inventory_component.wands.size() + 1):
		var candidate := posmod(start + delta * offset, inventory_component.wands.size())
		if inventory_component.wands[candidate] != null:
			inventory_component.equip_wand(candidate)
			return

func _update_animation() -> void:
	if _landing_active and (swimming or not is_on_floor()):
		_landing_active = false
	var selected := _select_animation()
	_update_animation_speed(selected)
	_play_body_animation(selected)

func _select_animation() -> StringName:
	if _kick_active:
		return _action_animation
	if swimming:
		return &"swim_move" if velocity.length() > 22.0 else &"swim_idle"
	if not is_on_floor():
		if flying:
			return &"fly_move" if absf(velocity.x) > 18.0 else &"fly_idle"
		return &"jump_up" if velocity.y < 0.0 else &"jump_fall"
	if _landing_active:
		return &"land"
	if crouching:
		if absf(velocity.x) < 8.0:
			return &"stand_crouched"
		if _moving_against_aim():
			return &"walk_backwards_crouched"
		return &"run_crouched" if Input.is_action_pressed(&"sprint") else &"walk_crouched"
	if absf(velocity.x) < 8.0:
		return &"stand"
	if _moving_against_aim():
		return &"walk_backwards"
	return &"run" if Input.is_action_pressed(&"sprint") else &"walk"

func _moving_against_aim() -> bool:
	var facing_sign := -1.0 if facing_left else 1.0
	return velocity.x * facing_sign < -4.0

func _play_body_animation(name: StringName, restart: bool = false) -> void:
	if body_sprite.sprite_frames == null or not body_sprite.sprite_frames.has_animation(name):
		name = &"stand"
	if not restart and body_sprite.animation == name:
		return
	body_sprite.play(name)
	if restart:
		body_sprite.frame = 0
		body_sprite.set_frame_and_progress(0, 0.0)
	_apply_body_animation_origin(name)

func _update_animation_speed(animation_name: StringName) -> void:
	match animation_name:
		&"walk", &"walk_backwards":
			body_sprite.speed_scale = clampf(absf(velocity.x) / maxf(walk_speed, 1.0), 0.72, 1.35)
		&"run":
			body_sprite.speed_scale = clampf(absf(velocity.x) / maxf(sprint_speed, 1.0), 0.82, 1.25)
		&"walk_crouched", &"walk_backwards_crouched", &"run_crouched":
			body_sprite.speed_scale = clampf(absf(velocity.x) / maxf(crouch_speed, 1.0), 0.72, 1.25)
		&"swim_move":
			body_sprite.speed_scale = clampf(velocity.length() / maxf(swim_speed, 1.0), 0.75, 1.3)
		&"fly_move":
			body_sprite.speed_scale = clampf(absf(velocity.x) / maxf(walk_speed, 1.0), 0.8, 1.25)
		_:
			body_sprite.speed_scale = 1.0

func _start_kick() -> void:
	_kick_active = true
	_landing_active = false
	_alternate_kick = not _alternate_kick
	if crouching:
		_action_animation = &"kick_alt_crouched" if _alternate_kick else &"kick_crouched"
	else:
		_action_animation = &"kick_alt" if _alternate_kick else &"kick"
	_play_body_animation(_action_animation, true)
	_update_aim()

func _start_landing() -> void:
	if _kick_active or swimming:
		return
	_landing_active = true
	_play_body_animation(&"land", true)

func _on_body_animation_finished() -> void:
	var finished := body_sprite.animation
	if _kick_active and finished == _action_animation:
		_kick_active = false
		_action_animation = &""
		_update_aim()
	elif _landing_active and finished == &"land":
		_landing_active = false
	elif ANIMATION_FALLBACKS.has(finished):
		var fallback: StringName = ANIMATION_FALLBACKS[finished]
		_play_body_animation(fallback, true)

func _apply_body_animation_origin(animation_name: StringName) -> void:
	var origin: Vector2 = BODY_ORIGIN_OVERRIDES.get(animation_name, BODY_DEFAULT_ORIGIN)
	var frame_texture := body_sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture != null:
		body_sprite.position = (frame_texture.get_size() * 0.5 - origin) * character_scale

func _configure_animated_sprites() -> void:
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_body_animation_origin(body_sprite.animation)

func _apply_character_scale() -> void:
	character_scale = clampf(character_scale, 0.25, 1.0)
	body_sprite.scale = Vector2.ONE * character_scale
	arm_pivot.scale = Vector2.ONE * character_scale
	ceiling_left.position = BASE_CEILING_LEFT_POSITION * character_scale
	ceiling_right.position = BASE_CEILING_RIGHT_POSITION * character_scale
	ceiling_left.target_position = BASE_CEILING_TARGET * character_scale
	ceiling_right.target_position = BASE_CEILING_TARGET * character_scale
	camera.position = BASE_CAMERA_POSITION * character_scale
	_apply_body_animation_origin(body_sprite.animation)
	_set_crouching(crouching, true)

func _set_crouching(value: bool, force: bool = false) -> void:
	if crouching == value and not force:
		return
	crouching = value
	var rectangle := collision_shape.shape as RectangleShape2D
	var collider_size := (BASE_CROUCHING_COLLIDER_SIZE if crouching else BASE_STANDING_COLLIDER_SIZE) * character_scale
	if rectangle != null:
		rectangle.size = collider_size
	collision_shape.position.y = -collider_size.y * 0.5
	_update_aim()

func _can_stand() -> bool:
	ceiling_left.force_raycast_update()
	ceiling_right.force_raycast_update()
	return not ceiling_left.is_colliding() and not ceiling_right.is_colliding()

func _collision_half_extents() -> Vector2:
	var rectangle := collision_shape.shape as RectangleShape2D
	return rectangle.size * 0.5 if rectangle != null else BASE_STANDING_COLLIDER_SIZE * character_scale * 0.5

func _try_step_up(delta: float) -> bool:
	if max_step_height <= 0.0 or not _was_on_floor or crouching or swimming:
		return false
	if absf(velocity.x) < 0.01 or velocity.y < -0.01:
		return false

	var horizontal_motion := Vector2(velocity.x * delta, 0.0)
	if horizontal_motion.is_zero_approx() or not test_move(global_transform, horizontal_motion, null, safe_margin):
		return false

	var whole_steps := maxi(1, int(ceil(max_step_height)))
	for step_index in range(1, whole_steps + 1):
		var step_height := minf(float(step_index), max_step_height)
		var upward_motion := Vector2(0.0, -step_height)
		if test_move(global_transform, upward_motion, null, safe_margin):
			continue

		var raised_transform := global_transform.translated(upward_motion)
		if test_move(raised_transform, horizontal_motion, null, safe_margin):
			continue

		# Require reachable floor after the horizontal move. This prevents the
		# step helper from climbing through floating obstacles or launching up walls.
		var landing_transform := raised_transform.translated(horizontal_motion)
		var floor_probe := Vector2(0.0, step_height + floor_snap_length + step_floor_probe)
		if not test_move(landing_transform, floor_probe, null, safe_margin):
			continue

		global_position.y -= step_height
		return true
	return false

func _motion_collision_is_ready(motion: Vector2) -> bool:
	if world_manager == null or not is_instance_valid(world_manager) or not world_manager.has_method("is_motion_collision_ready"):
		return true
	return bool(world_manager.call(
		"is_motion_collision_ready",
		global_position + collision_shape.position,
		motion,
		_collision_half_extents()
	))

func _set_flight_fuel(value: float) -> void:
	var previous := flight_fuel
	flight_fuel = clampf(value, 0.0, maximum_flight_fuel)
	if not is_equal_approx(previous, flight_fuel):
		flight_fuel_changed.emit(flight_fuel, maximum_flight_fuel)

func receive_damage(packet: DamagePacket) -> float:
	if health_component == null:
		return 0.0
	return health_component.take_damage(packet)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

func pickup_spell(spell: SpellDef) -> bool:
	return inventory_component.add_spell(spell) if inventory_component != null else false

func heal(amount: float) -> float:
	return health_component.heal(amount) if health_component != null else 0.0

func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)

func _on_player_died(_packet) -> void:
	if _dead:
		return
	_dead = true
	player_died.emit()
	_respawn_after_delay()

func _respawn_after_delay() -> void:
	await get_tree().create_timer(maxf(0.1, respawn_delay)).timeout
	if not is_inside_tree():
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_set_flight_fuel(maximum_flight_fuel)
	if status_component != null:
		status_component.clear_all()
	if health_component != null:
		health_component.reset_health()
	if wand_controller != null:
		wand_controller.reset_mana()
	_dead = false

func _set_zoom(value: float) -> void:
	var clamped := clampf(value, min_zoom, max_zoom)
	camera.zoom = Vector2(clamped, clamped)

func _ensure_input_actions() -> void:
	_add_key_action(&"move_left", [KEY_A, KEY_LEFT])
	_add_key_action(&"move_right", [KEY_D, KEY_RIGHT])
	_add_key_action(&"jump_fly", [KEY_W, KEY_SPACE, KEY_UP])
	_add_key_action(&"crouch", [KEY_S, KEY_DOWN])
	_add_key_action(&"sprint", [KEY_SHIFT])
	_add_key_action(&"kick", [KEY_F])
	_add_key_action(&"zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_add_key_action(&"zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_add_key_action(&"wand_slot_1", [KEY_1])
	_add_key_action(&"wand_slot_2", [KEY_2])
	_add_key_action(&"wand_slot_3", [KEY_3])
	_add_key_action(&"wand_slot_4", [KEY_4])
	_add_mouse_action(&"wand_fire", MOUSE_BUTTON_LEFT)
	_add_mouse_action(&"kick", MOUSE_BUTTON_RIGHT)

func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var exists := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).keycode == key:
				exists = true
				break
		if not exists:
			var key_event := InputEventKey.new()
			key_event.keycode = key
			InputMap.action_add_event(action, key_event)

func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button
	InputMap.action_add_event(action, mouse_event)
