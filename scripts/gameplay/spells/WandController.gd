class_name WandController
extends Node

signal mana_changed(current: float, maximum: float)
signal spell_changed(index: int, spell: SpellDef)
signal spell_cast(spell: SpellDef)
signal deck_changed(cursor: int, total: int)
signal recharge_changed(recharging: bool, remaining: float)
signal wand_changed(definition: WandDef)

@export var wand_def: WandDef

var current_mana: float = 0.0
var selected_spell_index: int = 0
var _cast_cooldown: float = 0.0
var _recharge_remaining: float = 0.0
var _pending_recharge: float = 0.0
var _spell_recharge_accum: float = 0.0
var _deck: SpellDeckRuntime
var _rng := RandomNumberGenerator.new()
var infinite_mana: bool = false

func _ready() -> void:
	_rng.randomize()
	current_mana = maxf(0.0, wand_def.mana_max) if wand_def != null else 0.0
	_rebuild_deck()
	mana_changed.emit(current_mana, maximum_mana())
	spell_changed.emit(selected_spell_index, current_spell())

func _process(delta: float) -> void:
	_cast_cooldown = maxf(0.0, _cast_cooldown - delta)
	if _cast_cooldown <= 0.0 and _pending_recharge > 0.0 and _recharge_remaining <= 0.0:
		_recharge_remaining = _pending_recharge
		_pending_recharge = 0.0
		recharge_changed.emit(true, _recharge_remaining)
	_recharge_remaining = maxf(0.0, _recharge_remaining - delta)
	if _recharge_remaining <= 0.0 and _deck != null and _deck.empty() and _pending_recharge <= 0.0:
		_finish_recharge()
	if wand_def == null:
		return
	var maximum := maximum_mana()
	if current_mana < maximum:
		var previous := current_mana
		current_mana = clampf(current_mana + maxf(0.0, wand_def.mana_recharge_per_second) * delta, 0.0, maximum)
		if not is_equal_approx(previous, current_mana):
			mana_changed.emit(current_mana, maximum)

func try_cast(
	origin: Vector2,
	direction: Vector2,
	caster: Node,
	world_interface: Node,
	projectile_parent: Node
) -> bool:
	if wand_def == null or _deck == null or _cast_cooldown > 0.0 or is_recharging():
		return false
	if caster == null or not is_instance_valid(caster):
		return false
	if projectile_parent == null or not is_instance_valid(projectile_parent) or projectile_parent.is_queued_for_deletion():
		return false
	if _deck.empty():
		_begin_recharge()
		return false

	var draw_result := _deck.draw(maxi(1, wand_def.multicast))
	var actions: Array = draw_result.get("actions", [])
	var consumed: Array = draw_result.get("consumed", [])
	if consumed.is_empty():
		_begin_recharge()
		return false
	var total_cost := 0.0
	var cast_delay_add := 0.0
	var recharge_add := 0.0
	for card_variant in consumed:
		var card := card_variant as SpellDef
		if card == null:
			continue
		total_cost += maxf(0.0, card.mana_cost)
		cast_delay_add += card.cast_delay_add
		recharge_add += card.recharge_time_add
	if not infinite_mana and current_mana + 0.0001 < total_cost:
		# Rewind to the start of this draw so insufficient mana never eats cards.
		_deck.cursor = maxi(0, _deck.cursor - consumed.size())
		deck_changed.emit(_deck.cursor, _deck.cards.size())
		return false

	if not infinite_mana:
		current_mana = maxf(0.0, current_mana - total_cost)
		mana_changed.emit(current_mana, maximum_mana())
	_spell_recharge_accum += recharge_add
	_cast_cooldown = maxf(0.02, wand_def.cast_delay + cast_delay_add)

	var base_direction := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	for action_index: int in range(actions.size()):
		var action: Dictionary = actions[action_index]
		var spell := action.get("spell", null) as SpellDef
		if spell == null:
			continue
		var modifiers: Array[SpellDef] = []
		for modifier_variant in action.get("modifiers", []):
			if modifier_variant is SpellDef:
				modifiers.append(modifier_variant as SpellDef)
		var state := SpellCastState.build(wand_def, spell, modifiers, action_index, actions.size())
		var cast_direction := state.direction_for(base_direction, _rng)
		var cast_origin := origin + cast_direction * state.origin_distance
		var context := CastContext.create(caster, self, projectile_parent, world_interface, cast_origin.floor(), cast_direction)
		context.rng = _rng
		context.cast_state = state
		for effect: Resource in spell.cast_effects:
			if effect != null and effect.has_method("execute"):
				effect.call("execute", context)
		PixelSpellVFX.spawn_burst(
			projectile_parent,
			cast_origin.floor(),
			spell.muzzle_primary,
			spell.muzzle_secondary,
			spell.muzzle_particle_count,
			68.0,
			0.18,
			1.0,
			cast_direction,
			70.0,
			0.0
		)
		_apply_recoil(caster, cast_direction, state.recoil)
		spell_cast.emit(spell)

	selected_spell_index = _deck.cursor
	deck_changed.emit(_deck.cursor, _deck.cards.size())
	spell_changed.emit(selected_spell_index, current_spell())
	if _deck.empty():
		_begin_recharge(true)
	return not actions.is_empty()

func select_spell(index: int) -> void:
	if _deck == null or _deck.cards.is_empty() or is_recharging():
		return
	_deck.set_cursor(index)
	selected_spell_index = _deck.cursor
	spell_changed.emit(selected_spell_index, current_spell())
	deck_changed.emit(_deck.cursor, _deck.cards.size())

func select_next(delta: int) -> void:
	if _deck == null or _deck.cards.is_empty() or is_recharging():
		return
	_deck.set_cursor(posmod(_deck.cursor + delta, _deck.cards.size()))
	selected_spell_index = _deck.cursor
	spell_changed.emit(selected_spell_index, current_spell())
	deck_changed.emit(_deck.cursor, _deck.cards.size())

func current_spell() -> SpellDef:
	if _deck == null or _deck.cards.is_empty():
		return null
	if _deck.cursor >= _deck.cards.size():
		return null
	return _deck.cards[_deck.cursor]


func set_infinite_mana(enabled: bool) -> void:
	infinite_mana = enabled
	if infinite_mana:
		current_mana = maximum_mana()
		mana_changed.emit(current_mana, maximum_mana())

func set_wand_definition(definition: WandDef, refill_mana: bool = true) -> void:
	wand_def = definition
	_cast_cooldown = 0.0
	_recharge_remaining = 0.0
	_pending_recharge = 0.0
	_spell_recharge_accum = 0.0
	_rebuild_deck()
	if refill_mana or infinite_mana:
		current_mana = maximum_mana()
	else:
		current_mana = clampf(current_mana, 0.0, maximum_mana())
	mana_changed.emit(current_mana, maximum_mana())
	spell_changed.emit(selected_spell_index, current_spell())
	wand_changed.emit(wand_def)

func refresh_definition(preserve_mana: bool = true) -> void:
	var previous_mana := current_mana
	_rebuild_deck()
	_cast_cooldown = 0.0
	_recharge_remaining = 0.0
	_pending_recharge = 0.0
	_spell_recharge_accum = 0.0
	current_mana = maximum_mana() if infinite_mana else (clampf(previous_mana, 0.0, maximum_mana()) if preserve_mana else maximum_mana())
	mana_changed.emit(current_mana, maximum_mana())
	spell_changed.emit(selected_spell_index, current_spell())
	wand_changed.emit(wand_def)

func deck_cards() -> Array[SpellDef]:
	var result: Array[SpellDef] = []
	if _deck != null:
		result.assign(_deck.cards)
	return result

func reset_mana() -> void:
	current_mana = maximum_mana()
	_cast_cooldown = 0.0
	_recharge_remaining = 0.0
	_pending_recharge = 0.0
	_spell_recharge_accum = 0.0
	_rebuild_deck()
	mana_changed.emit(current_mana, maximum_mana())

func maximum_mana() -> float:
	return maxf(0.0, wand_def.mana_max) if wand_def != null else 0.0

func mana_ratio() -> float:
	var maximum := maximum_mana()
	return current_mana / maximum if maximum > 0.0 else 0.0

func is_recharging() -> bool:
	return _recharge_remaining > 0.0 or _pending_recharge > 0.0

func recharge_remaining() -> float:
	return maxf(_recharge_remaining, _pending_recharge)

func deck_cursor() -> int:
	return _deck.cursor if _deck != null else 0

func deck_size() -> int:
	return _deck.cards.size() if _deck != null else 0

func _rebuild_deck() -> void:
	_deck = SpellDeckRuntime.new(wand_def.spells if wand_def != null else [], wand_def.shuffle if wand_def != null else false)
	selected_spell_index = 0
	deck_changed.emit(0, _deck.cards.size())

func _begin_recharge(after_cast: bool = false) -> void:
	if wand_def == null:
		return
	var duration := maxf(0.0, wand_def.recharge_time + _spell_recharge_accum)
	_spell_recharge_accum = 0.0
	if duration <= 0.0:
		_finish_recharge()
		return
	if after_cast and _cast_cooldown > 0.0:
		_pending_recharge = duration
	else:
		_recharge_remaining = duration
		recharge_changed.emit(true, _recharge_remaining)

func _finish_recharge() -> void:
	if _deck == null:
		_rebuild_deck()
	else:
		_deck.reset(wand_def.shuffle if wand_def != null else false)
	_recharge_remaining = 0.0
	_pending_recharge = 0.0
	selected_spell_index = 0
	recharge_changed.emit(false, 0.0)
	deck_changed.emit(_deck.cursor, _deck.cards.size())
	spell_changed.emit(selected_spell_index, current_spell())

func _apply_recoil(caster: Node, cast_direction: Vector2, amount: float) -> void:
	if amount <= 0.0 or caster == null or not is_instance_valid(caster) or caster.is_queued_for_deletion():
		return
	if caster is CharacterBody2D:
		(caster as CharacterBody2D).velocity -= cast_direction * amount
	elif caster is RigidBody2D:
		(caster as RigidBody2D).apply_central_impulse(-cast_direction * amount)
