class_name PixelSpellVFX
extends Node2D

## Tiny procedural square particles. No filtered textures, circles, or smooth
## particle sprites: the effect intentionally reads as simulation-adjacent pixels.
var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _lifetimes: Array[float] = []
var _initial_lifetimes: Array[float] = []
var _colors: Array[Color] = []
var _sizes: Array[float] = []
var _gravity: float = 0.0

static func spawn_burst(
	parent: Node,
	world_position: Vector2,
	primary: Color,
	secondary: Color,
	count: int = 10,
	speed: float = 80.0,
	lifetime: float = 0.28,
	pixel_size: float = 2.0,
	direction: Vector2 = Vector2.ZERO,
	cone_degrees: float = 360.0,
	gravity: float = 45.0
) -> PixelSpellVFX:
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion() or count <= 0:
		return null
	var burst := PixelSpellVFX.new()
	parent.add_child(burst)
	burst.global_position = world_position.floor()
	burst.z_index = 25
	burst._gravity = gravity
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var center_angle := direction.angle() if direction.length_squared() > 0.0001 else 0.0
	var full_circle := cone_degrees >= 359.0 or direction.length_squared() <= 0.0001
	for index: int in range(count):
		var angle := rng.randf_range(0.0, TAU) if full_circle else center_angle + deg_to_rad(rng.randf_range(-cone_degrees * 0.5, cone_degrees * 0.5))
		var magnitude := speed * rng.randf_range(0.35, 1.0)
		burst._positions.append(Vector2.ZERO)
		burst._velocities.append(Vector2.from_angle(angle) * magnitude)
		var particle_lifetime := maxf(0.01, lifetime) * rng.randf_range(0.65, 1.15)
		burst._lifetimes.append(particle_lifetime)
		burst._initial_lifetimes.append(particle_lifetime)
		burst._colors.append(primary if index % 3 != 0 else secondary)
		burst._sizes.append(maxf(1.0, pixel_size + float(rng.randi_range(-1, 1))))
	burst.queue_redraw()
	return burst

func _process(delta: float) -> void:
	var alive := false
	for index: int in range(_positions.size()):
		if _lifetimes[index] <= 0.0:
			continue
		_lifetimes[index] -= delta
		if _lifetimes[index] <= 0.0:
			continue
		alive = true
		var velocity := _velocities[index]
		velocity.y += _gravity * delta
		var position := _positions[index] + velocity * delta
		velocity *= maxf(0.0, 1.0 - delta * 3.2)
		_positions[index] = position
		_velocities[index] = velocity
	if not alive:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for index: int in range(_positions.size()):
		if _lifetimes[index] <= 0.0:
			continue
		var life_ratio := clampf(_lifetimes[index] / maxf(0.001, _initial_lifetimes[index]), 0.0, 1.0)
		var color := _colors[index]
		color.a *= life_ratio
		var size := _sizes[index]
		var snapped := _positions[index].round()
		draw_rect(Rect2(snapped - Vector2.ONE * floorf(size * 0.5), Vector2.ONE * size), color)
