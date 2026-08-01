class_name SandSimulationConfigurator
extends RefCounted

const ELEMENT_RESOURCE_DIR := "res://main/element_manager/element_material"

static var _base_ready: bool = false
static var _base_flat: Dictionary = {}
static var _base_gradient: Dictionary = {}
static var _base_fluid: Dictionary = {}
static var _base_metal: Dictionary = {}

static func configure(simulation: SandSimulation, palette: MaterialPalette) -> void:
	_load_base_graphics()
	var flat: Dictionary = _base_flat.duplicate(true)
	var gradient: Dictionary = _base_gradient.duplicate(true)
	var fluid: Dictionary = _base_fluid.duplicate(true)
	var metal: Dictionary = _base_metal.duplicate(true)
	var custom_elements: Dictionary = {}

	if palette != null:
		palette.rebuild_cache()
		for entry: MaterialEntry in palette.entries:
			if entry == null:
				continue
			var element_id: int = entry.engine_element_id
			var packed_color: int = entry.color.to_rgba32()
			if element_id >= 2048:
				custom_elements[element_id] = _custom_element_data(entry)
				fluid[element_id] = [packed_color, packed_color, packed_color]
			elif fluid.has(element_id):
				fluid[element_id] = [packed_color, packed_color, packed_color]
			elif metal.has(element_id):
				metal[element_id] = [packed_color, packed_color]
			elif gradient.has(element_id):
				gradient[element_id] = [
					packed_color, packed_color, packed_color, packed_color, packed_color,
					0.25, 0.50, 0.75
				]
			else:
				flat[element_id] = packed_color

	simulation.initialize_custom_elements(custom_elements)
	simulation.initialize_flat_color(flat)
	simulation.initialize_gradient_color(gradient)
	simulation.initialize_fluid_color(fluid)
	simulation.initialize_metal_color(metal)

static func _custom_element_data(entry: MaterialEntry) -> Array:
	return [
		entry.effective_state(),
		entry.effective_density(),
		entry.viscosity,
		0.0, # conductivity
		0.5, # neutral temperature
		1.0 if entry.flammable else 0.0,
		0.0, # reactivity
		entry.durability,
		0.0, # power
		false, # explosive
		false, # evaporable
		false, # alive
		false, # toxic
		false, # attractive
		false, # infectious
		false, # soluble
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
