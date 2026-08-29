extends GameplayUI

var _ui_context: GameUIContext = null


func bind_context(context: GameUIContext) -> bool:
	if context == null or not context.has_game():
		return false
	_ui_context = context
	if is_node_ready():
		_bind_player()
	return true


func unbind_context() -> void:
	if _inventory_open and is_inside_tree():
		set_inventory_open(false)
	_disconnect_runtime_signals()
	_player = null
	_health = null
	_status = null
	_wand = null
	_inventory = null
	_ui_context = null


func _bind_player() -> void:
	if _ui_context == null or not _ui_context.has_game():
		return
	var next_player: Node = _ui_context.player
	if _player == next_player and _player != null:
		return

	_disconnect_runtime_signals()
	_player = next_player
	_health = _player.get_node_or_null("HealthComponent") as HealthComponent
	_status = _player.get_node_or_null("StatusComponent") as StatusComponent
	_wand = _player.get_node_or_null("WandController") as WandController
	_inventory = _player.get_node_or_null("PlayerInventory") as PlayerInventory

	_connect_object_signal(_player, &"flight_fuel_changed", Callable(self, "_on_flight_fuel_changed"))
	_connect_object_signal(_player, &"health_changed", Callable(self, "_on_health_changed"))
	_connect_object_signal(_player, &"gold_changed", Callable(self, "_on_gold_changed"))
	_connect_object_signal(_player, &"player_died", Callable(self, "_on_player_died"))
	if _status != null and not _status.statuses_changed.is_connected(_on_status_changed):
		_status.statuses_changed.connect(_on_status_changed)
	if _wand != null:
		if not _wand.mana_changed.is_connected(_on_mana_changed):
			_wand.mana_changed.connect(_on_mana_changed)
		if not _wand.spell_changed.is_connected(_on_spell_changed):
			_wand.spell_changed.connect(_on_spell_changed)
		if not _wand.deck_changed.is_connected(_on_deck_changed):
			_wand.deck_changed.connect(_on_deck_changed)
		if not _wand.recharge_changed.is_connected(_on_recharge_changed):
			_wand.recharge_changed.connect(_on_recharge_changed)
		if _wand.has_signal(&"wand_changed"):
			_connect_object_signal(_wand, &"wand_changed", Callable(self, "_on_wand_changed"))
	if _inventory != null:
		if not _inventory.inventory_changed.is_connected(_queue_inventory_refresh):
			_inventory.inventory_changed.connect(_queue_inventory_refresh)
		if not _inventory.wand_slots_changed.is_connected(_queue_inventory_refresh):
			_inventory.wand_slots_changed.connect(_queue_inventory_refresh)
		if not _inventory.equipped_wand_changed.is_connected(_on_equipped_wand_changed):
			_inventory.equipped_wand_changed.connect(_on_equipped_wand_changed)
		if not _inventory.spell_added.is_connected(_on_spell_added):
			_inventory.spell_added.connect(_on_spell_added)
		if not _inventory.inventory_full.is_connected(_on_inventory_full):
			_inventory.inventory_full.connect(_on_inventory_full)
	_refresh_all()


func _disconnect_runtime_signals() -> void:
	_disconnect_object_signal(_player, &"flight_fuel_changed", Callable(self, "_on_flight_fuel_changed"))
	_disconnect_object_signal(_player, &"health_changed", Callable(self, "_on_health_changed"))
	_disconnect_object_signal(_player, &"gold_changed", Callable(self, "_on_gold_changed"))
	_disconnect_object_signal(_player, &"player_died", Callable(self, "_on_player_died"))
	if _status != null and is_instance_valid(_status) \
			and _status.statuses_changed.is_connected(_on_status_changed):
		_status.statuses_changed.disconnect(_on_status_changed)
	if _wand != null and is_instance_valid(_wand):
		if _wand.mana_changed.is_connected(_on_mana_changed):
			_wand.mana_changed.disconnect(_on_mana_changed)
		if _wand.spell_changed.is_connected(_on_spell_changed):
			_wand.spell_changed.disconnect(_on_spell_changed)
		if _wand.deck_changed.is_connected(_on_deck_changed):
			_wand.deck_changed.disconnect(_on_deck_changed)
		if _wand.recharge_changed.is_connected(_on_recharge_changed):
			_wand.recharge_changed.disconnect(_on_recharge_changed)
		_disconnect_object_signal(_wand, &"wand_changed", Callable(self, "_on_wand_changed"))
	if _inventory != null and is_instance_valid(_inventory):
		if _inventory.inventory_changed.is_connected(_queue_inventory_refresh):
			_inventory.inventory_changed.disconnect(_queue_inventory_refresh)
		if _inventory.wand_slots_changed.is_connected(_queue_inventory_refresh):
			_inventory.wand_slots_changed.disconnect(_queue_inventory_refresh)
		if _inventory.equipped_wand_changed.is_connected(_on_equipped_wand_changed):
			_inventory.equipped_wand_changed.disconnect(_on_equipped_wand_changed)
		if _inventory.spell_added.is_connected(_on_spell_added):
			_inventory.spell_added.disconnect(_on_spell_added)
		if _inventory.inventory_full.is_connected(_on_inventory_full):
			_inventory.inventory_full.disconnect(_on_inventory_full)


func _creative_mode_active() -> bool:
	if _ui_context == null or not _ui_context.has_game():
		return false
	var manager: GameModeManager = _ui_context.game_mode_manager
	return manager != null and is_instance_valid(manager) and manager.is_creative()


func _connect_object_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and is_instance_valid(source) and source.has_signal(signal_name) \
			and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _disconnect_object_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and is_instance_valid(source) and source.has_signal(signal_name) \
			and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)
