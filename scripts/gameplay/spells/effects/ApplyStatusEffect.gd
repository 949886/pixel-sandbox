class_name ApplyStatusEffect
extends GameplayEffect

enum StatusKind { BURNING, WET, OILED, SLOW, STUN }

@export_enum("Burning", "Wet", "Oiled", "Slow", "Stun") var status_kind: int = StatusKind.BURNING
@export var duration: float = 3.0
@export_range(0.05, 1.0, 0.05) var slow_factor: float = 0.45

func execute(context: CastContext) -> void:
	if context == null or context.target == null:
		return
	var status := StatusComponent.find_on(context.target)
	if status == null:
		return
	match status_kind:
		StatusKind.WET:
			status.expose_wet(duration)
		StatusKind.OILED:
			status.expose_oil(duration)
		StatusKind.SLOW:
			status.apply_slow(slow_factor, duration)
		StatusKind.STUN:
			status.apply_stun(duration)
		_:
			status.ignite(duration, context.caster)
