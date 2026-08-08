class_name MaterialEntry
extends Resource

## One color-coded material in PieceDef.material_texture and its sand-slide binding.
## `color` is also used as the runtime display color emitted by SandSimulation.
@export var id: StringName = &"air"
@export var color: Color = Color.TRANSPARENT
@export var source_colors: Array[Color] = []
@export_range(0, 4096, 1) var engine_element_id: int = 0
@export_enum("Powder", "Static", "Liquid", "Gas", "Energy") var simulation_state: int = 1

# Native Active Block policy. Auto infers a conservative policy from the palette
# state; use Autonomous for materials with time-based behavior even while stationary.
@export_enum("Auto", "Inert", "Movable", "Reactive", "Autonomous") var activity_mode: int = 0

# Fields retained from the world-generation demo's original MaterialEntry resource.
@export var solid: bool = false
@export var liquid: bool = false
@export var flammable: bool = false
@export var density: float = 1.0
@export_range(0.0, 1.0, 0.01) var viscosity: float = 0.5
@export_range(0.0, 1.0, 0.01) var durability: float = 1.0

func effective_state() -> int:
	if liquid:
		return 2
	# A palette entry marked solid must not accidentally behave like powder.
	if solid and simulation_state == 0:
		return 1
	return simulation_state


func effective_activity_mode() -> int:
	if activity_mode >= 1 and activity_mode <= 4:
		return activity_mode
	if engine_element_id == 0:
		return 1 # INERT
	match effective_state():
		0, 2, 3:
			return 2 # MOVABLE
		4:
			return 4 # AUTONOMOUS
		1:
			return 3 # REACTIVE
	return 4

func effective_density() -> float:
	# Custom sand-slide elements multiply this normalized value by 128 internally.
	return clampf(density / 8.0, 0.0, 1.0)

func all_source_colors() -> Array[Color]:
	var result: Array[Color] = [color]
	for source_color: Color in source_colors:
		result.append(source_color)
	return result
