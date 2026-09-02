extends Node

signal upgrade_purchased(upgrade_id: StringName, level: int)

var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true
	if ContentDatabase.get_account_progression().is_empty():
		push_error("Account progression content is unavailable.")
		return false
	_initialized = true
	return true


func get_account_gold() -> int:
	return PlayerProfileService.get_resource(&"account_gold")


func get_upgrade_level(upgrade_id: StringName) -> int:
	return PlayerProfileService.get_meta_upgrade_level(upgrade_id)


func get_upgrade_cost(upgrade_id: StringName) -> int:
	var config := ContentDatabase.get_account_upgrade(upgrade_id)
	var level := get_upgrade_level(upgrade_id)
	var costs_value: Variant = config.get("costs", [])
	if not costs_value is Array or level < 0 or level >= costs_value.size():
		return 0
	return int(costs_value[level])


func can_purchase(upgrade_id: StringName) -> bool:
	var config := ContentDatabase.get_account_upgrade(upgrade_id)
	if config.is_empty():
		return false
	var level := get_upgrade_level(upgrade_id)
	var max_level := int(config.get("max_level", 0))
	var cost := get_upgrade_cost(upgrade_id)
	return level < max_level and cost > 0 and get_account_gold() >= cost


func try_purchase(upgrade_id: StringName) -> Dictionary:
	var config := ContentDatabase.get_account_upgrade(upgrade_id)
	if config.is_empty():
		return {"accepted": false, "reason": "unknown_upgrade"}
	var current_level := get_upgrade_level(upgrade_id)
	var max_level := int(config.get("max_level", 0))
	if current_level >= max_level:
		return {"accepted": false, "reason": "maximum_level", "level": current_level}
	var cost := get_upgrade_cost(upgrade_id)
	if cost <= 0 or not RewardGrantService.try_purchase_account_upgrade(upgrade_id, current_level + 1, cost):
		return {"accepted": false, "reason": "insufficient_account_gold", "level": current_level, "cost": cost}
	var new_level := current_level + 1
	upgrade_purchased.emit(upgrade_id, new_level)
	return {"accepted": true, "level": new_level, "cost": cost, "account_gold": get_account_gold()}


func get_combined_modifiers() -> Dictionary:
	var result := {
		"max_health_flat": 0.0,
		"attack_damage_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"armor_flat": 0.0,
		"magic_resistance_flat": 0.0,
		"starting_run_gold_flat": 0.0,
	}
	for upgrade_id_value in ContentDatabase.get_account_upgrade_ids():
		var upgrade_id := StringName(upgrade_id_value)
		var level := get_upgrade_level(upgrade_id)
		if level <= 0:
			continue
		var config := ContentDatabase.get_account_upgrade(upgrade_id)
		var effects: Dictionary = config.get("effects_per_level", {})
		for effect_key_value in effects.keys():
			var effect_key := str(effect_key_value)
			var per_level := float(effects[effect_key_value])
			if effect_key.ends_with("_multiplier"):
				result[effect_key] = float(result.get(effect_key, 1.0)) + per_level * level
			else:
				result[effect_key] = float(result.get(effect_key, 0.0)) + per_level * level
	return result


func apply_to_king_config(base_config: Dictionary, modifier_snapshot: Dictionary = {}) -> Dictionary:
	var result := base_config.duplicate(true)
	var modifiers := modifier_snapshot.duplicate(true) if not modifier_snapshot.is_empty() else get_combined_modifiers()
	var health: Dictionary = result.get("health", {}).duplicate(true)
	health["max"] = maxf(float(health.get("max", 1.0)) + float(modifiers.get("max_health_flat", 0.0)), 1.0)
	result["health"] = health
	var attack: Dictionary = result.get("attack", {}).duplicate(true)
	attack["damage"] = maxf(float(attack.get("damage", 1.0)) * float(modifiers.get("attack_damage_multiplier", 1.0)), 1.0)
	result["attack"] = attack
	var movement: Dictionary = result.get("movement", {}).duplicate(true)
	movement["speed"] = maxf(float(movement.get("speed", 1.0)) * float(modifiers.get("move_speed_multiplier", 1.0)), 1.0)
	result["movement"] = movement
	var defense: Dictionary = result.get("defense", {}).duplicate(true)
	defense["armor"] = maxf(float(defense.get("armor", 0.0)) + float(modifiers.get("armor_flat", 0.0)), 0.0)
	defense["magic_resistance"] = maxf(float(defense.get("magic_resistance", 0.0)) + float(modifiers.get("magic_resistance_flat", 0.0)), 0.0)
	result["defense"] = defense
	return result


func get_starting_run_gold(modifier_snapshot: Dictionary = {}) -> int:
	var modifiers := modifier_snapshot if not modifier_snapshot.is_empty() else get_combined_modifiers()
	return maxi(roundi(float(modifiers.get("starting_run_gold_flat", 0.0))), 0)
