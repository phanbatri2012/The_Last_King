extends Node

const PROFILE_PATH := "user://profile_v1.json"

var _initialized := false


func initialize() -> bool:
	_initialized = true
	return true


func has_profile() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)


func load_profile() -> Dictionary:
	if not has_profile():
		return {}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open player profile.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Player profile is not valid JSON.")
		return {}
	return parsed


func save_profile(profile: Dictionary) -> bool:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write player profile.")
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	return true
