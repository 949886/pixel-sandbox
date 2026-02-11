class_name WorldGenerator
extends Node

# Orchestrates world generation by converting images into simulation elements.

var converter: ImageToElementConverter

# Set to true to run a test on startup that generates a 256x256 procedural image
@export var run_test_on_ready: bool = true


func _ready() -> void:
	converter = ImageToElementConverter.new()
	
	await get_tree().get_root().ready
	
	# Build the palette from loaded elements
	converter.build_palette_from_elements(CommonReference.element_manager.element_map)
	
	if run_test_on_ready:
		_run_test()


func generate_from_image(image: Image, offset: Vector2i = Vector2i.ZERO) -> void:
	## Converts an image and places the resulting elements onto the simulation grid.
	## Elements are placed at (row + offset.y, col + offset.x).
	## Pixels outside the simulation bounds are silently clipped.
	var sim: SandSimulation = CommonReference.main.sim
	var element_data: Array[PackedInt32Array] = converter.convert_image(image)
	
	for row in range(element_data.size()):
		var target_row: int = row + offset.y
		if target_row < 0 or target_row >= sim.get_height():
			continue
		var row_data: PackedInt32Array = element_data[row]
		for col in range(row_data.size()):
			var target_col: int = col + offset.x
			if target_col < 0 or target_col >= sim.get_width():
				continue
			var element_id: int = row_data[col]
			if element_id != 0:
				sim.draw_cell(target_row, target_col, element_id)
	
	CommonReference.canvas.repaint()


func generate_from_path(path: String, offset: Vector2i = Vector2i.ZERO) -> void:
	## Loads an image from a file path and generates elements from it.
	var image: Image = Image.load_from_file(path)
	if image == null:
		push_error("WorldGenerator: Failed to load image from path: %s" % path)
		return
	generate_from_image(image, offset)


# ---- Test utilities ----

func _run_test() -> void:
	## Generates a 256x256 procedural test image with bands of known element colors
	## and loads it onto the canvas to verify the converter works correctly.
	print("WorldGenerator: Running test — generating 256x256 procedural image...")
	
	var test_image: Image = _create_test_image(256, 256)
	generate_from_image(test_image)
	
	print("WorldGenerator: Test complete — check the canvas for element bands.")


func _create_test_image(width: int, height: int) -> Image:
	## Creates a procedural test image with horizontal bands of element colors.
	## Each band uses the primary color of a known element so the converter
	## should map them back to the correct element IDs.
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	# Gather element colors for bands
	var band_colors: Array = []
	var element_map: Dictionary = CommonReference.element_manager.element_map
	
	# Pick a representative set of common elements
	var test_ids: Array = []
	for id in element_map:
		if id == 0:
			continue  # skip background
		test_ids.append(id)
	test_ids.sort()
	
	# Limit to a reasonable number of bands
	var max_bands: int = mini(test_ids.size(), 16)
	var step: int = maxi(test_ids.size() / max_bands, 1)
	for i in range(0, test_ids.size(), step):
		var element: Element = element_map[test_ids[i]]
		var color: Color = converter._get_primary_color(element)
		if color.a > 0.1:
			band_colors.append({"color": color, "id": test_ids[i]})
	
	if band_colors.is_empty():
		push_warning("WorldGenerator: No element colors found for test image")
		return image
	
	# Draw horizontal bands
	var band_height: int = height / band_colors.size()
	for band_idx in range(band_colors.size()):
		var color: Color = band_colors[band_idx]["color"]
		var element_id: int = band_colors[band_idx]["id"]
		var y_start: int = band_idx * band_height
		var y_end: int = y_start + band_height if band_idx < band_colors.size() - 1 else height
		
		for y in range(y_start, y_end):
			for x in range(width):
				# Add slight noise to test nearest-color matching robustness
				var noisy_color: Color = Color(
					clampf(color.r + randf_range(-0.03, 0.03), 0.0, 1.0),
					clampf(color.g + randf_range(-0.03, 0.03), 0.0, 1.0),
					clampf(color.b + randf_range(-0.03, 0.03), 0.0, 1.0),
					1.0
				)
				image.set_pixel(x, y, noisy_color)
		
		print("  Band %d: element %d (y=%d..%d)" % [band_idx, element_id, y_start, y_end - 1])
	
	return image
