class_name GameplayEffect
extends Resource

## Base data-driven spell effect. Subclasses act on CastContext and stay unaware
## of Player/Enemy concrete classes.
func execute(_context: CastContext) -> void:
	pass
