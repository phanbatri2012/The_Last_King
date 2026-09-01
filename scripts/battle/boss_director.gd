class_name BossDirector
extends Node

signal boss_spawn_requested(request: Dictionary)

const PRE_BOSS_WARNING_SECONDS := 12.0
const POST_BOSS_RELIEF_SECONDS := 4.0

var _follow_target: Node2D
var _rng := RandomNumberGenerator.new()
var _bosses: Array[Dictionary] = []
var _ascendant_config: Dictionary = {}
var _difficulty_config: Dictionary = {}
var _spawned_boss_ids: Dictionary = {}
var _defeated_boss_ids: Dictionary = {}
var _active_boss_instance_id := ""
var _active_boss_id := ""
var _next_instance_serial := 1
var _next_ascendant_cycle := 1
var _relief_until := 0.0


func configure(
	seed: int,
	threat_config: Dictionary,
	follow_target: Node2D,
	difficulty_id: StringName = &"normal",
	restored_state: Dictionary = {}
) -> void:
	_follow_target = follow_target
	_rng.seed = seed ^ 0x5b055
	_bosses.clear()
	var bosses_value: Variant = threat_config.get("bosses", [])
	if bosses_value is Array:
		for boss_value in bosses_value:
			if boss_value is Dictionary:
				_bosses.append(boss_value.duplicate(true))
	_bosses.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("tier", 0)) < int(right.get("tier", 0))
	)
	_ascendant_config = threat_config.get("ascendant", {}).duplicate(true)
	var difficulties: Dictionary = threat_config.get("difficulty", {})
	_difficulty_config = difficulties.get(str(difficulty_id), difficulties.get("normal", {})).duplicate(true)
	_spawned_boss_ids = restored_state.get("spawned_boss_ids", {}).duplicate(true)
	_defeated_boss_ids = restored_state.get("defeated_boss_ids", {}).duplicate(true)
	_active_boss_instance_id = str(restored_state.get("active_boss_instance_id", ""))
	_active_boss_id = str(restored_state.get("active_boss_id", ""))
	_next_instance_serial = maxi(int(restored_state.get("next_instance_serial", 1)), 1)
	_next_ascendant_cycle = maxi(int(restored_state.get("next_ascendant_cycle", 1)), 1)
	_relief_until = maxf(float(restored_state.get("relief_until", 0.0)), 0.0)
	if restored_state.has("rng_state"):
		_rng.state = int(restored_state.get("rng_state", _rng.state))


func update(elapsed_time: float, has_active_boss: bool) -> void:
	if not is_instance_valid(_follow_target):
		return
	if has_active_boss:
		return
	if not _active_boss_instance_id.is_empty():
		_active_boss_instance_id = ""
		_active_boss_id = ""
	for boss in _bosses:
		var boss_id := str(boss.get("id", ""))
		if _spawned_boss_ids.has(boss_id):
			continue
		if elapsed_time + 0.001 < float(boss.get("appearance_time", INF)):
			return
		_spawn_scheduled_boss(boss)
		return
	if not _defeated_boss_ids.has("boss_goblin_god_king"):
		return
	var start_time := float(_ascendant_config.get("start_time", 1800.0))
	var interval := maxf(float(_ascendant_config.get("interval_seconds", 240.0)), 1.0)
	var due_time := start_time + float(_next_ascendant_cycle) * interval
	if elapsed_time + 0.001 >= due_time:
		_spawn_ascendant_boss(_next_ascendant_cycle)
		_next_ascendant_cycle += 1


func mark_defeated(boss_id: StringName, instance_id: String, elapsed_time: float) -> void:
	_defeated_boss_ids[str(boss_id)] = true
	if instance_id == _active_boss_instance_id:
		_active_boss_instance_id = ""
		_active_boss_id = ""
	_relief_until = maxf(_relief_until, elapsed_time + POST_BOSS_RELIEF_SECONDS)


func get_pressure_multiplier(elapsed_time: float, has_active_boss: bool) -> float:
	if has_active_boss:
		return 0.72
	if elapsed_time < _relief_until:
		return 0.6
	var next_time := get_next_boss_time()
	if next_time >= 0.0 and next_time - elapsed_time <= PRE_BOSS_WARNING_SECONDS:
		return 0.65
	return 1.0


func get_next_boss_time() -> float:
	for boss in _bosses:
		if not _spawned_boss_ids.has(str(boss.get("id", ""))):
			return float(boss.get("appearance_time", -1.0))
	if _defeated_boss_ids.has("boss_goblin_god_king"):
		return float(_ascendant_config.get("start_time", 1800.0)) + float(_next_ascendant_cycle) * float(_ascendant_config.get("interval_seconds", 240.0))
	return -1.0


func get_active_boss_id() -> StringName:
	return StringName(_active_boss_id)


func get_runtime_snapshot() -> Dictionary:
	return {
		"spawned_boss_ids": _spawned_boss_ids.duplicate(true),
		"defeated_boss_ids": _defeated_boss_ids.duplicate(true),
		"active_boss_instance_id": _active_boss_instance_id,
		"active_boss_id": _active_boss_id,
		"next_instance_serial": _next_instance_serial,
		"next_ascendant_cycle": _next_ascendant_cycle,
		"relief_until": _relief_until,
		"rng_state": _rng.state,
	}


func _spawn_scheduled_boss(boss: Dictionary) -> void:
	var boss_id := str(boss.get("id", ""))
	_spawned_boss_ids[boss_id] = true
	_emit_boss_request(boss, 0)


func _spawn_ascendant_boss(cycle: int) -> void:
	var minimum_tier := int(_ascendant_config.get("eligible_min_tier", 8))
	var maximum_tier := int(_ascendant_config.get("eligible_max_tier", 12))
	var eligible: Array[Dictionary] = []
	for boss in _bosses:
		var tier := int(boss.get("tier", 0))
		if tier >= minimum_tier and tier <= maximum_tier:
			eligible.append(boss)
	if eligible.is_empty():
		return
	_emit_boss_request(eligible[_rng.randi_range(0, eligible.size() - 1)], cycle)


func _emit_boss_request(boss: Dictionary, ascendant_cycle: int) -> void:
	var boss_id := str(boss.get("id", ""))
	var instance_id := "boss_%08d" % _next_instance_serial
	_next_instance_serial += 1
	_active_boss_instance_id = instance_id
	_active_boss_id = boss_id
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(680.0, 820.0)
	var hp_multiplier := float(_difficulty_config.get("enemy_hp", 1.0))
	var damage_multiplier := float(_difficulty_config.get("enemy_damage", 1.0))
	var cooldown_multiplier := 1.0
	if ascendant_cycle > 0:
		hp_multiplier *= 1.0 + float(_ascendant_config.get("hp_per_cycle", 0.22)) * float(ascendant_cycle)
		damage_multiplier *= 1.0 + float(_ascendant_config.get("damage_per_cycle", 0.14)) * float(ascendant_cycle)
		cooldown_multiplier = maxf(
			float(_ascendant_config.get("cooldown_floor", 0.65)),
			1.0 - float(_ascendant_config.get("cooldown_reduction_per_cycle", 0.03)) * float(ascendant_cycle)
		)
	boss_spawn_requested.emit({
		"instance_id": instance_id,
		"boss_id": boss_id,
		"boss_config": boss.duplicate(true),
		"position": _follow_target.global_position + Vector2.from_angle(angle) * radius,
		"ascendant_cycle": ascendant_cycle,
		"runtime_modifiers": {
			"hp_multiplier": hp_multiplier,
			"damage_multiplier": damage_multiplier,
			"cooldown_multiplier": cooldown_multiplier,
			"telegraph_multiplier": float(_difficulty_config.get("telegraph_multiplier", 1.0)),
			"enhanced_hp_threshold": float(_difficulty_config.get("enhanced_hp_threshold", 0.5)),
		},
	})
