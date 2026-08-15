extends Node

@onready var _game_manager: GameManager = $GameManager
@onready var _initial_runtime_root: Node = $GameRuntime


func _ready() -> void:
	# Transitional bootstrap for #1. #35 will replace this with GameConfig,
	# seed injection and readiness-driven activation.
	var game_id: int = _game_manager.start_game()
	if game_id == GameManager.INVALID_GAME_ID:
		push_error("Failed to start the initial game runtime.")
		return
	if not _game_manager.bind_runtime_root(_initial_runtime_root):
		push_error("Failed to bind the initial game runtime root.")
		return

	# World.tscn currently performs its own setup during _ready(). Defer the
	# compatibility activation until the existing scene has completed that
	# startup. #35 will replace this with explicit world/spawn readiness.
	_mark_initial_game_started.call_deferred(game_id)


func _mark_initial_game_started(game_id: int) -> void:
	if _game_manager.current_game_id != game_id:
		return
	_game_manager.mark_game_started(game_id)
