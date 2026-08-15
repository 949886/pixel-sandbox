extends Node

@onready var _game_manager: GameManager = $GameManager
@onready var _game_bootstrap: GameBootstrap = $GameBootstrap
@onready var _game_runtime: Node = $GameRuntime


func _ready() -> void:
	if not _game_bootstrap.setup(_game_manager, _game_runtime):
		push_error("Failed to configure GameBootstrap.")
		return
	var config := GameConfig.create_default()
	if config == null or not config.is_valid():
		push_error("Failed to create the initial GameConfig.")
		return
	if _game_bootstrap.start_game(config) == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game runtime.")
