extends Node

signal run_gold_granted(amount: int, total: int, context: Dictionary)
signal run_gold_spent(amount: int, total: int, context: Dictionary)

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
