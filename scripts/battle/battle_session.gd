class_name BattleSession
extends RefCounted

const SCHEMA_VERSION := 1

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
var upgrades: Dictionary = {}
var enemy_wave_state: Dictionary = {}
var boss_state: Dictionary = {}
var rng_state: Dictionary = {}
var pause_state: Dictionary = {}
var king_state: Dictionary = {
	"position": {"x": 0.0, "y": 0.0},
	"velocity": {"x": 0.0, "y": 0.0},
}


func create(new_king_id: StringName, new_faction_id: StringName, new_seed: int) -> void:
	session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(new_seed)]
	king_id = new_king_id
	faction_id = new_faction_id
	seed = new_seed


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
		"upgrades": upgrades.duplicate(true),
		"enemy_wave_state": enemy_wave_state.duplicate(true),
		"boss_state": boss_state.duplicate(true),
		"rng_state": rng_state.duplicate(true),
		"pause_state": pause_state.duplicate(true),
		"king_state": king_state.duplicate(true),
	}
