class_name RewardCatalog
extends Resource

@export var rewards: Array[RewardProfile] = []

var _by_id: Dictionary = {}
var _cache_ready := false


func get_reward(reward_id: StringName) -> RewardProfile:
	_ensure_cache()
	return _by_id.get(reward_id, null) as RewardProfile


func is_valid(wand_catalog: WandGenerationCatalog) -> bool:
	_ensure_cache()
	if _by_id.size() != _non_null_count():
		return false
	for reward: RewardProfile in rewards:
		if reward != null and not reward.is_valid(wand_catalog):
			return false
	return true


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for reward: RewardProfile in rewards:
		if reward == null or reward.reward_id == &"":
			continue
		if _by_id.has(reward.reward_id):
			push_error("RewardCatalog contains duplicate reward id '%s'." % str(reward.reward_id))
			continue
		_by_id[reward.reward_id] = reward
	_cache_ready = true


func _non_null_count() -> int:
	var count := 0
	for reward: RewardProfile in rewards:
		if reward != null:
			count += 1
	return count
