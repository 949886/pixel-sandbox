class_name MaterialPalette
extends Resource

## Converts flat colors in generated material images to sand-slide element IDs.
@export var entries: Array[MaterialEntry] = []
@export_range(0.0, 1.0, 0.01) var transparent_alpha_threshold: float = 0.05
@export var use_nearest_color_fallback: bool = true
@export_range(0.0, 2.0, 0.01) var maximum_color_distance: float = 0.42

var _exact_element_by_rgba: Dictionary = {}
var _nearest_cache: Dictionary = {}
var _solid_element_ids: Dictionary = {}
var _entry_by_element_id: Dictionary = {}
var _cache_ready: bool = false

func rebuild_cache() -> void:
	_exact_element_by_rgba.clear()
	_nearest_cache.clear()
	_solid_element_ids.clear()
	_entry_by_element_id.clear()
	for entry: MaterialEntry in entries:
		if entry == null:
			continue
		_entry_by_element_id[entry.engine_element_id] = entry
		if entry.solid:
			_solid_element_ids[entry.engine_element_id] = true
		for source_color: Color in entry.all_source_colors():
			_exact_element_by_rgba[_rgba_key_from_color(source_color)] = entry.engine_element_id
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
	var image: Image = source_image.duplicate()
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
	for pixel_index: int in range(pixel_count):
		var byte_index: int = pixel_index * 4
		var red: int = bytes[byte_index]
		var green: int = bytes[byte_index + 1]
		var blue: int = bytes[byte_index + 2]
		var alpha: int = bytes[byte_index + 3]
		if alpha <= alpha_cutoff:
			result[pixel_index] = 0
			continue
		var key: int = _rgba_key(red, green, blue, alpha)
		if _exact_element_by_rgba.has(key):
			result[pixel_index] = int(_exact_element_by_rgba[key])
			continue
		if _nearest_cache.has(key):
			result[pixel_index] = int(_nearest_cache[key])
			continue
		var resolved: int = _nearest_element_id(Color8(red, green, blue, alpha)) if use_nearest_color_fallback else 0
		_nearest_cache[key] = resolved
		result[pixel_index] = resolved
	return result

func is_solid_element_id(element_id: int) -> bool:
	_ensure_cache()
	return bool(_solid_element_ids.get(element_id, false))

func entry_for_element_id(element_id: int) -> MaterialEntry:
	_ensure_cache()
	return _entry_by_element_id.get(element_id, null) as MaterialEntry

func _nearest_element_id(source_color: Color) -> int:
	var best_id: int = 0
	var best_distance: float = INF
	for entry: MaterialEntry in entries:
		if entry == null or entry.engine_element_id == 0:
			# Opaque unknown pixels should never silently turn into empty air.
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
	# Weighted RGBA distance; green contributes most to perceived luminance.
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
