extends Node

@export var starting_loadout: StartingLoadoutDef

@onready var _game_manager: GameManager = $GameManager
@onready var _game_bootstrap: GameBootstrap = $GameBootstrap
@onready var _game_ui_manager: GameUIManager = $GameUIManager
@onready var _game_runtime_host: Node = $GameRuntimeHost


func _ready() -> void:
	if not _game_ui_manager.setup(_game_manager):
		push_error("Failed to configure GameUIManager.")
		return
	if not _game_bootstrap.setup(_game_manager, _game_runtime_host):
		push_error("Failed to configure GameBootstrap.")
		return
	var config := GameConfig.create_default(GameConfig.DEFAULT_FLOW_ID, starting_loadout)
	if config == null or not config.is_valid() or not config.has_valid_starting_loadout():
		push_error("Failed to create the initial GameConfig.")
		return
	if _game_bootstrap.start_game(config) == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game runtime.")
