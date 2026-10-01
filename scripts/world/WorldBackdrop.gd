class_name WorldBackdrop
extends Node2D

## Lightweight data-driven backdrop for the continuous pixel world. This node has
## no content paths and does not participate in simulation or chunk streaming.
var _snapshot: WorldLayoutSnapshot
var _profile: WorldPresentationProfile
var _world_seed: int = 0
var _draw_bounds: Rect2 = Rect2()
var _surface_y: float = 0.0
var _far_silhouette: PackedVector2Array = PackedVector2Array()
var _near_silhouette: PackedVector2Array = PackedVector2Array()


func configure(
	snapshot: WorldLayoutSnapshot,
	profile: WorldPresentationProfile,
	world_seed: int
) -> bool:
	_snapshot = snapshot
	_profile = profile
	_world_seed = world_seed
	if _snapshot == null or _profile == null or not _profile.is_valid() or not _snapshot.is_valid():
		visible = false
		queue_redraw()
		return false
	var anchor_value: Variant = _snapshot.get_anchor_position(_profile.surface_reference_anchor_id)
	if not anchor_value is Vector2:
		visible = false
		queue_redraw()
		return false
	var anchor_position: Vector2 = anchor_value
	_surface_y = anchor_position.y + _profile.surface_y_offset
	_draw_bounds = _expanded_world_bounds()
	_rebuild_silhouettes()
	visible = true
	queue_redraw()
	return true


func draw_bounds() -> Rect2:
	return _draw_bounds


func surface_y() -> float:
	return _surface_y


func _draw() -> void:
	if not visible or _profile == null or _draw_bounds.size.x <= 0.0 or _draw_bounds.size.y <= 0.0:
		return
	# Start with the deepest background so VOID and transparent material pixels never
	# expose the viewport clear color.
	draw_rect(_draw_bounds, _profile.underground_color, true)
	_draw_sky_gradient()
	_draw_underground_transition()
	if _profile.draw_surface_silhouettes:
		if _far_silhouette.size() >= 3:
			draw_colored_polygon(_far_silhouette, _profile.far_silhouette_color)
		if _near_silhouette.size() >= 3:
			draw_colored_polygon(_near_silhouette, _profile.near_silhouette_color)


func _expanded_world_bounds() -> Rect2:
	var chunk_size: float = float(_snapshot.chunk_size)
	var rect: Rect2i = _snapshot.used_rect
	var left: float = float(rect.position.x - _profile.horizontal_margin_chunks) * chunk_size
	var top: float = float(rect.position.y - _profile.top_margin_chunks) * chunk_size
	var width_chunks: int = rect.size.x + _profile.horizontal_margin_chunks * 2
	var height_chunks: int = rect.size.y + _profile.top_margin_chunks + _profile.bottom_margin_chunks
	return Rect2(
		Vector2(left, top),
		Vector2(float(width_chunks) * chunk_size, float(height_chunks) * chunk_size)
	)


func _draw_sky_gradient() -> void:
	var sky_top: float = _draw_bounds.position.y
	var sky_height: float = maxf(1.0, _surface_y - sky_top)
	var bands: int = maxi(2, _profile.gradient_bands)
	for index: int in range(bands):
		var t0: float = float(index) / float(bands)
		var t1: float = float(index + 1) / float(bands)
		var color: Color = _profile.sky_top_color.lerp(_profile.sky_horizon_color, (t0 + t1) * 0.5)
		draw_rect(
			Rect2(
				Vector2(_draw_bounds.position.x, sky_top + sky_height * t0),
				Vector2(_draw_bounds.size.x, sky_height * (t1 - t0) + 1.0)
			),
			color,
			true
		)


func _draw_underground_transition() -> void:
	var available: float = _draw_bounds.end.y - _surface_y
	var depth: float = minf(maxf(0.0, _profile.underground_transition_depth), maxf(0.0, available))
	if depth <= 0.0:
		return
	var bands: int = maxi(2, _profile.gradient_bands)
	for index: int in range(bands):
		var t0: float = float(index) / float(bands)
		var t1: float = float(index + 1) / float(bands)
		var color: Color = _profile.sky_horizon_color.lerp(_profile.underground_color, (t0 + t1) * 0.5)
		draw_rect(
			Rect2(
				Vector2(_draw_bounds.position.x, _surface_y + depth * t0),
				Vector2(_draw_bounds.size.x, depth * (t1 - t0) + 1.0)
			),
			color,
			true
		)


func _rebuild_silhouettes() -> void:
	_far_silhouette = _build_silhouette(
		&"far",
		_profile.far_mountain_height,
		_profile.mountain_step * 1.25,
		_surface_y + 2.0
	)
	_near_silhouette = _build_silhouette(
		&"near",
		_profile.near_mountain_height,
		_profile.mountain_step,
		_surface_y + 4.0
	)


func _build_silhouette(
	layer_id: StringName,
	max_height: float,
	step: float,
	baseline: float
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var left: float = _draw_bounds.position.x
	var right: float = _draw_bounds.end.x
	points.append(Vector2(left, baseline))
	if max_height <= 0.0:
		points.append(Vector2(right, baseline))
		points.append(Vector2(left, baseline))
		return points
	var rng: RandomNumberGenerator = SeedUtil.rng(
		_world_seed,
		"world_backdrop_%s_%s" % [str(_profile.id), str(layer_id)]
	)
	var x: float = left
	while x < right:
		var height_scale: float = rng.randf_range(0.28, 1.0)
		points.append(Vector2(x, baseline - max_height * height_scale))
		x += step * rng.randf_range(0.72, 1.24)
	points.append(Vector2(right, baseline))
	points.append(Vector2(left, baseline))
	return points
