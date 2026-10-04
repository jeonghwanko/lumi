extends RefCounted
## Flow-review profile. Normal eight-level source data is never changed.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting("lumi/review_mode", false))
static func levels() -> Array:
	var result: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	if enabled():
		result=result.duplicate(true)
		result[0]["straw"]=3
		result[0]["moves"]=18
	return result
static func opening_seed(index: int, requested: int) -> int:
	# Seed2 has no opening match and a legal first hint that collects three yellow cats.
	return 2 if enabled() and index==0 else requested
static func save_path(normal: String) -> String:
	return normal.replace("user://", "user://review-") if enabled() else normal
