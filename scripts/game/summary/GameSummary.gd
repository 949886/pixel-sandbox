class_name GameSummary
extends RefCounted

var game_id: int = GameManager.INVALID_GAME_ID
var result: int = GameState.GameResult.NONE
var seed: int = 0
var depth: int = 0
var gold: int = 0
var elapsed_time: float = 0.0
var enemies_killed: int = 0
var wands_collected: int = 0
var spells_collected: int = 0
var creative_used: bool = false


static func create_from_state(state: GameState, player_data: Dictionary = {}) -> GameSummary:
	if state == null or not is_instance_valid(state) or not state.is_initialized():
		return null
	if state.phase != GameState.GamePhase.ENDED:
		return null
	if state.result == GameState.GameResult.NONE:
		return null

	var summary := GameSummary.new()
	summary.game_id = state.game_id
	summary.result = state.result
	summary.seed = state.game_seed
	summary.depth = state.current_depth
	summary.gold = maxi(0, int(player_data.get("gold", 0)))
	summary.elapsed_time = maxf(0.0, state.elapsed_time)
	summary.creative_used = state.used_creative_mode
	if state.statistics != null:
		summary.enemies_killed = state.statistics.enemies_killed
		summary.wands_collected = state.statistics.wands_collected
		summary.spells_collected = state.statistics.spells_collected
	return summary


func is_valid() -> bool:
	return game_id > GameManager.INVALID_GAME_ID \
		and GameState.GameResult.values().has(result) \
		and result != GameState.GameResult.NONE \
		and depth >= 0 \
		and gold >= 0 \
		and elapsed_time >= 0.0 \
		and enemies_killed >= 0 \
		and wands_collected >= 0 \
		and spells_collected >= 0


func to_dictionary() -> Dictionary:
	return {
		"game_id": game_id,
		"result": result,
		"seed": seed,
		"depth": depth,
		"gold": gold,
		"elapsed_time": elapsed_time,
		"enemies_killed": enemies_killed,
		"wands_collected": wands_collected,
		"spells_collected": spells_collected,
		"creative_used": creative_used,
	}
