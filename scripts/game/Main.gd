extends Node

const WORLD_SCENE: PackedScene = preload("res://scenes/World.tscn")
const DEFAULT_STARTING_LOADOUT = preload("res://resources/gameplay/loadouts/normal_starting_loadout.tres")

@onready var _game_manager: GameBootstrapManager = $GameManager
@onready var _runtime_root: Node = $GameRuntime


func _ready() -> void:
	if not _game_manager.configure_bootstrap(_runtime_root, WORLD_SCENE):
		push_error("Failed to configure the game bootstrap dependencies.")
		return

	var loadout := DEFAULT_STARTING_LOADOUT as StartingLoadoutDef
	var config := GameConfig.create_default(loadout)
	if config == null or not config.is_valid():
		push_error("Failed to create the initial GameConfig.")
		return
	if _game_manager.start_game(config) == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game.")
