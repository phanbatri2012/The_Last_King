extends Node

signal run_gold_granted(amount: int, total: int, context: Dictionary)
signal run_gold_spent(amount: int, total: int, context: Dictionary)
signal run_xp_granted(amount: int, total: int, context: Dictionary)
signal account_gold_granted(amount: int, total: int, context: Dictionary)
signal account_gold_spent(amount: int, total: int, context: Dictionary)
signal run_settled(result: Dictionary, account_gold_reward: int)

var _initialized := false


func initialize() -> bool:
	_initialized = true
	return true


func grant_run_gold(amount: int, context: Dictionary = {}) -> int:
	if amount <= 0 or not GameSessionService.has_active_session():
		return 0
	GameSessionService.active_session.run_gold += amount
	run_gold_granted.emit(amount, GameSessionService.active_session.run_gold, context.duplicate(true))
	return amount


func try_spend_run_gold(amount: int, context: Dictionary = {}) -> bool:
	if amount <= 0 or not GameSessionService.has_active_session():
		return false
	if GameSessionService.active_session.run_gold < amount:
		return false
	GameSessionService.active_session.run_gold -= amount
	run_gold_spent.emit(amount, GameSessionService.active_session.run_gold, context.duplicate(true))
	return true


func get_run_gold() -> int:
	if not GameSessionService.has_active_session():
		return 0
	return GameSessionService.active_session.run_gold


func grant_run_xp(amount: int, context: Dictionary = {}) -> int:
	if amount <= 0 or not GameSessionService.has_active_session():
		return 0
	GameSessionService.active_session.run_xp += amount
	run_xp_granted.emit(amount, GameSessionService.active_session.run_xp, context.duplicate(true))
	return amount


func get_run_xp() -> int:
	if not GameSessionService.has_active_session():
		return 0
	return GameSessionService.active_session.run_xp


func grant_account_gold(amount: int, context: Dictionary = {}) -> int:
	if amount <= 0 or not PlayerProfileService.grant_resource(&"account_gold", amount):
		return 0
	var total := PlayerProfileService.get_resource(&"account_gold")
	account_gold_granted.emit(amount, total, context.duplicate(true))
	return amount


func try_purchase_account_upgrade(upgrade_id: StringName, new_level: int, cost: int) -> bool:
	if not PlayerProfileService.purchase_meta_upgrade(upgrade_id, new_level, cost):
		return false
	account_gold_spent.emit(cost, PlayerProfileService.get_resource(&"account_gold"), {
		"source_kind": "meta_upgrade",
		"upgrade_id": str(upgrade_id),
		"level": new_level,
	})
	return true


func calculate_account_gold_reward(result: Dictionary) -> int:
	var progression := ContentDatabase.get_account_progression()
	var curve: Dictionary = progression.get("reward_curve", {})
	return maxi(
		int(curve.get("base_account_gold", 0))
		+ floori(maxf(float(result.get("time", 0.0)), 0.0) / 30.0) * int(curve.get("per_30_seconds", 0))
		+ maxi(int(result.get("enemies", 0)), 0) * int(curve.get("per_enemy", 0))
		+ maxi(int(result.get("bosses", 0)), 0) * int(curve.get("per_boss", 0))
		+ maxi(int(result.get("level", 1)) - 1, 0) * int(curve.get("per_run_level_after_first", 0)),
		0
	)


func settle_active_run(result: Dictionary) -> int:
	if not GameSessionService.has_active_session():
		return 0
	var session := GameSessionService.active_session
	if bool(session.run_stats.get("account_reward_claimed", false)):
		return int(session.run_stats.get("account_gold_reward", 0))
	var reward := calculate_account_gold_reward(result)
	if not PlayerProfileService.record_completed_run(result, reward):
		return 0
	session.run_stats["account_reward_claimed"] = true
	session.run_stats["account_gold_reward"] = reward
	result["account_gold_reward"] = reward
	result["account_gold_total"] = PlayerProfileService.get_resource(&"account_gold")
	account_gold_granted.emit(reward, int(result["account_gold_total"]), {"source_kind": "completed_run", "session_id": session.session_id})
	run_settled.emit(result.duplicate(true), reward)
	return reward
