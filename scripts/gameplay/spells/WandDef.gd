class_name WandDef
extends Resource

@export var wand_id: StringName = &"wand"
@export var display_name: String = "Wand"
@export var visual_texture: Texture2D
@export var visual_modulate: Color = Color.WHITE
@export var mana_max: float = 100.0
@export var mana_recharge_per_second: float = 28.0
@export var cast_delay: float = 0.15
@export var recharge_time: float = 0.6
@export_range(1, 16, 1) var multicast: int = 1
@export var capacity: int = 4
@export var shuffle: bool = false
@export var spread_degrees: float = 0.0
@export var spells: Array[Resource] = []
@export var precast_spells: Array[Resource] = []
