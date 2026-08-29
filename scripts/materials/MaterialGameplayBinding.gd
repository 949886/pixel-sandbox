class_name MaterialGameplayBinding
extends Resource

## Associates a native sand-slide element id with gameplay semantics without
## teaching gameplay code any engine-specific element numbers.
@export_range(0, 4096, 1) var engine_element_id: int = 0
@export var tags: Array[StringName] = []
