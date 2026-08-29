class_name LootSpawner
extends Object

## Stateless runtime executor for authored LootTableDef resources.
static func spawn_table(
		table: LootTableDef,
		parent: Node,
		world_position: Vector2,
		rng: RandomNumberGenerator,
		content: GameplayContentDB,
	) -> Array[Node]:
	var spawned: Array[Node] = []
	if table == null or parent == null or not is_instance_valid(parent):
		return spawned
	var source_rng := rng
	if source_rng == null:
		source_rng = RandomNumberGenerator.new()
		source_rng.randomize()
	for entry: LootEntryDef in table.entries:
		if entry == null or entry.drop_scene == null:
			continue
		if source_rng.randf() > clampf(entry.chance, 0.0, 1.0):
			continue
		var payload: Variant = entry.roll_payload(content, source_rng)
		if entry.requires_payload and payload == null:
			continue
		var instance := entry.drop_scene.instantiate()
		if instance == null:
			continue
		if entry.payload_property != &"":
			instance.set(entry.payload_property, payload)
		parent.add_child(instance)
		if instance is Node2D:
			(instance as Node2D).global_position = world_position + entry.roll_offset(source_rng)
		spawned.append(instance)
	return spawned
