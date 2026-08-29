class_name GameUIContext
extends RefCounted

# GameUIManager is the only writer. UI implementations treat this object as a
# read-only dependency carrier for persistent and current-game references.
var game_manager: GameManager = null
var summary_store: GameSummaryStore = null

var game_id: int = GameManager.INVALID_GAME_ID
var game_state: GameState = null
var player_state: PlayerState = null
var player: Node = null
var gameplay_world: WorldGameplayService = null
var game_mode_manager: GameModeManager = null
var creative_brush: CreativeBrushController = null
var creative_entities: CreativeEntityController = null


func setup_persistent(manager: GameManager, store: GameSummaryStore) -> bool:
	if game_manager != null or summary_store != null:
		return game_manager == manager and summary_store == store
	if manager == null or not is_instance_valid(manager):
		return false
	if store == null or not is_instance_valid(store):
		return false
	game_manager = manager
	summary_store = store
	return true


func is_persistent_ready() -> bool:
	return game_manager != null and is_instance_valid(game_manager) \
		and summary_store != null and is_instance_valid(summary_store)


func bind_game(
		game_id_value: int,
		state: GameState,
		local_player_state: PlayerState,
		local_player: Node,
		world_service: WorldGameplayService,
		mode_manager: GameModeManager,
		brush: CreativeBrushController,
		entities: CreativeEntityController,
	) -> bool:
	if not is_persistent_ready():
		return false
	if game_id_value <= GameManager.INVALID_GAME_ID:
		return false
	if game_manager.current_game_id != game_id_value:
		return false
	if state == null or not is_instance_valid(state) or game_manager.game_state != state:
		return false
	if local_player_state == null or not is_instance_valid(local_player_state):
		return false
	if game_manager.get_player_state(local_player_state.player_id) != local_player_state:
		return false
	if local_player == null or not is_instance_valid(local_player):
		return false
	if game_manager.get_player_runtime(local_player_state.player_id) != local_player:
		return false
	if world_service == null or not is_instance_valid(world_service):
		return false
	if mode_manager == null or not is_instance_valid(mode_manager):
		return false
	if brush == null or not is_instance_valid(brush):
		return false
	if entities == null or not is_instance_valid(entities):
		return false

	if has_game() and game_id != game_id_value:
		return false

	game_id = game_id_value
	game_state = state
	player_state = local_player_state
	player = local_player
	gameplay_world = world_service
	game_mode_manager = mode_manager
	creative_brush = brush
	creative_entities = entities
	return true


func has_game() -> bool:
	return game_id > GameManager.INVALID_GAME_ID \
		and game_state != null and is_instance_valid(game_state) \
		and player_state != null and is_instance_valid(player_state) \
		and player != null and is_instance_valid(player) \
		and gameplay_world != null and is_instance_valid(gameplay_world) \
		and game_mode_manager != null and is_instance_valid(game_mode_manager) \
		and creative_brush != null and is_instance_valid(creative_brush) \
		and creative_entities != null and is_instance_valid(creative_entities)


func clear_game(expected_game_id: int = GameManager.INVALID_GAME_ID) -> bool:
	if expected_game_id != GameManager.INVALID_GAME_ID \
			and game_id != GameManager.INVALID_GAME_ID \
			and game_id != expected_game_id:
		return false

	game_id = GameManager.INVALID_GAME_ID
	game_state = null
	player_state = null
	player = null
	gameplay_world = null
	game_mode_manager = null
	creative_brush = null
	creative_entities = null
	return true
