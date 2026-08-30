class_name WorldGenConfig
extends Resource

# Top-level generation config for the piece-based runtime world.
@export var world_seed: int = 20260706
@export var unit_size: int = 128
@export var units_per_chunk: int = 4
@export var load_radius: int = 2
@export var world_definition: WorldDefinition
@export var piece_library: PieceLibrary
@export var structure_profile: WorldStructureProfile
@export var biome_configs: Array[BiomeConfig] = []
@export var special_chunk_defs: Array[SpecialChunkDef] = []


func get_biome_config(biome_id: StringName) -> BiomeConfig:
	for biome_config: BiomeConfig in biome_configs:
		if biome_config != null and biome_config.id == biome_id:
			return biome_config
	return null


func get_special_chunk_def(chunk_id: StringName) -> SpecialChunkDef:
	for definition: SpecialChunkDef in special_chunk_defs:
		if definition != null and definition.id == chunk_id:
			return definition
	return null


func is_valid() -> bool:
	if unit_size <= 0 or units_per_chunk <= 0 or load_radius < 0:
		return false
	if unit_size != PieceWorldConstants.UNIT_SIZE or units_per_chunk != PieceWorldConstants.CHUNK_UNITS:
		return false
	if world_definition == null or not world_definition.is_valid():
		return false
	if piece_library == null or structure_profile == null or not structure_profile.is_valid():
		return false
	if biome_configs.is_empty():
		return false
	var biome_ids: Dictionary = {}
	for biome_config: BiomeConfig in biome_configs:
		if biome_config == null or not biome_config.is_valid() or biome_ids.has(biome_config.id):
			return false
		biome_ids[biome_config.id] = true
	var special_ids: Dictionary = {}
	for definition: SpecialChunkDef in special_chunk_defs:
		if definition == null or definition.id == &"" or special_ids.has(definition.id):
			return false
		if not definition.validate_profiles(units_per_chunk):
			return false
		for allowed_biome: StringName in definition.allowed_biomes:
			if allowed_biome == &"" or not biome_ids.has(allowed_biome):
				return false
		special_ids[definition.id] = true
	return true
