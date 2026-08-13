class_name ProjectileDef
extends Resource

@export_category("Motion")
@export var speed: float = 700.0
@export var lifetime: float = 1.5
@export var gravity: float = 0.0
@export var collision_query_mask: int = 5
@export var detonate_on_timeout: bool = false
@export var can_bounce: bool = false
@export_range(0, 12, 1) var max_bounces: int = 0
@export_range(0.05, 1.25, 0.05) var bounce_energy: float = 0.82
@export var can_pierce: bool = false
@export_range(0, 12, 1) var max_pierces: int = 0

@export_category("Impact")
@export var impact_effects: Array[Resource] = []

@export_category("World trail")
@export var trail_material_element_id: int = -1
@export var trail_material_radius: float = 0.0
@export var trail_material_interval: float = 0.08
@export var trail_material_only_air: bool = true

@export_category("Pixel visual")
@export var primary_color := Color(0.85, 1.0, 1.0, 1.0)
@export var secondary_color := Color(0.35, 0.85, 1.0, 1.0)
@export_range(1.0, 8.0, 1.0) var core_pixel_size: float = 2.0
@export_range(0, 24, 1) var trail_length: int = 7
@export_range(1.0, 12.0, 0.5) var trail_spacing: float = 4.0
@export_range(0, 40, 1) var impact_particle_count: int = 10
@export_range(1.0, 5.0, 1.0) var impact_pixel_size: float = 2.0
@export var impact_particle_speed: float = 85.0
@export var trail_jitter: float = 1.0
@export_range(0, 5, 1) var satellite_pixels: int = 0
