extends CanvasLayer

# Grouped runtime HUD. The layout mirrors WorldRuntimeProfile categories so a
# value seen in F1 is easy to find in the profile inspector.

var panel: PanelContainer
var title_label: Label
var status_label: Label
var world_label: Label
var chunk_label: Label
var piece_label: Label
var worker_label: Label
var structure_label: Label
var simulation_label: Label
var block_label: Label
var flow_label: Label
var collision_label: Label
var pipeline_label: Label
var help_label: Label

const TEXT_COLOR := Color(0.80, 0.87, 0.93, 1.0)
const MUTED_COLOR := Color(0.61, 0.68, 0.75, 1.0)
const WORLD_COLOR := Color(0.47, 0.82, 1.0, 1.0)
const SIM_COLOR := Color(0.47, 0.93, 0.69, 1.0)
const COLLISION_COLOR := Color(1.0, 0.73, 0.38, 1.0)
const STRUCTURE_COLOR := Color(0.82, 0.65, 1.0, 1.0)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var old_margin: Node = get_node_or_null("DebugMargin")
	if old_margin != null:
		old_margin.free()
	var old_panel: Node = get_node_or_null("Panel")
	if old_panel != null:
		old_panel.free()

	var margin := MarginContainer.new()
	margin.name = "DebugMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 18.0
	margin.offset_top = 18.0
	margin.offset_right = 770.0
	margin.offset_bottom = 620.0
	add_child(margin)

	panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.custom_minimum_size = Vector2(752, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.065, 0.90)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	title_label = _make_label("PIXEL PIECE WORLD  ·  DEBUG", 15, Color(0.92, 0.97, 1.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	root.add_child(title_label)
	status_label = _make_label("Profile loading...", 11, MUTED_COLOR)
	root.add_child(status_label)
	root.add_child(_make_separator())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(350, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(350, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	world_label = _add_section(left, "WORLD / STREAMING", WORLD_COLOR)
	chunk_label = _add_section(left, "CURRENT CHUNK", WORLD_COLOR)
	piece_label = _add_section(left, "PIECES / SEAMS", STRUCTURE_COLOR)
	worker_label = _add_section(left, "GENERATION / QUEUES", WORLD_COLOR)
	structure_label = _add_section(left, "STRUCTURE / SPECIAL", STRUCTURE_COLOR)

	simulation_label = _add_section(right, "SIMULATION", SIM_COLOR)
	block_label = _add_section(right, "ACTIVE BLOCKS", SIM_COLOR)
	flow_label = _add_section(right, "CROSS-CHUNK FLOW", SIM_COLOR)
	collision_label = _add_section(right, "COLLISION", COLLISION_COLOR)
	pipeline_label = _add_section(right, "FRAME PIPELINE", COLLISION_COLOR)

	root.add_child(_make_separator())
	help_label = _make_label(
		"F1 HUD   F2 World   F3 Regen   F4 Next Seed   F5 Pixel Sim   F6 Collision\n" +
		"Sockets: hollow ring = Expected   filled dot = Actual   red strip = mismatch",
		10,
		MUTED_COLOR
	)
	root.add_child(help_label)

func _add_section(parent: VBoxContainer, title: String, color: Color) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	var header := _make_label(title, 10, color)
	header.add_theme_constant_override("outline_size", 1)
	box.add_child(header)
	var value := _make_label("loading...", 11, TEXT_COLOR)
	box.add_child(value)
	return value

func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.modulate = Color(1.0, 1.0, 1.0, 0.16)
	return separator

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	return label

func _yes_no(value: bool) -> String:
	return "YES" if value else "NO"

func set_debug_snapshot(snapshot: Dictionary) -> void:
	if panel == null:
		_build_ui()

	var native_api: int = int(snapshot.get("collision_native_api_version", 0))
	status_label.text = "Profile  %s   ·   Native API  %d   ·   Canvas  %s" % [
		str(snapshot.get("runtime_profile", "None")),
		native_api,
		str(snapshot.get("current_canvas_mode", "not attached")),
	]

	world_label.text = "Seed %d   ·   Player %s\nLoaded %d   ·   Pending %d   ·   Load radius %d\nRenderer %s   ·   Visual x%d   ·   Pool %d\nChunk %d px = %d × %d px units" % [
		int(snapshot.get("seed", 0)),
		str(snapshot.get("center_chunk", Vector2i.ZERO)),
		int(snapshot.get("loaded_count", 0)),
		int(snapshot.get("pending_count", 0)),
		int(snapshot.get("load_radius", 0)),
		str(snapshot.get("renderer", "PixelCanvas")),
		int(snapshot.get("visual_downscale", 1)),
		int(snapshot.get("renderer_pool", 0)),
		int(snapshot.get("unit_size", 128)) * int(snapshot.get("units_per_chunk", 4)),
		int(snapshot.get("units_per_chunk", 4)),
		int(snapshot.get("unit_size", 128)),
	]

	chunk_label.text = "Biome %s   ·   Type %s\nOpen sides %d   ·   Intended links %d\nTags %s" % [
		str(snapshot.get("biome", "unknown")),
		str(snapshot.get("chunk_type", "unknown")),
		int(snapshot.get("open_sides", 0)),
		int(snapshot.get("intended_connections", 0)),
		str(snapshot.get("structure_tags", "fallback")),
	]

	piece_label.text = "Expected  T %s  R %s  B %s  L %s\nActual     T %s  R %s  B %s  L %s\nRegular %d   ·   Open sockets %d   ·   Glue %d\nSeam repairs %d   ·   Broken expected/neighbor %d/%d" % [
		str(snapshot.get("top_profile", "SSSS")),
		str(snapshot.get("right_profile", "SSSS")),
		str(snapshot.get("bottom_profile", "SSSS")),
		str(snapshot.get("left_profile", "SSSS")),
		str(snapshot.get("actual_top_profile", "SSSS")),
		str(snapshot.get("actual_right_profile", "SSSS")),
		str(snapshot.get("actual_bottom_profile", "SSSS")),
		str(snapshot.get("actual_left_profile", "SSSS")),
		int(snapshot.get("exact_matches", 0)),
		int(snapshot.get("compatible_matches", 0)),
		int(snapshot.get("fallback_count", 0)),
		int(snapshot.get("seam_repairs", 0)),
		int(snapshot.get("seam_expected_broken", 0)),
		int(snapshot.get("seam_neighbor_broken", 0)),
	]

	worker_label.text = "Chunk worker %s   ·   Special worker %s\nChunk queue/results %d/%d   ·   Ready attach %d\nSpecial pending/worker queue %d/%d\nLast generation %d ms   ·   Last uploads %d" % [
		_yes_no(bool(snapshot.get("threaded_chunks", false))),
		_yes_no(bool(snapshot.get("threaded_specials", false))),
		int(snapshot.get("worker_queue", 0)),
		int(snapshot.get("worker_results", 0)),
		int(snapshot.get("ready_attach_queue", 0)),
		int(snapshot.get("special_pending", 0)),
		int(snapshot.get("special_worker_queue", 0)),
		int(snapshot.get("last_chunk_ms", 0)),
		int(snapshot.get("last_upload_count", 0)),
	]

	var special_text: String = str(snapshot.get("special_info", ""))
	var chamber_text: String = str(snapshot.get("current_chamber", ""))
	structure_label.text = "Special  %s\nChamber  %s\nAir units %d   ·   Placements %d   ·   Chambers %d" % [
		special_text if special_text != "" else "none nearby",
		chamber_text if chamber_text != "" else "none",
		int(snapshot.get("air_tiles", 0)),
		int(snapshot.get("air_pockets", 0)),
		int(snapshot.get("chamber_carve_open", 0)),
	]

	simulation_label.text = "Pixel sim %s   ·   Radius %d\nRate foreground/background %.0f / %.0f Hz   ·   Repaint %.0f Hz\nFrame ticks %d   ·   Special canvases %d" % [
		"ON" if bool(snapshot.get("simulation_enabled", false)) else "OFF",
		int(snapshot.get("simulation_radius", 0)),
		float(snapshot.get("simulation_hz", 0.0)),
		float(snapshot.get("background_simulation_hz", 0.0)),
		float(snapshot.get("simulation_repaint_hz", 0.0)),
		int(snapshot.get("simulation_ticks", 0)),
		int(snapshot.get("special_pixel_canvases", 0)),
	]

	block_label.text = "%d px blocks   ·   Active Blocks %s\nActive %d   ·   Cooling %d   ·   Sleeping %d / %d\nOccupied %d   ·   Processed %d   ·   Elements %d\nScanned cells %d   ·   Wakes %d   ·   Quiet threshold %d ticks" % [
		int(snapshot.get("block_size", 16)),
		_yes_no(bool(snapshot.get("native_active_blocks", false))),
		int(snapshot.get("block_active", 0)),
		int(snapshot.get("block_cooling", 0)),
		int(snapshot.get("block_sleeping", 0)),
		int(snapshot.get("block_total", 0)),
		int(snapshot.get("block_occupied", 0)),
		int(snapshot.get("block_processed", 0)),
		int(snapshot.get("block_processed_elements", 0)),
		int(snapshot.get("block_scanned_cells", 0)),
		int(snapshot.get("block_wakes", 0)),
		int(snapshot.get("block_sleep_quiet_ticks", 4)),
	]

	flow_label.text = "Native bridge %s   ·   Seams this frame %d\nMoved cells %d   ·   Warm radius %d   ·   Neighbor wake %d ms" % [
		_yes_no(bool(snapshot.get("native_flow_bridge", false))),
		int(snapshot.get("border_flow_seams", 0)),
		int(snapshot.get("border_flow_moved", 0)),
		int(snapshot.get("flow_warm_radius", 0)),
		int(snapshot.get("border_neighbor_wake_ms", 0)),
	]

	collision_label.text = "Sector %d px   ·   %d sectors   ·   Native sectors %s\nDirty %d   ·   Building %d   ·   Pending %d   ·   Unsafe %d\nRebuild %.0f Hz   ·   Commits/frame %d   ·   F6 %s" % [
		int(snapshot.get("collision_sector_size", 64)),
		int(snapshot.get("collision_sector_count", 0)),
		_yes_no(bool(snapshot.get("collision_native_sector_api", false))),
		int(snapshot.get("collision_dirty_sectors", 0)),
		int(snapshot.get("collision_building_sectors", 0)),
		int(snapshot.get("collision_pending_sectors", 0)),
		int(snapshot.get("collision_unsafe_sectors", 0)),
		float(snapshot.get("collision_dynamic_rebuild_hz", 0.0)),
		int(snapshot.get("collision_sector_commits_per_physics_frame", 0)),
		"ON" if bool(snapshot.get("collision_debug_visible", false)) else "OFF",
	]

	pipeline_label.text = "Pipeline %.2f / %.2f ms\nWork  warm %d   ·   texture %d   ·   collision shapes %d   ·   sim ticks %d\nBudgets ms  sim %.2f   ·   collision %.2f + critical %.2f\nAttach %.2f   ·   warm %.2f   ·   texture %.2f   ·   recycle %.2f" % [
		float(snapshot.get("pipeline_ms", 0.0)),
		float(snapshot.get("pipeline_budget_ms", 0.0)),
		int(snapshot.get("warmup_completed", 0)),
		int(snapshot.get("texture_activations", 0)),
		int(snapshot.get("collision_shapes_built", 0)),
		int(snapshot.get("simulation_ticks", 0)),
		float(snapshot.get("simulation_update_budget_ms", 0.0)),
		float(snapshot.get("collision_build_budget_ms", 0.0)),
		float(snapshot.get("critical_collision_budget_ms", 0.0)),
		float(snapshot.get("chunk_attach_budget_ms", 0.0)),
		float(snapshot.get("simulation_warmup_budget_ms", 0.0)),
		float(snapshot.get("simulation_texture_activation_budget_ms", 0.0)),
		float(snapshot.get("recycle_budget_ms", 0.0)),
	]

func set_debug_data(seed_value: int, center_chunk: Vector2i, loaded_count: int, fallback_count: int, renderer_name: String = "PieceImage", air_tile_count: int = 0, compatible_match_count: int = 0) -> void:
	set_debug_snapshot({
		"seed": seed_value,
		"center_chunk": center_chunk,
		"loaded_count": loaded_count,
		"load_radius": 0,
		"renderer": renderer_name,
		"fallback_count": fallback_count,
		"compatible_matches": compatible_match_count,
		"air_tiles": air_tile_count,
	})

func toggle_visible() -> void:
	visible = not visible
