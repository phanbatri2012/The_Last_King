extends Node

signal profile_loaded
signal profile_saved

const SCHEMA_VERSION := 1

var profile: Dictionary = {}
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true
	profile = SaveService.load_profile()
	if profile.is_empty():
		profile = create_default_profile()
	if not _validate_profile(profile):
		push_error("Player profile validation failed.")
		return false
	_initialized = true
	profile_loaded.emit()
	return true


func create_default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"player_id": "local_player",
		"display_name": "",
		"resources": {
			"account_gold": 0,
			"crown_gem": 0,
			"royal_seal": 0,
		},
		"kings": {},
		"units": {},
		"unlocks": ["tran_hung_dao"],
		"achievements": {},
		"statistics": {
			"total_kills": 0,
			"total_play_time_sec": 0,
			"highest_battle_score": 0,
			"longest_survival_sec": 0,
			"boss_kills": 0,
			"challenge_stars": 0,
		},
		"active_run": {},
	}


func save() -> bool:
	if not _validate_profile(profile):
		return false
	if not SaveService.save_profile(profile):
		return false
	profile_saved.emit()
	return true


func get_profile_snapshot() -> Dictionary:
	return profile.duplicate(true)


func _validate_profile(value: Dictionary) -> bool:
	return (
		int(value.get("schema_version", -1)) == SCHEMA_VERSION
		and value.get("resources", null) is Dictionary
		and value.get("statistics", null) is Dictionary
		and value.get("active_run", null) is Dictionary
	)
