class_name FactionComponent
extends Node

## Small faction layer prevents projectiles from hard-coding Player/Enemy class
## checks and leaves room for summons, charm and neutral destructibles later.
enum Faction {
	NEUTRAL,
	PLAYER,
	ENEMY,
}

@export_enum("Neutral", "Player", "Enemy") var faction: int = Faction.NEUTRAL
@export var friendly_fire: bool = false

static func find_on(node) -> FactionComponent:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return null
	var current: Node = node as Node
	var steps := 0
	while current != null and is_instance_valid(current) and steps < 4:
		if current is FactionComponent:
			return current as FactionComponent
		var direct := current.get_node_or_null("FactionComponent") as FactionComponent
		if direct != null:
			return direct
		current = current.get_parent()
		steps += 1
	return null

static func can_damage(source: FactionComponent, target: FactionComponent) -> bool:
	if target == null:
		return true
	if source == null or source.faction == Faction.NEUTRAL:
		return true
	if source.friendly_fire:
		return true
	if target.faction == Faction.NEUTRAL:
		return true
	return source.faction != target.faction
