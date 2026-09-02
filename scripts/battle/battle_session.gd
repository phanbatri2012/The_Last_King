class_name BattleSession
extends RefCounted

const SCHEMA_VERSION := 4

var session_id := ""
var seed := 0
var king_id: StringName = &""
var faction_id: StringName = &""
var difficulty: StringName = &"normal"
var game_mode: StringName = &"story"

var elapsed_time := 0.0
var battle_score := 0
var run_level := 1
var run_xp := 0
var run_gold := 0
var revive_count := 0

var army: Array[Dictionary] = []
var skills: Dictionary = {}
var active_skills: Dictionary = {}
var account_modifiers: Dictionary = {
	"max_health_flat": 0.0,
	"attack_damage_multiplier": 1.0,
	"move_speed_multiplier": 1.0,
	"armor_flat": 0.0,
	"magic_resistance_flat": 0.0,
	"starting_run_gold_flat": 0.0,
}
var upgrades: Dictionary = {}
var enemy_wave_state: Dictionary = {}
var boss_state: Dictionary = {}
var rng_state: Dictionary = {}
var pause_state: Dictionary = {}
var run_stats: Dictionary = {
	"enemies_defeated": 0,
	"bosses_defeated": 0,
	"active_skills_cast": 0,
	"max_army_size": 0,
	"gold_collected": 0,
	"account_reward_claimed": false,
	"account_gold_reward": 0,
}
var king_state: Dictionary = {
	"position": {"x": 0.0, "y": 0.0},
	"velocity": {"x": 0.0, "y": 0.0},
	"health": {"current": -1.0, "max": -1.0},
}


func create(new_king_id: StringName, new_faction_id: StringName, new_seed: int) -> void:
	session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(new_seed)]
	king_id = new_king_id
	faction_id = new_faction_id
	seed = new_seed


static func migrate_snapshot(snapshot: Dictionary) -> Dictionary:
	var migrated := snapshot.duplicate(true)
	var source_version := int(migrated.get("schema_version", 1))
	if source_version > SCHEMA_VERSION:
		return {}
	if source_version < 3:
		migrated["active_skills"] = {}
		migrated["run_stats"] = {
			"enemies_defeated": 0,
			"bosses_defeated": 0,
			"active_skills_cast": 0,
			"max_army_size": 0,
			"gold_collected": 0,
		}
	if source_version < 4:
		var run_stats_value: Variant = migrated.get("run_stats", {})
		var migrated_stats: Dictionary = run_stats_value if run_stats_value is Dictionary else {}
		migrated_stats["account_reward_claimed"] = false
		migrated_stats["account_gold_reward"] = 0
		migrated["run_stats"] = migrated_stats
		migrated["account_modifiers"] = {
			"max_health_flat": 0.0,
			"attack_damage_multiplier": 1.0,
			"move_speed_multiplier": 1.0,
			"armor_flat": 0.0,
			"magic_resistance_flat": 0.0,
			"starting_run_gold_flat": 0.0,
		}
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id,
		"seed": seed,
		"king_id": str(king_id),
		"faction_id": str(faction_id),
		"difficulty": str(difficulty),
		"game_mode": str(game_mode),
		"elapsed_time": elapsed_time,
		"battle_score": battle_score,
		"run_level": run_level,
		"run_xp": run_xp,
		"run_gold": run_gold,
		"revive_count": revive_count,
		"army": army.duplicate(true),
		"skills": skills.duplicate(true),
		"active_skills": active_skills.duplicate(true),
		"account_modifiers": account_modifiers.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"enemy_wave_state": enemy_wave_state.duplicate(true),
		"boss_state": boss_state.duplicate(true),
		"rng_state": rng_state.duplicate(true),
		"pause_state": pause_state.duplicate(true),
		"run_stats": run_stats.duplicate(true),
		"king_state": king_state.duplicate(true),
	}
