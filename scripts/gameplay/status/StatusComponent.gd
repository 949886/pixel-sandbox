class_name StatusComponent
extends Node

signal statuses_changed(summary: String)

@export var rules: StatusRulesDef

var wet_remaining: float = 0.0
var oiled_remaining: float = 0.0
var burning_remaining: float = 0.0
var slow_remaining: float = 0.0
var slow_factor: float = 1.0
var stun_remaining: float = 0.0
var _damage_tick_remaining: float = 0.0
var _burn_source_ref: WeakRef
var _fire_contact: bool = false
var _lava_contact: bool = false
var _toxic_contact: bool = false
var _last_summary: String = ""

@onready var health: HealthComponent = get_parent().get_node_or_null("HealthComponent") as HealthComponent

func _physics_process(delta: float) -> void:
	wet_remaining = maxf(0.0, wet_remaining - delta)
	oiled_remaining = maxf(0.0, oiled_remaining - delta)
	if wet_remaining > 0.0:
		burning_remaining = maxf(0.0, burning_remaining - delta * _rule_float(&"wet_extinguish_rate_multiplier", 1.0))
	else:
		burning_remaining = maxf(0.0, burning_remaining - delta)
	slow_remaining = maxf(0.0, slow_remaining - delta)
	stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining <= 0.0:
		slow_factor = 1.0
	_damage_tick_remaining -= delta
	if _damage_tick_remaining <= 0.0:
		_damage_tick_remaining = maxf(0.05, _rule_float(&"damage_tick_interval", 0.0))
		_apply_damage_tick()
	_emit_summary_if_changed()

func apply_environment(sensor: EnvironmentSensor, source: Node = null) -> void:
	if sensor == null:
		_fire_contact = false
		_lava_contact = false
		_toxic_contact = false
		return
	if sensor.water_contact:
		expose_wet(_rule_float(&"wet_memory_seconds", 0.0))
	if sensor.oil_contact:
		expose_oil(_rule_float(&"oil_memory_seconds", 0.0))
	if sensor.fire_contact or sensor.lava_contact:
		ignite(_rule_float(&"environment_ignite_seconds", 0.0), source)
	_fire_contact = sensor.fire_contact
	_lava_contact = sensor.lava_contact
	_toxic_contact = sensor.toxic_contact

func expose_wet(duration: float = -1.0) -> void:
	wet_remaining = maxf(wet_remaining, _rule_float(&"wet_memory_seconds", 0.0) if duration < 0.0 else duration)
	burning_remaining = minf(burning_remaining, _rule_float(&"wet_burning_cap_seconds", 0.0))

func expose_oil(duration: float = -1.0) -> void:
	oiled_remaining = maxf(oiled_remaining, _rule_float(&"oil_memory_seconds", 0.0) if duration < 0.0 else duration)

func ignite(duration: float = -1.0, source: Node = null) -> bool:
	if wet_remaining > _rule_float(&"wet_ignite_block_threshold", 0.0):
		return false
	var target_duration := _rule_float(&"base_burning_seconds", 0.0) if duration < 0.0 else duration
	if oiled_remaining > 0.0:
		target_duration *= _rule_float(&"oiled_burn_duration_multiplier", 1.0)
	burning_remaining = maxf(burning_remaining, target_duration)
	if source != null and is_instance_valid(source):
		_burn_source_ref = weakref(source)
	return true

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))
	slow_remaining = maxf(slow_remaining, maxf(0.0, duration))

func apply_stun(duration: float) -> void:
	stun_remaining = maxf(stun_remaining, maxf(0.0, duration))

func movement_speed_multiplier() -> float:
	return 0.0 if stun_remaining > 0.0 else (slow_factor if slow_remaining > 0.0 else 1.0)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func clear_all() -> void:
	wet_remaining = 0.0
	oiled_remaining = 0.0
	burning_remaining = 0.0
	slow_remaining = 0.0
	slow_factor = 1.0
	stun_remaining = 0.0
	_fire_contact = false
	_lava_contact = false
	_toxic_contact = false
	_damage_tick_remaining = 0.0
	_burn_source_ref = null
	_emit_summary_if_changed(true)

func summary_text() -> String:
	var labels: Array[String] = []
	if wet_remaining > 0.0:
		labels.append("Wet")
	if oiled_remaining > 0.0:
		labels.append("Oiled")
	if burning_remaining > 0.0:
		labels.append("Burning")
	if _toxic_contact:
		labels.append("Toxic")
	if slow_remaining > 0.0:
		labels.append("Slowed")
	if stun_remaining > 0.0:
		labels.append("Stunned")
	return " · ".join(labels)

func _apply_damage_tick() -> void:
	if health == null or health.dead:
		return
	var interval := maxf(0.05, _rule_float(&"damage_tick_interval", 0.0))
	if _lava_contact:
		_apply_damage(_rule_float(&"lava_contact_damage_per_second", 0.0) * interval, DamageTypes.Type.FIRE, &"lava")
	elif _fire_contact:
		_apply_damage(_rule_float(&"fire_contact_damage_per_second", 0.0) * interval, DamageTypes.Type.FIRE, &"fire_contact")
	elif _toxic_contact:
		_apply_damage(_rule_float(&"toxic_contact_damage_per_second", 0.0) * interval, DamageTypes.Type.TOXIC, &"toxic_contact")
	if burning_remaining > 0.0 and wet_remaining <= 0.0:
		var multiplier := _rule_float(&"oiled_burn_damage_multiplier", 1.0) if oiled_remaining > 0.0 else 1.0
		_apply_damage(_rule_float(&"burning_damage_per_second", 0.0) * interval * multiplier, DamageTypes.Type.FIRE, &"burning")

func _rule_float(property_name: StringName, fallback: float) -> float:
	if rules == null:
		return fallback
	return float(rules.get(property_name))


func _apply_damage(amount: float, type: int, tag: StringName) -> void:
	if amount <= 0.0:
		return
	var actor := get_parent() as Node2D
	var world_position := actor.global_position if actor != null else Vector2.ZERO
	var packet := DamagePacket.create(amount, type, self, _burn_source(), world_position)
	packet.tags.append(tag)
	health.take_damage(packet)

func _burn_source() -> Node:
	if _burn_source_ref == null:
		return null
	var value = _burn_source_ref.get_ref()
	if value == null or not is_instance_valid(value) or not (value is Node):
		_burn_source_ref = null
		return null
	return value as Node

func _emit_summary_if_changed(force: bool = false) -> void:
	var next := summary_text()
	if force or next != _last_summary:
		_last_summary = next
		statuses_changed.emit(next)

static func find_on(node) -> StatusComponent:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return null
	var current: Node = node as Node
	var steps := 0
	while current != null and is_instance_valid(current) and steps < 4:
		if current is StatusComponent:
			return current as StatusComponent
		var direct := current.get_node_or_null("StatusComponent") as StatusComponent
		if direct != null:
			return direct
		current = current.get_parent()
		steps += 1
	return null
