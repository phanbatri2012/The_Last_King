class_name CombatDropDirector
extends Node

const DROP_SEED_SALT := 1515870810

var _rng := RandomNumberGenerator.new()
var _next_healing_serial := 1


func configure(seed: int, restored_state: Dictionary = {}) -> void:
	_rng.seed = int((seed ^ DROP_SEED_SALT) & 0x7fffffff)
	_next_healing_serial = maxi(int(restored_state.get("next_healing_serial", 1)), 1)
	if restored_state.has("rng_state"):
		_rng.state = int(restored_state.get("rng_state", _rng.state))


func roll_healing_pickup(rewards: Dictionary) -> Dictionary:
	var healing_data: Dictionary = rewards.get("healing_orb", {})
	var chance := clampf(float(healing_data.get("chance", 0.0)), 0.0, 1.0)
	var max_health_fraction := clampf(float(healing_data.get("max_health_fraction", 0.0)), 0.0, 1.0)
	if chance <= 0.0 or max_health_fraction <= 0.0 or _rng.randf() >= chance:
		return {}
	var pickup_id := "healing_orb_%08d" % _next_healing_serial
	_next_healing_serial += 1
	return {
		"pickup_id": pickup_id,
		"max_health_fraction": max_health_fraction,
	}


func get_runtime_snapshot() -> Dictionary:
	return {
		"rng_state": _rng.state,
		"next_healing_serial": _next_healing_serial,
	}
