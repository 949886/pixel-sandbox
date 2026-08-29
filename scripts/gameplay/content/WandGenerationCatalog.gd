class_name WandGenerationCatalog
extends Resource

@export var profiles: Array[WandGenerationProfile] = []

var _by_id: Dictionary = {}
var _cache_ready := false


func get_profile(profile_id: StringName) -> WandGenerationProfile:
	_ensure_cache()
	return _by_id.get(profile_id, null) as WandGenerationProfile


func is_valid() -> bool:
	_ensure_cache()
	if _by_id.size() != _non_null_count():
		return false
	for profile: WandGenerationProfile in profiles:
		if profile != null and not profile.is_valid():
			return false
	return true


func _ensure_cache() -> void:
	if _cache_ready:
		return
	_by_id.clear()
	for profile: WandGenerationProfile in profiles:
		if profile == null or profile.profile_id == &"":
			continue
		if _by_id.has(profile.profile_id):
			push_error("WandGenerationCatalog contains duplicate profile id '%s'." % str(profile.profile_id))
			continue
		_by_id[profile.profile_id] = profile
	_cache_ready = true


func _non_null_count() -> int:
	var count := 0
	for profile: WandGenerationProfile in profiles:
		if profile != null:
			count += 1
	return count
