class_name SpellDef
extends Resource

## Unified spell-card resource. This keeps the useful semantics of the previous
## Luna C# Spell/Card model while remaining compatible with the V4.1 effect stack.
enum Kind {
	PROJECTILE,
	MATERIAL,
	PASSIVE,
	UTILITY,
	STATIC,
	MODIFIER,
	MULTICAST,
	OTHER,
}

enum ModifierOperation {
	ADD,
	MULTIPLY,
	SET,
}

@export_category("Card")
@export var spell_id: StringName = &"spell"
@export var display_name: String = "Spell"
@export var icon: Texture2D ## Direct resource reference; UI never resolves icons by path at runtime.
@export_multiline var description: String = ""
@export var tier: int = 0
@export var extra_draw: int = 0
@export var tags: PackedStringArray = PackedStringArray()
@export_enum("Projectile", "Material", "Passive", "Utility", "Static", "Modifier", "Multicast", "Other") var kind: int = Kind.PROJECTILE
@export var uses: int = 0 ## 0 = unlimited

@export_category("Cast economics")
@export var mana_cost: float = 5.0
@export var cast_delay_add: float = 0.0
@export var recharge_time_add: float = 0.0
@export var spread_degrees: float = 0.0
@export var recoil: float = 0.0
@export var critical_chance: float = 0.0

@export_category("Effects")
@export var cast_effects: Array[Resource] = []

@export_category("Modifier card")
@export_enum("Add", "Multiply", "Set") var modifier_operation: int = ModifierOperation.ADD
@export var modifier_damage: float = 0.0
@export var modifier_radius: float = 0.0
@export var modifier_spread_degrees: float = 0.0
@export var modifier_speed_scale: float = 1.0
@export var modifier_speed_add: float = 0.0
@export var modifier_lifetime_add: float = 0.0
@export var modifier_critical_chance: float = 0.0
@export var modifier_origin_distance: float = 0.0
@export var fixed_angle_enabled: bool = false
@export var fixed_angle_degrees: float = 0.0
@export var add_pixel_light: bool = false

@export_category("Multicast / formation")
@export_range(0, 16, 1) var formation_count: int = 0
@export var formation_start_degrees: float = 0.0
@export var formation_end_degrees: float = 0.0

@export_category("Pixel muzzle")
@export var muzzle_primary := Color(0.85, 1.0, 1.0, 1.0)
@export var muzzle_secondary := Color(0.35, 0.85, 1.0, 1.0)
@export_range(0, 32, 1) var muzzle_particle_count: int = 6

func is_modifier_card() -> bool:
	return kind == Kind.MODIFIER or kind == Kind.MULTICAST

func is_action_card() -> bool:
	return not is_modifier_card() and kind != Kind.PASSIVE
