class_name IgniteEffect
extends GameplayEffect

@export var duration: float = 3.0

func execute(context: CastContext) -> void:
	if context == null or context.target == null:
		return
	var target_status := StatusComponent.find_on(context.target)
	if target_status != null:
		target_status.ignite(duration, context.caster)
