class_name EnvironmentSensor
extends Node

signal contacts_changed

var liquid_count: int = 0
var sample_count: int = 0
var swimming: bool = false
var water_contact: bool = false
var oil_contact: bool = false
var fire_contact: bool = false
var lava_contact: bool = false
var toxic_contact: bool = false
var contact_element_ids := PackedInt32Array()

func sample_points(world_interface: Node, world_points: Array[Vector2]) -> void:
	_reset()
	if world_interface == null or not is_instance_valid(world_interface) or not world_interface.has_method("get_element_id_at_world_position"):
		contacts_changed.emit()
		return
	var palette: MaterialPalette = null
	var manager: Node = world_interface
	if world_interface is WorldGameplayService:
		manager = (world_interface as WorldGameplayService).world_manager
	if manager != null and is_instance_valid(manager):
		palette = manager.get("material_palette") as MaterialPalette
	for world_point: Vector2 in world_points:
		sample_count += 1
		var element_id := int(world_interface.call("get_element_id_at_world_position", world_point))
		contact_element_ids.append(element_id)
		var entry: MaterialEntry = palette.entry_for_element_id(element_id) if palette != null else null
		var tags := GameplayMaterialRules.tags_for(element_id, entry)
		if bool(tags["liquid"]):
			liquid_count += 1
		water_contact = water_contact or bool(tags["water"])
		oil_contact = oil_contact or bool(tags["oil"])
		fire_contact = fire_contact or bool(tags["fire"])
		lava_contact = lava_contact or bool(tags["lava"])
		toxic_contact = toxic_contact or bool(tags["toxic"])
	swimming = sample_count > 0 and liquid_count >= maxi(1, ceili(float(sample_count) * 0.5))
	contacts_changed.emit()

func _reset() -> void:
	liquid_count = 0
	sample_count = 0
	swimming = false
	water_contact = false
	oil_contact = false
	fire_contact = false
	lava_contact = false
	toxic_contact = false
	contact_element_ids = PackedInt32Array()
