class_name WorldGenConfig
extends Resource

# Top-level generation config for the piece-based runtime world.
@export var world_seed: int = 20260706
@export var unit_size: int = 128
@export var units_per_chunk: int = 4
@export var load_radius: int = 2
@export var piece_library: PieceLibrary
@export var structure_profile: WorldStructureProfile
@export var biome_configs: Array[BiomeConfig] = []
@export var special_chunk_defs: Array[SpecialChunkDef] = []

func get_biome_config(biome_id: StringName) -> BiomeConfig:
	for biome_config: BiomeConfig in biome_configs:
		if biome_config != null and biome_config.id == biome_id:
			return biome_config
	return null

func is_valid() -> bool:
	if unit_size <= 0 or units_per_chunk <= 0 or load_radius < 0:
		return false
	if piece_library == null or structure_profile == null or not structure_profile.is_valid():
		return false
	if biome_configs.is_empty():
		return false
	var ids: Dictionary = {}
	for biome_config: BiomeConfig in biome_configs:
		if biome_config == null or not biome_config.is_valid() or ids.has(biome_config.id):
			return false
		ids[biome_config.id] = true
	# The authored world depth must resolve to exactly one biome at every row.
	for y: int in range(structure_profile.min_y, structure_profile.max_y + 1):
		var matches := 0
		for biome_config: BiomeConfig in biome_configs:
			if y >= biome_config.depth_min and y <= biome_config.depth_max:
				matches += 1
		if matches != 1:
			return false
	for definition: SpecialChunkDef in special_chunk_defs:
		if definition == null or definition.id == &"" or not definition.validate_profiles(units_per_chunk):
			return false
	return true
