class_name SpellCastState
extends RefCounted

var spell: SpellDef
var modifiers: Array[SpellDef] = []
var damage_add: float = 0.0
var radius_add: float = 0.0
var spread_degrees: float = 0.0
var speed_scale: float = 1.0
var speed_add: float = 0.0
var lifetime_add: float = 0.0
var critical_chance: float = 0.0
var origin_distance: float = 0.0
var fixed_angle_enabled: bool = false
var fixed_angle_degrees: float = 0.0
var add_pixel_light: bool = false
var recoil: float = 0.0
var formation_count: int = 0
var formation_start_degrees: float = 0.0
var formation_end_degrees: float = 0.0
var action_index: int = 0
var action_count: int = 1

static func build(wand: WandDef, p_spell: SpellDef, p_modifiers: Array[SpellDef], p_action_index: int, p_action_count: int) -> SpellCastState:
	var state := SpellCastState.new()
	state.spell = p_spell
	state.modifiers = p_modifiers.duplicate()
	state.action_index = p_action_index
	state.action_count = maxi(1, p_action_count)
	state.spread_degrees = (wand.spread_degrees if wand != null else 0.0) + (p_spell.spread_degrees if p_spell != null else 0.0)
	state.critical_chance = p_spell.critical_chance if p_spell != null else 0.0
	state.recoil = p_spell.recoil if p_spell != null else 0.0
	for modifier: SpellDef in p_modifiers:
		state.apply_modifier(modifier)
	return state

func apply_modifier(modifier: SpellDef) -> void:
	if modifier == null:
		return
	match modifier.modifier_operation:
		SpellDef.ModifierOperation.MULTIPLY:
			damage_add *= modifier.modifier_damage if not is_zero_approx(modifier.modifier_damage) else 1.0
			radius_add *= modifier.modifier_radius if not is_zero_approx(modifier.modifier_radius) else 1.0
			spread_degrees *= modifier.modifier_spread_degrees if not is_zero_approx(modifier.modifier_spread_degrees) else 1.0
			speed_scale *= modifier.modifier_speed_scale
			speed_add *= modifier.modifier_speed_add if not is_zero_approx(modifier.modifier_speed_add) else 1.0
			lifetime_add *= modifier.modifier_lifetime_add if not is_zero_approx(modifier.modifier_lifetime_add) else 1.0
			critical_chance *= modifier.modifier_critical_chance if not is_zero_approx(modifier.modifier_critical_chance) else 1.0
		SpellDef.ModifierOperation.SET:
			damage_add = modifier.modifier_damage
			radius_add = modifier.modifier_radius
			spread_degrees = modifier.modifier_spread_degrees
			speed_scale = modifier.modifier_speed_scale
			speed_add = modifier.modifier_speed_add
			lifetime_add = modifier.modifier_lifetime_add
			critical_chance = modifier.modifier_critical_chance
		_:
			damage_add += modifier.modifier_damage
			radius_add += modifier.modifier_radius
			spread_degrees += modifier.modifier_spread_degrees
			speed_scale *= modifier.modifier_speed_scale
			speed_add += modifier.modifier_speed_add
			lifetime_add += modifier.modifier_lifetime_add
			critical_chance += modifier.modifier_critical_chance
	origin_distance += modifier.modifier_origin_distance
	if modifier.fixed_angle_enabled:
		fixed_angle_enabled = true
		fixed_angle_degrees = modifier.fixed_angle_degrees
	add_pixel_light = add_pixel_light or modifier.add_pixel_light
	if modifier.formation_count > 0:
		formation_count = modifier.formation_count
		formation_start_degrees = modifier.formation_start_degrees
		formation_end_degrees = modifier.formation_end_degrees

func direction_for(base_direction: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var direction := base_direction.normalized() if base_direction.length_squared() > 0.0001 else Vector2.RIGHT
	if fixed_angle_enabled:
		direction = direction.rotated(deg_to_rad(fixed_angle_degrees))
	var count := formation_count if formation_count > 0 else action_count
	if count > 1:
		var index := mini(action_index, count - 1)
		var t := float(index) / float(count - 1)
		var angle := lerpf(formation_start_degrees, formation_end_degrees, t)
		direction = direction.rotated(deg_to_rad(angle))
	if spread_degrees > 0.0 and rng != null:
		direction = direction.rotated(deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees)))
	return direction.normalized()
