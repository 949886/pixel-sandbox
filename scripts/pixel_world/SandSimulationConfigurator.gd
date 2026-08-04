class_name SandSimulationConfigurator
extends RefCounted

const ELEMENT_RESOURCE_DIR := "res://painting/element_manager/element_material"

static var _base_ready: bool = false
static var _base_flat: Dictionary = {}
static var _base_gradient: Dictionary = {}
static var _base_fluid: Dictionary = {}
static var _base_metal: Dictionary = {}
static var _prepared_palette_id: int = 0
static var _prepared_flat: Dictionary = {}
static var _prepared_gradient: Dictionary = {}
static var _prepared_fluid: Dictionary = {}
static var _prepared_metal: Dictionary = {}
static var _prepared_custom: Dictionary = {}
static var _prepared_collision_ids: PackedInt32Array = PackedInt32Array()

static func prepare(palette: MaterialPalette) -> void:
	## Build immutable dictionaries once during world startup instead of duplicating and
	## rebuilding them every time a nearby chunk starts warming.
	_load_base_graphics()
	var palette_id: int = palette.get_instance_id() if palette != null else 0
	if palette_id == _prepared_palette_id and not _prepared_flat.is_empty():
		return
	_prepared_palette_id = palette_id
	_prepared_flat = _base_flat.duplicate(true)
	_prepared_gradient = _base_gradient.duplicate(true)
	_prepared_fluid = _base_fluid.duplicate(true)
	_prepared_metal = _base_metal.duplicate(true)
	_prepared_custom = {}
	_prepared_collision_ids = PackedInt32Array()
	if palette == null:
		return
	palette.rebuild_cache()
	for entry: MaterialEntry in palette.entries:
		if entry == null:
			continue
		var element_id: int = entry.engine_element_id
		if entry.solid:
			_prepared_collision_ids.append(element_id)
		var packed_color: int = entry.color.to_rgba32()
		if element_id >= 2048:
			_prepared_custom[element_id] = _custom_element_data(entry)
			_prepared_fluid[element_id] = [packed_color, packed_color, packed_color]
		elif _prepared_fluid.has(element_id):
			_prepared_fluid[element_id] = [packed_color, packed_color, packed_color]
		elif _prepared_metal.has(element_id):
			_prepared_metal[element_id] = [packed_color, packed_color]
		elif _prepared_gradient.has(element_id):
			_prepared_gradient[element_id] = [
				packed_color, packed_color, packed_color, packed_color, packed_color,
				0.25, 0.50, 0.75
			]
		else:
			_prepared_flat[element_id] = packed_color

static func configure(simulation: SandSimulation, palette: MaterialPalette) -> void:
	prepare(palette)
	simulation.initialize_custom_elements(_prepared_custom)
	simulation.initialize_flat_color(_prepared_flat)
	simulation.initialize_gradient_color(_prepared_gradient)
	simulation.initialize_fluid_color(_prepared_fluid)
	simulation.initialize_metal_color(_prepared_metal)
	if simulation.has_method("set_collision_elements"):
		simulation.call("set_collision_elements", _prepared_collision_ids)

static func _custom_element_data(entry: MaterialEntry) -> Array:
	return [
		entry.effective_state(),
		entry.effective_density(),
		entry.viscosity,
		0.0,
		0.5,
		1.0 if entry.flammable else 0.0,
		0.0,
		entry.durability,
		0.0,
		false, false, false, false, false, false, false,
		0, 0, 0, 0, 0, 0
	]

static func _load_base_graphics() -> void:
	if _base_ready:
		return
	_base_flat.clear()
	_base_gradient.clear()
	_base_fluid.clear()
	_base_metal.clear()
	var directory: DirAccess = DirAccess.open(ELEMENT_RESOURCE_DIR)
	if directory == null:
		push_error("Cannot open sand-slide element resource directory: %s" % ELEMENT_RESOURCE_DIR)
		_base_ready = true
		return
	for file_name: String in directory.get_files():
		var clean_name: String = file_name.replace(".remap", "")
		if not clean_name.ends_with(".tres"):
			continue
		var material: Resource = ResourceLoader.load("%s/%s" % [ELEMENT_RESOURCE_DIR, clean_name])
		if material == null:
			continue
		if material is FlatColor:
			_base_flat[material.id] = material.color.to_rgba32()
		elif material is GradientColor:
			_base_gradient[material.id] = [
				material.color_a.to_rgba32(), material.color_b.to_rgba32(),
				material.color_c.to_rgba32(), material.color_d.to_rgba32(),
				material.color_e.to_rgba32(), material.offset_1,
				material.offset_2, material.offset_3
			]
		elif material is Fluid:
			_base_fluid[material.id] = [
				material.color_a.to_rgba32(), material.color_b.to_rgba32(),
				material.color_c.to_rgba32()
			]
		elif material is Metal:
			_base_metal[material.id] = [
				material.color_a.to_rgba32(), material.color_b.to_rgba32()
			]
	_base_ready = true
