class_name CafeSaveStore
extends RefCounted
## Native save storage. Browser localStorage is never read. Import browser exports
## explicitly with CafeModel.restore_save(). Atomic rename leaves the old main
## save intact if writing/flushing/verifying either temporary file fails.

const KEY = "cats-and-coffee-v2"
const OLD = "cats-and-coffee-cafe-v1"
var path: String
var last_error := ""
var fail_writes := false # Test seam: simulates an unwritable/full storage device.
var fail_stage := "" # Test seam: "backup", "commit", or "before_restore".

func _init(save_path: String = "user://cafe-save.json") -> void:
	path = preload("res://scripts/level_profile.gd").save_path(save_path)

func _path_for(key: String) -> String:
	if key == KEY: return path
	if key == KEY + ":backup": return path + ".backup"
	if key == KEY + ":before-restore": return path + ".before-restore"
	# Only an explicitly supplied native legacy JSON file can occupy this path.
	if key == OLD: return path + ".legacy-v1"
	return ""

func get_item(key: String) -> Variant:
	last_error = ""
	var target := _path_for(key)
	if target.is_empty() or not FileAccess.file_exists(target): return null
	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		last_error = "저장 파일을 읽을 수 없어요. 원본을 보존했습니다."
		return null
	var raw := file.get_as_text()
	if file.get_error() != OK:
		last_error = "저장 파일을 끝까지 읽을 수 없어요. 원본을 보존했습니다."
		return null
	return raw

func _prepare(target: String, raw: String) -> bool:
	if fail_writes:
		last_error = "저장 공간에 쓸 수 없어요. 이전 저장을 보존했습니다."
		return false
	var directory := ProjectSettings.globalize_path(target.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "저장 폴더를 만들 수 없어요. 이전 저장을 보존했습니다."
		return false
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "저장 파일을 쓸 수 없어요. 이전 저장을 보존했습니다."
		return false
	file.store_string(raw)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(target + ".tmp") != raw:
		last_error = "저장 확인에 실패했어요. 이전 저장을 보존했습니다."
		return false
	return true

func _replace(target: String) -> bool:
	# rename(2), through Godot, replaces the destination atomically on the same
	# filesystem. Do not remove the destination first.
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(target + ".tmp"), ProjectSettings.globalize_path(target))
	if error != OK:
		last_error = "저장 파일 교체에 실패했어요. 이전 저장을 보존했습니다."
		return false
	return true

func set_item(key: String, raw: String) -> bool:
	last_error = ""
	var target := _path_for(key)
	if target.is_empty():
		last_error = "알 수 없는 저장 파일이에요."
		return false
	return _prepare(target, raw) and _replace(target)

func commit(raw: String, validated_backup: Variant = null, before_restore: Variant = null) -> bool:
	last_error = ""
	if not _prepare(path, raw): return false
	if validated_backup != null:
		if fail_stage == "backup":
			last_error = "백업 저장 실패. 이전 저장을 보존했습니다."
			return false
		if not _prepare(path + ".backup", validated_backup) or not _replace(path + ".backup"): return false
	if before_restore != null:
		if fail_stage == "before_restore":
			last_error = "복원 전 원본 보존 실패. 현재 저장을 보존했습니다."
			return false
		if not _prepare(path + ".before-restore", before_restore) or not _replace(path + ".before-restore"): return false
	if fail_stage == "commit":
		last_error = "저장 교체 실패. 이전 저장을 보존했습니다."
		return false
	return _replace(path)

class MemoryStore extends RefCounted:
	var data: Dictionary
	var fail_writes := false
	var fail_stage := ""
	var last_error := ""

	func _init(initial: Dictionary = {}) -> void:
		data = initial.duplicate(true)

	func get_item(key: String) -> Variant:
		last_error = ""
		return data.get(key)

	func set_item(key: String, raw: String) -> bool:
		if fail_writes:
			last_error = "저장 실패. 이전 저장을 보존했습니다."
			return false
		data[key] = raw
		return true

	func commit(raw: String, validated_backup: Variant = null, before_restore: Variant = null) -> bool:
		last_error = ""
		if fail_writes or not fail_stage.is_empty():
			last_error = "저장 실패. 이전 저장을 보존했습니다."
			return false
		if validated_backup != null: data[KEY + ":backup"] = validated_backup
		if before_restore != null: data[KEY + ":before-restore"] = before_restore
		data[KEY] = raw
		return true
