extends Node

const BOARD_LEGACY := &"legacy"
const BOARD_BATTLE_SCORE := &"battle_score"

var _local_scores: Dictionary = {}
var _initialized := false


func initialize() -> bool:
	_initialized = true
	return true


func submit_score(board_id: StringName, score: int) -> bool:
	var key := str(board_id)
	var previous_best := int(_local_scores.get(key, 0))
	if score > previous_best:
		_local_scores[key] = score
	if PlatformService.supports_native_leaderboard():
		return PlatformService.adapter.submit_score(key, score)
	return true


func get_local_best(board_id: StringName) -> int:
	return int(_local_scores.get(str(board_id), 0))
