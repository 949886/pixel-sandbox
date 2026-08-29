class_name MaterialPalette
extends Resource

## Converts flat colors in generated material images to sand-slide element IDs.
@export var entries: Array[MaterialEntry] = []
@export var gameplay_bindings: Array[MaterialGameplayBinding] = []
@export var base_element_resource_directories: PackedStringArray = PackedStringArray()
@export_range(0.0, 1.0, 0.01) var transparent_alpha_threshold: float = 0.05
@export var use_nearest_color_fallback: bool = true
@export_range(0.0, 2.0, 0.01) var maximum_color_distance: float = 0.42

var _exact_element_by_rgba: Dictionary = {}
var _nearest_cache: Dictionary = {}
var _solid_element_ids: Dictionary = {}
var _entry_by_element_id: Dictionary = {}
var _gameplay_tags_by_element_id: Dictionary = {}
var _cache_ready: bool = false

func rebuild_cache() -> void:
	_exact_element_by_rgba.clear()
	_nearest_cache.clear()
	_solid_element_ids.clear()
	_entry_by_element_id.clear()
	_gameplay_tags_by_element_id.clear()
	for entry: MaterialEntry in entries:
		if entry == null:
			continue
		_entry_by_element_id[entry.engine_element_id] = entry
		if entry.solid:
			_solid_element_ids[entry.engine_element_id] = true
		for source_color: Color in entry.all_source_colors():
			_exact_element_by_rgba[_rgba_key_from_color(source_color)] = entry.engine_element_id
	for binding: MaterialGameplayBinding in gameplay_bindings:
		if binding == null:
			continue
		var normalized: Array[StringName] = []
		for tag: StringName in binding.tags:
			if tag != &"" and not normalized.has(tag):
				normalized.append(tag)
		_gameplay_tags_by_element_id[binding.engine_element_id] = normalized
	_cache_ready = true

func element_id_for_color(source_color: Color) -> int:
	_ensure_cache()
	if source_color.a <= transparent_alpha_threshold:
		return 0
	var key: int = _rgba_key_from_color(source_color)
	if _exact_element_by_rgba.has(key):
		return int(_exact_element_by_rgba[key])
	if _nearest_cache.has(key):
		return int(_nearest_cache[key])
	var resolved: int = _nearest_element_id(source_color) if use_nearest_color_fallback else 0
	_nearest_cache[key] = resolved
	return resolved

func image_to_element_ids(source_image: Image) -> PackedInt32Array:
	_ensure_cache()
	var result := PackedInt32Array()
	if source_image == null or source_image.is_empty():
		return result
	# Generated chunk images are already uncompressed RGBA8. Avoid duplicate() in the
	# hot path; duplicate only when conversion/decompression is actually required.
	var image: Image = source_image
	if image.is_compressed() or image.get_format() != Image.FORMAT_RGBA8:
		image = source_image.duplicate()
		if image.is_compressed():
			var error: Error = image.decompress()
			if error != OK:
				push_error("MaterialPalette could not decompress a chunk material image.")
				return result
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = image.get_data()
	var pixel_count: int = image.get_width() * image.get_height()
	result.resize(pixel_count)
	var alpha_cutoff: int = int(round(transparent_alpha_threshold * 255.0))
	# Keep dictionary references local to reduce Variant/property traffic in this
	# 262,144-iteration worker-thread loop.
	var exact: Dictionary = _exact_element_by_rgba
	# Each worker uses a local fallback cache. The palette resource is shared by the
	# normal and special generation threads, so mutating one shared Dictionary here
	# would introduce needless locking/races for non-exact source colors.
	var nearest: Dictionary = {}
	var allow_nearest: bool = use_nearest_color_fallback
	for pixel_index: int in range(pixel_count):
		var byte_index: int = pixel_index << 2
		var alpha: int = bytes[byte_index + 3]
		if alpha <= alpha_cutoff:
			result[pixel_index] = 0
			continue
		var red: int = bytes[byte_index]
		var green: int = bytes[byte_index + 1]
		var blue: int = bytes[byte_index + 2]
		var key: int = _rgba_key(red, green, blue, alpha)
		if exact.has(key):
			result[pixel_index] = int(exact[key])
			continue
		if nearest.has(key):
			result[pixel_index] = int(nearest[key])
			continue
		var resolved: int = _nearest_element_id(Color8(red, green, blue, alpha)) if allow_nearest else 0
		nearest[key] = resolved
		result[pixel_index] = resolved
	return result

func build_collision_rects(element_ids: PackedInt32Array, width: int, height: int, cell_size: int = 1) -> PackedInt32Array:
	## Converts the solid mask to an occupancy grid and greedily merges occupied cells.
	## Runtime profiles use a one-pixel step so the merged rectangles exactly cover
	## the rendered solid pixels without expanding into neighboring air.
	_ensure_cache()
	var result := PackedInt32Array()
	if element_ids.size() != width * height or width <= 0 or height <= 0:
		return result
	var step: int = maxi(1, cell_size)
	var grid_width: int = ceili(float(width) / float(step))
	var grid_height: int = ceili(float(height) / float(step))
	var occupied := PackedByteArray()
	occupied.resize(grid_width * grid_height)
	for gy: int in range(grid_height):
		var py0: int = gy * step
		var py1: int = mini(height, py0 + step)
		for gx: int in range(grid_width):
			var px0: int = gx * step
			var px1: int = mini(width, px0 + step)
			var solid_count: int = 0
			# With the runtime one-pixel step this is an exact occupancy test. Larger
			# optional steps remain conservative for custom low-detail profiles.
			var solid_threshold: int = 1
			for py: int in range(py0, py1):
				var row: int = py * width
				for px: int in range(px0, px1):
					if bool(_solid_element_ids.get(element_ids[row + px], false)):
						solid_count += 1
						if solid_count >= solid_threshold:
							break
				if solid_count >= solid_threshold:
					break
			occupied[gy * grid_width + gx] = 1 if solid_count >= solid_threshold else 0
	var used := PackedByteArray()
	used.resize(occupied.size())
	for gy: int in range(grid_height):
		for gx: int in range(grid_width):
			var start: int = gy * grid_width + gx
			if occupied[start] == 0 or used[start] != 0:
				continue
			var run_width: int = 1
			while gx + run_width < grid_width:
				var idx: int = gy * grid_width + gx + run_width
				if occupied[idx] == 0 or used[idx] != 0:
					break
				run_width += 1
			var run_height: int = 1
			var can_extend: bool = true
			while gy + run_height < grid_height and can_extend:
				for xx: int in range(run_width):
					var idx: int = (gy + run_height) * grid_width + gx + xx
					if occupied[idx] == 0 or used[idx] != 0:
						can_extend = false
						break
				if can_extend:
					run_height += 1
			for yy: int in range(run_height):
				for xx: int in range(run_width):
					used[(gy + yy) * grid_width + gx + xx] = 1
			var rect_x: int = gx * step
			var rect_y: int = gy * step
			var rect_w: int = mini(width - rect_x, run_width * step)
			var rect_h: int = mini(height - rect_y, run_height * step)
			result.append_array(PackedInt32Array([rect_x, rect_y, rect_w, rect_h]))
	return result

func is_solid_element_id(element_id: int) -> bool:
	_ensure_cache()
	return bool(_solid_element_ids.get(element_id, false))

func gameplay_tags_for_element_id(element_id: int) -> Array[StringName]:
	_ensure_cache()
	var result: Array[StringName] = []
	var entry := _entry_by_element_id.get(element_id, null) as MaterialEntry
	if entry != null and entry.liquid:
		result.append(&"liquid")
	var configured: Variant = _gameplay_tags_by_element_id.get(element_id, [])
	if configured is Array:
		for tag_value: Variant in configured:
			var tag := StringName(tag_value)
			if tag != &"" and not result.has(tag):
				result.append(tag)
	return result

func entry_for_element_id(element_id: int) -> MaterialEntry:
	_ensure_cache()
	return _entry_by_element_id.get(element_id, null) as MaterialEntry

func _nearest_element_id(source_color: Color) -> int:
	var best_id: int = 0
	var best_distance: float = INF
	for entry: MaterialEntry in entries:
		if entry == null or entry.engine_element_id == 0:
			continue
		for candidate: Color in entry.all_source_colors():
			if candidate.a <= transparent_alpha_threshold:
				continue
			var distance: float = _color_distance(source_color, candidate)
			if distance < best_distance:
				best_distance = distance
				best_id = entry.engine_element_id
	if best_distance > maximum_color_distance:
		return 0
	return best_id

func _color_distance(a: Color, b: Color) -> float:
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	var da: float = a.a - b.a
	return sqrt(dr * dr * 0.30 + dg * dg * 0.59 + db * db * 0.11 + da * da * 0.25)

func _rgba_key_from_color(color: Color) -> int:
	return _rgba_key(
		clampi(int(round(color.r * 255.0)), 0, 255),
		clampi(int(round(color.g * 255.0)), 0, 255),
		clampi(int(round(color.b * 255.0)), 0, 255),
		clampi(int(round(color.a * 255.0)), 0, 255)
	)

func _rgba_key(red: int, green: int, blue: int, alpha: int) -> int:
	return (red << 24) | (green << 16) | (blue << 8) | alpha

func _ensure_cache() -> void:
	if not _cache_ready:
		rebuild_cache()
