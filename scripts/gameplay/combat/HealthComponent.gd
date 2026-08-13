class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, packet)
signal healed(amount: float)
signal died(packet)

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.0, 2.0, 0.01) var hit_invulnerability_seconds: float = 0.05

var current_health: float = 0.0
var dead: bool = false
var invulnerable: bool = false
var _invulnerability_remaining: float = 0.0

func _ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)

func _physics_process(delta: float) -> void:
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)

func take_damage(packet: DamagePacket) -> float:
	if dead or invulnerable or packet == null or packet.amount <= 0.0:
		return 0.0
	if _invulnerability_remaining > 0.0:
		return 0.0
	var applied := minf(current_health, packet.amount)
	current_health = maxf(0.0, current_health - applied)
	_invulnerability_remaining = hit_invulnerability_seconds
	damaged.emit(applied, packet)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0 and not dead:
		dead = true
		died.emit(packet)
	return applied

func heal(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var applied := minf(maximum_health - current_health, amount)
	if applied <= 0.0:
		return 0.0
	current_health += applied
	healed.emit(applied)
	health_changed.emit(current_health, maximum_health)
	return applied

func reset_health(new_maximum: float = -1.0) -> void:
	if new_maximum > 0.0:
		maximum_health = new_maximum
	current_health = maximum_health
	dead = false
	_invulnerability_remaining = 0.0
	health_changed.emit(current_health, maximum_health)

func health_ratio() -> float:
	return current_health / maximum_health if maximum_health > 0.0 else 0.0

static func find_on(node) -> HealthComponent:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return null
	var current: Node = node as Node
	var steps := 0
	while current != null and is_instance_valid(current) and steps < 4:
		if current is HealthComponent:
			return current as HealthComponent
		var direct := current.get_node_or_null("HealthComponent") as HealthComponent
		if direct != null:
			return direct
		current = current.get_parent()
		steps += 1
	return null
