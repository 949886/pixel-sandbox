class_name CreativeEntityDef
extends Resource

@export var entity_id: StringName = &""
@export var display_name: String = "Entity"
@export var category: StringName = &"OTHER"
@export var scene: PackedScene
@export var spell_override: SpellDef
@export_multiline var description: String = ""

func spawn(parent: Node, world_position: Vector2) -> Node:
	if scene == null or parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	var instance: Node = scene.instantiate()
	if instance == null:
		return null
	if spell_override != null and instance is SpellPickup:
		(instance as SpellPickup).spell = spell_override
	# Pre-position Node2D instances before add_child() so _ready() observes the
	# intended spawn location. Some entities cache their initial transform for
	# bobbing/animation and must not see the parent's origin for one frame.
	if instance is Node2D:
		var node_2d: Node2D = instance as Node2D
		var parent_2d: Node2D = parent as Node2D
		if parent_2d != null:
			node_2d.position = parent_2d.to_local(world_position)
		else:
			node_2d.position = world_position
	parent.add_child(instance)
	if instance is Node2D:
		(instance as Node2D).global_position = world_position
	instance.add_to_group(&"creative_spawned")
	instance.add_to_group(&"creative_deletable")
	return instance
