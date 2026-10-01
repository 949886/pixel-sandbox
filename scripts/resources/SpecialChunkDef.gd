@tool
class_name SpecialChunkDef
extends Resource

# Metadata for a piece-rendered special chunk. The old TileMap scene/TileSet path
# is intentionally gone; external seams are stored as PieceSocket slots.
enum ChunkKind {
	TREASURE,
	SHOP,
	ALTAR,
	PORTAL,
	BOSS_ENTRANCE,
	PUZZLE,
	HALL,
	SHRINE,
	DECORATIVE,
}

enum TransitionStyle {
	ROCK,
	SNOW,
	DEEP,
	RUINS,
}

enum FillMode {
	NONE,
	PIECE_BORDER,
	PIECE_ENVIRONMENT,
}

enum LayoutStyle {
	ROOM,
	SURFACE_GROUND,
	SURFACE_ENTRANCE,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var editor_color: Color = Color(0.75, 0.55, 0.2, 1.0)
@export var editor_preview: Texture2D
@export_enum("Treasure", "Shop", "Altar", "Portal", "Boss Entrance", "Puzzle", "Hall", "Shrine", "Decorative") var chunk_kind: int = ChunkKind.DECORATIVE
@export var allowed_biomes: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var spawn_anchors: Array[SpawnAnchorDef] = []
@export var prefer_structure_tags: Array[StringName] = []
@export var avoid_structure_tags: Array[StringName] = []
@export var prefer_branch_end: bool = true
@export var prefer_chamber_edge: bool = false
@export var avoid_chamber_interior: bool = true
@export var placement_weight: float = 1.0
@export var size_in_chunks: Vector2i = Vector2i.ONE
@export var weight: float = 1.0
@export var target_count: int = 1
@export var allow_random_placement: bool = true
@export var unique_per_world: bool = false
@export var can_overlap_main_path: bool = false
@export var require_near_main_path: bool = false
@export_enum("Rock", "Snow", "Deep", "Ruins") var transition_style: int = TransitionStyle.ROCK
@export_enum("None", "Piece Border", "Piece Environment") var fill_mode: int = FillMode.PIECE_ENVIRONMENT

@export_category("Authored material layout")
## Optional exact material-color image used by fixed authored chunks. The image size
## must equal size_in_chunks * PieceWorldConstants.CHUNK_SIZE. Transparent pixels are
## air; opaque colors are resolved through MaterialPalette.
@export var material_layout: Texture2D
## Fixed art-critical chunks should enable this so a missing/invalid source image
## fails validation instead of silently falling back to procedural placeholder art.
@export var require_material_layout: bool = false

@export_category("Generated layout fallback")
@export_enum("Room", "Surface Ground", "Surface Entrance") var layout_style: int = LayoutStyle.ROOM
@export_range(0.15, 0.9, 0.01) var surface_ground_ratio: float = 0.62
@export_range(0.0, 0.35, 0.01) var surface_height_variation: float = 0.06
@export_range(0.2, 0.9, 0.01) var entrance_opening_ratio: float = 0.58
@export_range(0.1, 0.8, 0.01) var entrance_slope_width_ratio: float = 0.42

@export_category("Generated fallback visuals")
@export var generated_rock_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var generated_dark_color: Color = Color(0.1, 0.1, 0.1, 1.0)
@export var generated_accent_color: Color = Color(0.5, 0.7, 0.8, 1.0)
@export var generated_feature_color: Color = Color(0.5, 0.5, 0.5, 1.0)

# Profiles are four 128px socket slots per chunk edge.
# For a 2x1 chunk, top/bottom have 8 entries; left/right have 4 entries.
@export var top_profile: Array[int] = []
@export var right_profile: Array[int] = []
@export var bottom_profile: Array[int] = []
@export var left_profile: Array[int] = []

func expected_material_size() -> Vector2i:
	return size_in_chunks * PieceWorldConstants.CHUNK_SIZE


func has_valid_material_layout() -> bool:
	if material_layout == null:
		return not require_material_layout
	return Vector2i(material_layout.get_size()) == expected_material_size()


func create_authored_material_image() -> Image:
	if material_layout == null:
		return null
	var source: Image = material_layout.get_image()
	if source == null or source.is_empty() or source.get_size() != expected_material_size():
		return null
	var image: Image = source.duplicate() as Image
	if image == null:
		return null
	if image.is_compressed():
		var decompress_error: Error = image.decompress()
		if decompress_error != OK:
			return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func profile_length_top_bottom(slots_per_chunk: int) -> int:
	return size_in_chunks.x * slots_per_chunk

func profile_length_left_right(slots_per_chunk: int) -> int:
	return size_in_chunks.y * slots_per_chunk

func validate_profiles(slots_per_chunk: int) -> bool:
	return top_profile.size() == profile_length_top_bottom(slots_per_chunk) \
		and bottom_profile.size() == profile_length_top_bottom(slots_per_chunk) \
		and left_profile.size() == profile_length_left_right(slots_per_chunk) \
		and right_profile.size() == profile_length_left_right(slots_per_chunk)

func socket_profile(side: StringName, local_chunk_offset: Vector2i, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	match side:
		&"top":
			return _slice_socket_profile(top_profile, local_chunk_offset.x, slots_per_chunk)
		&"bottom":
			return _slice_socket_profile(bottom_profile, local_chunk_offset.x, slots_per_chunk)
		&"left":
			return _slice_socket_profile(left_profile, local_chunk_offset.y, slots_per_chunk)
		&"right":
			return _slice_socket_profile(right_profile, local_chunk_offset.y, slots_per_chunk)
	return _solid_profile(slots_per_chunk)

func _slice_socket_profile(profile: Array[int], local_chunk_index: int, slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	var start: int = local_chunk_index * slots_per_chunk
	for i: int in range(start, mini(start + slots_per_chunk, profile.size())):
		result.append(PieceSocket.from_value(profile[i]))
	while result.size() < slots_per_chunk:
		result.append(PieceSocket.SOLID)
	return result

func _solid_profile(slots_per_chunk: int) -> Array[PieceSocket.Socket]:
	var result: Array[PieceSocket.Socket] = []
	for i: int in range(slots_per_chunk):
		result.append(PieceSocket.SOLID)
	return result
