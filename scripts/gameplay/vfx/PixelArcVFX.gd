class_name PixelArcVFX
extends Node2D

var _points: Array[Vector2] = []
var _primary := Color(0.65, 0.92, 1.0, 1.0)
var _secondary := Color.WHITE
var _lifetime: float = 0.12
var _initial_lifetime: float = 0.12
var _pixel_size: float = 1.0

static func spawn_arc(parent: Node, start: Vector2, finish: Vector2, primary: Color, secondary: Color, variance: float = 5.0, lifetime: float = 0.12, pixel_size: float = 1.0) -> PixelArcVFX:
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	var arc := PixelArcVFX.new()
	parent.add_child(arc)
	arc.global_position = start.round()
	arc.z_index = 27
	arc._primary = primary
	arc._secondary = secondary
	arc._lifetime = maxf(0.01, lifetime)
	arc._initial_lifetime = arc._lifetime
	arc._pixel_size = maxf(1.0, pixel_size)
	var local_end := finish - start
	var distance := local_end.length()
	var direction := local_end.normalized() if distance > 0.001 else Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var segments := clampi(int(distance / 7.0) + 2, 3, 48)
	for index: int in range(segments + 1):
		var t := float(index) / float(segments)
		var offset := 0.0 if index == 0 or index == segments else rng.randf_range(-variance, variance) * sin(PI * t)
		arc._points.append((direction * distance * t + perpendicular * offset).round())
	arc.queue_redraw()
	return arc

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := clampf(_lifetime / maxf(0.001, _initial_lifetime), 0.0, 1.0)
	for index: int in range(_points.size() - 1):
		var a := _points[index]
		var b := _points[index + 1]
		var distance := a.distance_to(b)
		var steps := maxi(1, int(ceil(distance)))
		for step: int in range(steps + 1):
			var t := float(step) / float(steps)
			var point := a.lerp(b, t).round()
			var color := _secondary if (index + step) % 5 == 0 else _primary
			color.a *= alpha
			draw_rect(Rect2(point, Vector2.ONE * _pixel_size), color)
