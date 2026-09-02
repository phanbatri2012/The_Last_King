extends Node

signal profile_loaded
signal profile_saved

const SCHEMA_VERSION := 2

var profile: Dictionary = {}
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true
	var loaded_profile := SaveService.load_profile()
	var migrated := false
	if loaded_profile.is_empty():
		profile = create_default_profile()
	else:
		profile = migrate_profile(loaded_profile)
		migrated = int(loaded_profile.get("schema_version", 1)) < SCHEMA_VERSION
	if not _validate_profile(profile):
		push_error("Player profile validation failed.")
		return false
	_initialized = true
	if migrated and not save():
		push_error("Migrated player profile could not be saved.")
		_initialized = false
		return false
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
		"meta_upgrades": {},
		"statistics": {
			"completed_runs": 0,
			"total_kills": 0,
			"total_play_time_sec": 0,
			"highest_battle_score": 0,
			"longest_survival_sec": 0,
			"boss_kills": 0,
			"challenge_stars": 0,
		},
		"active_run": {},
	}


func migrate_profile(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var source_version := int(migrated.get("schema_version", 1))
	if source_version > SCHEMA_VERSION:
		return {}
	if source_version < 2:
		migrated["meta_upgrades"] = {}
		var statistics_value: Variant = migrated.get("statistics", {})
		var statistics: Dictionary = statistics_value if statistics_value is Dictionary else {}
		statistics["completed_runs"] = int(statistics.get("completed_runs", 0))
		migrated["statistics"] = statistics
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated


func save() -> bool:
	if not _validate_profile(profile):
		return false
	if not SaveService.save_profile(profile):
		return false
	profile_saved.emit()
	return true


func get_profile_snapshot() -> Dictionary:
	return profile.duplicate(true)


func get_resource(resource_id: StringName) -> int:
	var resources_value: Variant = profile.get("resources", {})
	if not resources_value is Dictionary:
		return 0
	return maxi(int(resources_value.get(str(resource_id), 0)), 0)


func get_meta_upgrade_level(upgrade_id: StringName) -> int:
	var upgrades_value: Variant = profile.get("meta_upgrades", {})
	if not upgrades_value is Dictionary:
		return 0
	return maxi(int(upgrades_value.get(str(upgrade_id), 0)), 0)


func grant_resource(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	var resources: Dictionary = profile.get("resources", {})
	var key := str(resource_id)
	resources[key] = maxi(int(resources.get(key, 0)) + amount, 0)
	profile["resources"] = resources
	return save()


func purchase_meta_upgrade(upgrade_id: StringName, new_level: int, cost: int) -> bool:
	if cost <= 0 or new_level != get_meta_upgrade_level(upgrade_id) + 1 or get_resource(&"account_gold") < cost:
		return false
	var previous := profile.duplicate(true)
	var resources: Dictionary = profile.get("resources", {})
	resources["account_gold"] = int(resources.get("account_gold", 0)) - cost
	profile["resources"] = resources
	var upgrades: Dictionary = profile.get("meta_upgrades", {})
	upgrades[str(upgrade_id)] = new_level
	profile["meta_upgrades"] = upgrades
	if save():
		return true
	profile = previous
	return false


func record_completed_run(result: Dictionary, account_gold_reward: int) -> bool:
	if account_gold_reward < 0:
		return false
	var previous := profile.duplicate(true)
	var resources: Dictionary = profile.get("resources", {})
	resources["account_gold"] = maxi(int(resources.get("account_gold", 0)) + account_gold_reward, 0)
	profile["resources"] = resources
	var statistics: Dictionary = profile.get("statistics", {})
	statistics["completed_runs"] = int(statistics.get("completed_runs", 0)) + 1
	statistics["total_kills"] = int(statistics.get("total_kills", 0)) + maxi(int(result.get("enemies", 0)), 0)
	statistics["boss_kills"] = int(statistics.get("boss_kills", 0)) + maxi(int(result.get("bosses", 0)), 0)
	statistics["total_play_time_sec"] = int(statistics.get("total_play_time_sec", 0)) + maxi(floori(float(result.get("time", 0.0))), 0)
	statistics["highest_battle_score"] = maxi(int(statistics.get("highest_battle_score", 0)), int(result.get("score", 0)))
	statistics["longest_survival_sec"] = maxi(int(statistics.get("longest_survival_sec", 0)), floori(float(result.get("time", 0.0))))
	profile["statistics"] = statistics
	if save():
		return true
	profile = previous
	return false


func _validate_profile(value: Dictionary) -> bool:
	if (
		int(value.get("schema_version", -1)) != SCHEMA_VERSION
		or not value.get("resources", null) is Dictionary
		or not value.get("meta_upgrades", null) is Dictionary
		or not value.get("statistics", null) is Dictionary
		or not value.get("active_run", null) is Dictionary
	):
		return false
	var resources: Dictionary = value.get("resources", {})
	if int(resources.get("account_gold", -1)) < 0:
		return false
	var upgrades: Dictionary = value.get("meta_upgrades", {})
	for upgrade_id_value in upgrades.keys():
		var upgrade_id := StringName(str(upgrade_id_value))
		var config := ContentDatabase.get_account_upgrade(upgrade_id)
		var level := int(upgrades[upgrade_id_value])
		if config.is_empty() or level < 0 or level > int(config.get("max_level", 0)):
			return false
	return true
