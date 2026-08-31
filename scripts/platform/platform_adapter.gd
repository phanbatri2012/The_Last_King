class_name PlatformAdapter
extends RefCounted

signal pause_requested
signal resume_requested

enum Capability {
	CLOUD_SAVE,
	NATIVE_LEADERBOARD,
	REWARDED_ADS,
	INTERSTITIAL_ADS,
	IAP,
	QUIT_APPLICATION,
}

var initialized := false


func initialize() -> bool:
	initialized = true
	return true


func get_platform_name() -> String:
	return "unknown"


func get_locale() -> String:
	return OS.get_locale().replace("_", "-")


func supports(_capability: Capability) -> bool:
	return false


func save_cloud(_data: String) -> bool:
	return false


func load_cloud() -> String:
	return ""


func submit_score(_board_id: String, _score: int) -> bool:
	return false


func show_rewarded_ad() -> bool:
	return false


func purchase(_product_id: String) -> bool:
	return false


func restore_purchases() -> bool:
	return false


func request_application_quit() -> bool:
	return false
