class_name EnemySpawnDirector
extends Node

signal spawn_requested(request: Dictionary)

@export_range(1, 500, 1) var base_population := 8
@export_range(1, 500, 1) var maximum_population := 220
@export_range(1, 500, 1) var hard_population_cap := 220
@export_range(0.0, 30.0, 0.05) var respawn_delay := 0.65
@export_range(0.0, 5.0, 0.01) var spawn_stagger := 0.08
@export_range(1.0, 5000.0, 1.0) var minimum_spawn_radius := 520.0
@export_range(1.0, 5000.0, 1.0) var maximum_spawn_radius := 940.0

var _follow_target: Node2D
var _rng := RandomNumberGenerator.new()
var _spawn_roster: Array[Dictionary] = []
var _threat_config: Dictionary = {}
var _difficulty_config: Dictionary = {}
var _next_spawn_serial := 1
var _pending_spawns: Array[Dictionary] = []
var _active := true
var _elapsed_time := 0.0
var _available_budget := 0.0
var _last_budget_window := -1
var _pressure_multiplier := 1.0
var _platform_name := "web"


func set_spawn_roster(spawn_roster: Array[Dictionary]) -> void:
	_spawn_roster.clear()
	for entry in spawn_roster:
		var enemy_id := str(entry.get("enemy_id", ""))
		var weight := float(entry.get("weight", 0.0))
		if enemy_id.is_empty() or weight <= 0.0:
			continue
		_spawn_roster.append({
			"enemy_id": enemy_id,
			"weight": weight,
			"cost": maxi(int(entry.get("cost", 1)), 1),
			"unlock_minute": maxf(float(entry.get("unlock_minute", 0.0)), 0.0),
			"tags": entry.get("tags", []).duplicate(),
		})
	if _spawn_roster.is_empty():
		_spawn_roster.append({"enemy_id": "goblin", "weight": 1.0, "cost": 1, "unlock_minute": 0.0, "tags": []})


func set_threat_config(config: Dictionary, platform_name: String = "web", difficulty_id: StringName = &"normal") -> void:
	_threat_config = config.duplicate(true)
	_platform_name = platform_name
	var platform_caps: Dictionary = _threat_config.get("platform_caps", {})
	var cap_config: Dictionary = platform_caps.get(platform_name, platform_caps.get("web", {}))
	maximum_population = maxi(int(cap_config.get("soft", maximum_population)), 1)
	hard_population_cap = maxi(int(cap_config.get("hard", hard_population_cap)), maximum_population)
	var difficulties: Dictionary = _threat_config.get("difficulty", {})
	_difficulty_config = difficulties.get(str(difficulty_id), difficulties.get("normal", {})).duplicate(true)


func configure(seed: int, follow_target: Node2D, restored_state: Dictionary = {}) -> void:
	_follow_target = follow_target
	_rng.seed = seed
	_next_spawn_serial = maxi(int(restored_state.get("next_spawn_serial", 1)), 1)
	if restored_state.has("rng_state"):
		_rng.state = int(restored_state.get("rng_state", _rng.state))
	_elapsed_time = maxf(float(restored_state.get("elapsed_time", 0.0)), 0.0)
	_available_budget = maxf(float(restored_state.get("available_budget", 0.0)), 0.0)
	_last_budget_window = int(restored_state.get("last_budget_window", -1))
	_pressure_multiplier = clampf(float(restored_state.get("pressure_multiplier", 1.0)), 0.2, 1.0)
	_pending_spawns.clear()
	var pending_value: Variant = restored_state.get("pending_spawns", restored_state.get("pending_spawn_delays", []))
	if pending_value is Array:
		for pending_entry in pending_value:
			if pending_entry is Dictionary:
				var restored_entry: Dictionary = pending_entry.duplicate(true)
				restored_entry["delay"] = maxf(float(restored_entry.get("delay", 0.0)), 0.0)
				_pending_spawns.append(restored_entry)
			elif pending_entry is float or pending_entry is int:
				_pending_spawns.append({"delay": maxf(float(pending_entry), 0.0)})


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_follow_target):
		return
	for index in range(_pending_spawns.size() - 1, -1, -1):
		var pending: Dictionary = _pending_spawns[index]
		pending["delay"] = maxf(float(pending.get("delay", 0.0)) - delta, 0.0)
		_pending_spawns[index] = pending
		if float(pending.get("delay", 0.0)) > 0.0:
			continue
		_pending_spawns.remove_at(index)
		spawn_requested.emit(_create_spawn_request(pending))


func get_target_population(elapsed_time: float) -> int:
	var phase := get_phase(elapsed_time)
	if phase.is_empty():
		return mini(base_population, hard_population_cap)
	var start_time := float(phase.get("start_time", 0.0))
	var end_time := maxf(float(phase.get("end_time", start_time + 1.0)), start_time + 1.0)
	var progress := clampf((maxf(elapsed_time, 0.0) - start_time) / (end_time - start_time), 0.0, 1.0)
	var minimum := int(phase.get("target_active_min", base_population))
	var maximum := int(phase.get("target_active_max", minimum))
	var desired := roundi(lerpf(float(minimum), float(maximum), progress) * _pressure_multiplier)
	return clampi(desired, 1, hard_population_cap)


func get_phase(elapsed_time: float) -> Dictionary:
	var phases_value: Variant = _threat_config.get("phases", [])
	if not phases_value is Array or phases_value.is_empty():
		return {}
	var phases: Array = phases_value
	var selected: Dictionary = phases[0] if phases[0] is Dictionary else {}
	for phase_value in phases:
		if not phase_value is Dictionary:
			continue
		var phase: Dictionary = phase_value
		if elapsed_time >= float(phase.get("start_time", 0.0)):
			selected = phase
		if elapsed_time < float(phase.get("end_time", INF)):
			break
	return selected


func get_phase_id(elapsed_time: float) -> StringName:
	return StringName(str(get_phase(elapsed_time).get("id", "phase_0")))


func get_spawn_budget(elapsed_time: float) -> int:
	var budget_config: Dictionary = _threat_config.get("budget", {})
	var minute := maxf(elapsed_time, 0.0) / 60.0
	var base := float(budget_config.get("base", 18.0))
	var linear := float(budget_config.get("linear_per_minute", 0.2))
	var quadratic := float(budget_config.get("quadratic_per_minute", 0.012))
	return maxi(roundi(base * (1.0 + linear * minute + quadratic * minute * minute) * float(_difficulty_config.get("threat_budget", 1.0))), 1)


func ensure_population(living_population: int, elapsed_time: float = 0.0, immediate: bool = false) -> void:
	_elapsed_time = maxf(elapsed_time, 0.0)
	_refresh_budget(immediate)
	var target_population := get_target_population(_elapsed_time)
	var projected_population := maxi(living_population, 0) + _pending_spawns.size()
	var missing := maxi(target_population - projected_population, 0)
	var starting_pending_count := _pending_spawns.size()
	for index in missing:
		if projected_population + index >= hard_population_cap:
			break
		var roster_entry := _take_spawn_entry(_elapsed_time, projected_population + index)
		if roster_entry.is_empty():
			break
		var cost := float(roster_entry.get("cost", 1))
		if _available_budget + 0.001 < cost:
			break
		_available_budget -= cost
		var base_delay := 0.0 if immediate else respawn_delay
		_pending_spawns.append({
			"delay": base_delay + spawn_stagger * float(starting_pending_count + index),
			"enemy_id": str(roster_entry.get("enemy_id", "goblin")),
			"elite_rank": _roll_elite_rank(projected_population + index),
		})


func schedule_replacement(delay: float = -1.0) -> void:
	var roster_entry := _take_spawn_entry(_elapsed_time, 0)
	_pending_spawns.append({
		"delay": respawn_delay if delay < 0.0 else maxf(delay, 0.0),
		"enemy_id": str(roster_entry.get("enemy_id", "goblin")),
		"elite_rank": _roll_elite_rank(0),
	})


func set_pressure_multiplier(multiplier: float) -> void:
	_pressure_multiplier = clampf(multiplier, 0.2, 1.0)


func set_active(active: bool) -> void:
	_active = active


func get_pending_count() -> int:
	return _pending_spawns.size()


func get_soft_cap() -> int:
	return maximum_population


func get_hard_cap() -> int:
	return hard_population_cap


func get_runtime_snapshot() -> Dictionary:
	return {
		"next_spawn_serial": _next_spawn_serial,
		"rng_state": _rng.state,
		"pending_spawns": _pending_spawns.duplicate(true),
		"elapsed_time": _elapsed_time,
		"available_budget": _available_budget,
		"last_budget_window": _last_budget_window,
		"pressure_multiplier": _pressure_multiplier,
		"platform_name": _platform_name,
	}


func _refresh_budget(immediate: bool) -> void:
	var interval := maxf(float(_threat_config.get("budget", {}).get("interval_seconds", 15.0)), 1.0)
	var current_window := floori(_elapsed_time / interval)
	if current_window == _last_budget_window and not immediate:
		return
	if _last_budget_window < 0:
		_last_budget_window = current_window
		_available_budget += float(get_spawn_budget(_elapsed_time))
	elif current_window > _last_budget_window:
		for window in range(_last_budget_window + 1, current_window + 1):
			_available_budget += float(get_spawn_budget(float(window) * interval))
		_last_budget_window = current_window
	var budget_cap := float(get_spawn_budget(_elapsed_time) * 2)
	_available_budget = minf(_available_budget, budget_cap)


func _take_spawn_entry(elapsed_time: float, projected_population: int) -> Dictionary:
	var phase := get_phase(elapsed_time)
	var allowed_ids: Array = phase.get("allowed_enemy_ids", [])
	var minute := elapsed_time / 60.0
	var normal_candidates: Array[Dictionary] = []
	var special_candidates: Array[Dictionary] = []
	for entry in _spawn_roster:
		var enemy_id := str(entry.get("enemy_id", ""))
		if not allowed_ids.is_empty() and enemy_id not in allowed_ids:
			continue
		if minute + 0.001 < float(entry.get("unlock_minute", 0.0)):
			continue
		var tags: Array = entry.get("tags", [])
		if "special" in tags or "support" in tags:
			special_candidates.append(entry)
		else:
			normal_candidates.append(entry)
	var support_ratio := clampf(float(phase.get("support_budget_ratio", 0.0)), 0.0, 0.3)
	var use_special := not special_candidates.is_empty() and _rng.randf() < support_ratio
	var candidates := special_candidates if use_special else normal_candidates
	if candidates.is_empty():
		candidates = special_candidates if not special_candidates.is_empty() else _spawn_roster
	if projected_population >= maximum_population:
		var quality_candidates: Array[Dictionary] = []
		for entry in candidates:
			var tags: Array = entry.get("tags", [])
			if "elite" in tags or "ascendant" in tags or int(entry.get("cost", 1)) >= 4:
				quality_candidates.append(entry)
		if not quality_candidates.is_empty():
			candidates = quality_candidates
	var total_weight := 0.0
	for entry in candidates:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total_weight)
	for entry in candidates:
		roll -= float(entry.get("weight", 0.0))
		if roll <= 0.0:
			return entry
	return candidates.back()


func _roll_elite_rank(projected_population: int) -> int:
	var phase := get_phase(_elapsed_time)
	var density := clampf(float(phase.get("elite_density", 0.0)), 0.0, 1.0)
	var rank := 1 if _rng.randf() < density else 0
	if projected_population >= maximum_population:
		rank = maxi(rank, 1 + floori(maxf(_elapsed_time / 60.0 - 10.0, 0.0) / 5.0))
	return rank


func _create_spawn_request(pending: Dictionary) -> Dictionary:
	var elite_rank := maxi(int(pending.get("elite_rank", 0)), 0)
	var scaling: Dictionary = _threat_config.get("scaling", {})
	var minute := _elapsed_time / 60.0
	var quality_multiplier := 1.0 + float(elite_rank) * 0.32
	var hp_multiplier := (1.0 + float(scaling.get("hp_linear", 0.14)) * minute + float(scaling.get("hp_quadratic", 0.018)) * minute * minute)
	hp_multiplier *= float(_difficulty_config.get("enemy_hp", 1.0)) * quality_multiplier
	var damage_multiplier := (1.0 + float(scaling.get("damage_linear", 0.1)) * minute + float(scaling.get("damage_quadratic", 0.009)) * minute * minute)
	damage_multiplier *= float(_difficulty_config.get("enemy_damage", 1.0)) * (1.0 + float(elite_rank) * 0.18)
	var speed_multiplier := minf(float(scaling.get("speed_cap", 1.35)), 1.0 + float(scaling.get("speed_linear", 0.012)) * minute)
	return {
		"instance_id": _take_next_instance_id(),
		"enemy_id": str(pending.get("enemy_id", "goblin")),
		"position": _take_next_spawn_position(),
		"runtime_modifiers": {
			"hp_multiplier": hp_multiplier,
			"damage_multiplier": damage_multiplier,
			"speed_multiplier": speed_multiplier,
			"defense_multiplier": 1.0 + float(elite_rank) * 0.16,
			"elite_rank": elite_rank,
			"spawn_minute": minute,
		},
	}


func _take_next_instance_id() -> String:
	var instance_key := "endless_goblin_%08d" % _next_spawn_serial
	_next_spawn_serial += 1
	return instance_key


func _take_next_spawn_position() -> Vector2:
	var minimum_radius := minf(minimum_spawn_radius, maximum_spawn_radius)
	var maximum_radius := maxf(minimum_spawn_radius, maximum_spawn_radius)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(minimum_radius, maximum_radius)
	return _follow_target.global_position + Vector2.from_angle(angle) * radius
