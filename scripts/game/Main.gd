extends Node

@export var starting_loadout: StartingLoadoutDef

@onready var _game_manager: GameManager = $GameManager
@onready var _game_bootstrap: GameBootstrap = $GameBootstrap
@onready var _game_summary_store: GameSummaryStore = $GameSummaryStore
@onready var _game_flow_ui: GameFlowUI = $GameFlowUI
@onready var _game_runtime_host: Node = $GameRuntimeHost

func _ready() -> void:
	if not _game_summary_store.setup(_game_manager):
		push_error("Failed to configure GameSummaryStore.")
		return
	if not _game_flow_ui.setup(
			_game_manager,
			_game_summary_store,
			Callable(self, "_request_quit_from_game_flow_ui"),
		):
		push_error("Failed to configure GameFlowUI.")
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


func _request_quit_from_game_flow_ui(player_id: int) -> bool:
	# Quit is a Shell decision. GameFlowUI only forwards intent and never calls
	# SceneTree.quit() directly or mutates gameplay/framework state.
	if _game_manager.lifecycle_state != GameManager.LifecycleState.ACTIVE:
		return false
	if _game_manager.game_state == null or not is_instance_valid(_game_manager.game_state):
		return false
	if _game_manager.game_state.phase != GameState.GamePhase.ENDED:
		return false
	if not _game_manager.has_player(player_id):
		return false
	get_tree().quit()
	return true
