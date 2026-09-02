extends "res://scripts/progression/player_profile_service.gd"


func save() -> bool:
	profile_saved.emit()
	return true
