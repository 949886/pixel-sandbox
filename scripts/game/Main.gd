extends Node

@export var gameplay_content: GameplayContentDB

@onready var _game_manager: GameManager = $GameManager
@onready var _game_bootstrap: GameBootstrap = $GameBootstrap
@onready var _game_ui_manager: GameUIManager = $GameUIManager
@onready var _game_runtime_host: Node = $GameRuntimeHost


func _ready() -> void:
	if gameplay_content == null or not gameplay_content.is_valid():
		push_error("Main: GameplayContentDB is not configured or invalid.")
		return
	_game_bootstrap.gameplay_content = gameplay_content
	if not _game_bootstrap.setup(_game_manager, _game_runtime_host):
		push_error("Failed to configure GameBootstrap.")
		return
	
	if not _game_ui_manager.setup(_game_manager):
		push_error("Failed to configure GameUIManager.")
		return

	var config := GameConfig.create_default(
		gameplay_content.default_flow_id,
		gameplay_content.default_starting_loadout,
	)
	if config == null or not config.is_valid() or not config.has_valid_starting_loadout():
		push_error("Failed to create the initial GameConfig.")
		return
	if _game_bootstrap.start_game(config) == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game runtime.")
