class_name GameFlowDef
extends Resource

@export var flow_id: StringName = &""
@export var flow_scene: PackedScene


func is_valid() -> bool:
	return flow_id != &"" and flow_scene != null


func instantiate_flow() -> GameFlow:
	if not is_valid():
		return null
	var instance: Node = flow_scene.instantiate()
	var flow: GameFlow = instance as GameFlow
	if flow == null:
		if instance != null:
			instance.free()
		push_error("GameFlowDef '%s' does not instantiate a GameFlow." % str(flow_id))
		return null
	return flow
