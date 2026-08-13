class_name SpellDeckRuntime
extends RefCounted

var cards: Array[SpellDef] = []
var cursor: int = 0
var _rng := RandomNumberGenerator.new()

func _init(source_cards: Array[Resource] = [], shuffle_cards: bool = false) -> void:
	_rng.randomize()
	for card: Resource in source_cards:
		if card is SpellDef:
			cards.append(card as SpellDef)
	if shuffle_cards:
		shuffle()

func empty() -> bool:
	return cards.is_empty() or cursor >= cards.size()

func remaining() -> int:
	return maxi(0, cards.size() - cursor)

func reset(shuffle_cards: bool = false) -> void:
	cursor = 0
	if shuffle_cards:
		shuffle()

func shuffle() -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var tmp := cards[index]
		cards[index] = cards[other]
		cards[other] = tmp
	cursor = 0

func set_cursor(index: int) -> void:
	if cards.is_empty():
		cursor = 0
	else:
		cursor = clampi(index, 0, cards.size() - 1)

## Returns {actions:Array[Dictionary], consumed:Array[SpellDef]}.
## Each action dictionary contains the action SpellDef and the modifier cards
## accumulated by extra-draw/multicast cards in this draw operation.
func draw(count: int = 1) -> Dictionary:
	var actions: Array[Dictionary] = []
	var consumed: Array[SpellDef] = []
	var modifiers: Array[SpellDef] = []
	var remaining_draws := maxi(1, count)
	var guard := 0
	while remaining_draws > 0 and cursor < cards.size() and guard < 64:
		guard += 1
		var card := cards[cursor]
		cursor += 1
		remaining_draws -= 1
		consumed.append(card)
		if card.is_modifier_card():
			modifiers.append(card)
			remaining_draws += maxi(0, card.extra_draw)
			continue
		if card.is_action_card():
			actions.append({"spell": card, "modifiers": modifiers.duplicate()})
		if card.extra_draw > 0:
			remaining_draws += card.extra_draw
	return {"actions": actions, "consumed": consumed}
