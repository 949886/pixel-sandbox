class_name ImageToElementConverter
extends RefCounted

# Converts a pixel image into a 2D array of element IDs by matching each pixel's
# color to the nearest known element color.

# Explicit palette overrides: Color -> element_id
# When set, these colors take priority over auto-matching.
var color_palette: Dictionary = {}

# Internal lookup built from element resources: Array of [Color, int (element_id)]
var _element_colors: Array = []


func build_palette_from_elements(element_map: Dictionary) -> void:
	## Builds the internal color->element lookup from the ElementManager's element_map.
	## Call this once after elements are loaded.
	_element_colors.clear()
	
	for id in element_map:
		var element: Element = element_map[id]
		var color: Color = _get_primary_color(element)
		if color.a < 0.01:
			# Skip fully transparent elements
			continue
		_element_colors.append([color, id])


func convert_image(image: Image) -> Array[PackedInt32Array]:
	## Converts an entire image to a 2D array of element IDs.
	## Returns Array[PackedInt32Array] where result[row][col] = element_id.
	## Transparent pixels (alpha < 0.1) map to element 0 (background).
	var width: int = image.get_width()
	var height: int = image.get_height()
	var result: Array[PackedInt32Array] = []
	result.resize(height)
	
	for row in range(height):
		var row_data: PackedInt32Array = PackedInt32Array()
		row_data.resize(width)
		for col in range(width):
			var pixel_color: Color = image.get_pixel(col, row)
			if pixel_color.a < 0.1:
				row_data[col] = 0
			else:
				row_data[col] = find_nearest_element(pixel_color)
		result[row] = row_data
	
	return result


func find_nearest_element(color: Color) -> int:
	## Finds the element ID whose color is closest to the given color.
	## Checks explicit color_palette first, then falls back to auto-matching.
	
	# Check explicit palette first (exact match with small tolerance)
	for palette_color in color_palette:
		if _colors_close(color, palette_color, 0.02):
			return color_palette[palette_color]
	
	# Auto-match: find nearest element by Euclidean distance in RGB
	var best_id: int = 0
	var best_dist: float = INF
	
	for entry in _element_colors:
		var element_color: Color = entry[0]
		var element_id: int = entry[1]
		var dist: float = _color_distance(color, element_color)
		if dist < best_dist:
			best_dist = dist
			best_id = element_id
	
	return best_id


func _get_primary_color(element: Element) -> Color:
	## Extracts the primary/representative color from any Element subtype.
	if element is FlatColor:
		return element.color
	elif element is GradientColor:
		return element.color_a
	elif element is Fluid:
		return element.color_a
	elif element is Metal:
		return element.color_a
	# Fallback: transparent (will be skipped)
	return Color(0, 0, 0, 0)


func _color_distance(a: Color, b: Color) -> float:
	## Euclidean distance in RGB space (ignoring alpha).
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	return dr * dr + dg * dg + db * db


func _colors_close(a: Color, b: Color, tolerance: float) -> bool:
	## Returns true if two colors are within tolerance in each RGB channel.
	return absf(a.r - b.r) < tolerance and absf(a.g - b.g) < tolerance and absf(a.b - b.b) < tolerance
