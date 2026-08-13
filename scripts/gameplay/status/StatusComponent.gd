class_name StatusComponent
extends Node

signal statuses_changed(summary: String)

@export var wet_memory_seconds: float = 0.8
@export var oil_memory_seconds: float = 4.0
@export var base_burning_seconds: float = 3.0
@export var burning_damage_per_second: float = 7.0
@export var fire_contact_damage_per_second: float = 5.0
@export var lava_contact_damage_per_second: float = 24.0
@export var toxic_contact_damage_per_second: float = 10.0
@export var damage_tick_interval: float = 0.25

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
		burning_remaining = maxf(0.0, burning_remaining - delta * 4.0)
	else:
		burning_remaining = maxf(0.0, burning_remaining - delta)
	slow_remaining = maxf(0.0, slow_remaining - delta)
	stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining <= 0.0:
		slow_factor = 1.0
	_damage_tick_remaining -= delta
	if _damage_tick_remaining <= 0.0:
		_damage_tick_remaining = maxf(0.05, damage_tick_interval)
		_apply_damage_tick()
	_emit_summary_if_changed()

func apply_environment(sensor: EnvironmentSensor, source: Node = null) -> void:
	if sensor == null:
		_fire_contact = false
		_lava_contact = false
		_toxic_contact = false
		return
	if sensor.water_contact:
		expose_wet(wet_memory_seconds)
	if sensor.oil_contact:
		expose_oil(oil_memory_seconds)
	if sensor.fire_contact or sensor.lava_contact:
		ignite(0.75, source)
	_fire_contact = sensor.fire_contact
	_lava_contact = sensor.lava_contact
	_toxic_contact = sensor.toxic_contact

func expose_wet(duration: float = -1.0) -> void:
	wet_remaining = maxf(wet_remaining, wet_memory_seconds if duration < 0.0 else duration)
	burning_remaining = minf(burning_remaining, 0.25)

func expose_oil(duration: float = -1.0) -> void:
	oiled_remaining = maxf(oiled_remaining, oil_memory_seconds if duration < 0.0 else duration)

func ignite(duration: float = -1.0, source: Node = null) -> bool:
	if wet_remaining > 0.15:
		return false
	var target_duration := base_burning_seconds if duration < 0.0 else duration
	if oiled_remaining > 0.0:
		target_duration *= 1.75
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
	var interval := maxf(0.05, damage_tick_interval)
	if _lava_contact:
		_apply_damage(lava_contact_damage_per_second * interval, DamageTypes.Type.FIRE, &"lava")
	elif _fire_contact:
		_apply_damage(fire_contact_damage_per_second * interval, DamageTypes.Type.FIRE, &"fire_contact")
	elif _toxic_contact:
		_apply_damage(toxic_contact_damage_per_second * interval, DamageTypes.Type.TOXIC, &"toxic_contact")
	if burning_remaining > 0.0 and wet_remaining <= 0.0:
		var multiplier := 1.35 if oiled_remaining > 0.0 else 1.0
		_apply_damage(burning_damage_per_second * interval * multiplier, DamageTypes.Type.FIRE, &"burning")

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
