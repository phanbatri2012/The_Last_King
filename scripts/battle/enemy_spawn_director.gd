class_name EnemySpawnDirector
extends Node

signal spawn_requested(instance_id: String, enemy_id: StringName, world_position: Vector2)

@export_range(1, 100, 1) var base_population := 9
@export_range(1, 100, 1) var maximum_population := 15
@export_range(1.0, 600.0, 1.0) var population_growth_interval := 45.0
@export_range(0.0, 30.0, 0.05) var respawn_delay := 1.0
@export_range(0.0, 5.0, 0.05) var spawn_stagger := 0.14
@export_range(1.0, 5000.0, 1.0) var minimum_spawn_radius := 480.0
@export_range(1.0, 5000.0, 1.0) var maximum_spawn_radius := 900.0

var _follow_target: Node2D
var _rng := RandomNumberGenerator.new()
var _spawn_roster: Array[Dictionary] = []
var _next_spawn_serial := 1
var _pending_spawn_delays: Array[float] = []
var _active := true


func set_spawn_roster(spawn_roster: Array[Dictionary]) -> void:
	_spawn_roster.clear()
	for entry in spawn_roster:
		var enemy_id := str(entry.get("enemy_id", ""))
		var weight := float(entry.get("weight", 0.0))
		if not enemy_id.is_empty() and weight > 0.0:
			_spawn_roster.append({"enemy_id": enemy_id, "weight": weight})
	if _spawn_roster.is_empty():
		_spawn_roster.append({"enemy_id": "goblin", "weight": 1.0})


func configure(seed: int, follow_target: Node2D, restored_state: Dictionary = {}) -> void:
	_follow_target = follow_target
	_rng.seed = seed
	_next_spawn_serial = maxi(int(restored_state.get("next_spawn_serial", 1)), 1)
	if restored_state.has("rng_state"):
		_rng.state = int(restored_state.get("rng_state", _rng.state))
	_pending_spawn_delays.clear()
	var pending_value: Variant = restored_state.get("pending_spawn_delays", [])
	if pending_value is Array:
		for delay_value in pending_value:
			_pending_spawn_delays.append(maxf(float(delay_value), 0.0))


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_follow_target):
		return
	for index in range(_pending_spawn_delays.size() - 1, -1, -1):
		_pending_spawn_delays[index] = maxf(_pending_spawn_delays[index] - delta, 0.0)
		if _pending_spawn_delays[index] > 0.0:
			continue
		_pending_spawn_delays.remove_at(index)
		spawn_requested.emit(_take_next_instance_id(), _take_next_enemy_id(), _take_next_spawn_position())


func get_target_population(elapsed_time: float) -> int:
	var growth_steps := floori(maxf(elapsed_time, 0.0) / maxf(population_growth_interval, 1.0))
	return mini(base_population + growth_steps, maxi(maximum_population, base_population))


func ensure_population(living_population: int, elapsed_time: float = 0.0, immediate: bool = false) -> void:
	var target_population := get_target_population(elapsed_time)
	var missing := maxi(target_population - maxi(living_population, 0) - _pending_spawn_delays.size(), 0)
	var starting_pending_count := _pending_spawn_delays.size()
	for index in missing:
		var base_delay := 0.0 if immediate else respawn_delay
		_pending_spawn_delays.append(base_delay + spawn_stagger * float(starting_pending_count + index))


func schedule_replacement(delay: float = -1.0) -> void:
	_pending_spawn_delays.append(respawn_delay if delay < 0.0 else maxf(delay, 0.0))


func set_active(active: bool) -> void:
	_active = active


func get_pending_count() -> int:
	return _pending_spawn_delays.size()


func get_runtime_snapshot() -> Dictionary:
	return {
		"next_spawn_serial": _next_spawn_serial,
		"rng_state": _rng.state,
		"pending_spawn_delays": _pending_spawn_delays.duplicate(),
	}


func _take_next_instance_id() -> String:
	var instance_key := "endless_goblin_%08d" % _next_spawn_serial
	_next_spawn_serial += 1
	return instance_key


func _take_next_enemy_id() -> StringName:
	var total_weight := 0.0
	for entry in _spawn_roster:
		total_weight += float(entry.get("weight", 0.0))
	var roll := _rng.randf_range(0.0, total_weight)
	for entry in _spawn_roster:
		roll -= float(entry.get("weight", 0.0))
		if roll <= 0.0:
			return StringName(str(entry.get("enemy_id", "goblin")))
	return StringName(str(_spawn_roster.back().get("enemy_id", "goblin")))


func _take_next_spawn_position() -> Vector2:
	var minimum_radius := minf(minimum_spawn_radius, maximum_spawn_radius)
	var maximum_radius := maxf(minimum_spawn_radius, maximum_spawn_radius)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(minimum_radius, maximum_radius)
	return _follow_target.global_position + Vector2.from_angle(angle) * radius
