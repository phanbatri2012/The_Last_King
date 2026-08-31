class_name EnemySpawnDirector
extends Node

signal spawn_requested(instance_id: String, world_position: Vector2)

@export_range(1, 100, 1) var target_population := 5
@export_range(0.0, 30.0, 0.05) var respawn_delay := 1.25
@export_range(0.0, 5.0, 0.05) var spawn_stagger := 0.2
@export_range(1.0, 5000.0, 1.0) var minimum_spawn_radius := 620.0
@export_range(1.0, 5000.0, 1.0) var maximum_spawn_radius := 820.0

var _follow_target: Node2D
var _rng := RandomNumberGenerator.new()
var _next_spawn_serial := 1
var _pending_spawn_delays: Array[float] = []
var _active := true


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
		spawn_requested.emit(_take_next_instance_id(), _take_next_spawn_position())


func ensure_population(living_population: int) -> void:
	var missing := maxi(target_population - maxi(living_population, 0) - _pending_spawn_delays.size(), 0)
	for index in missing:
		_pending_spawn_delays.append(respawn_delay + spawn_stagger * float(index))


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


func _take_next_spawn_position() -> Vector2:
	var minimum_radius := minf(minimum_spawn_radius, maximum_spawn_radius)
	var maximum_radius := maxf(minimum_spawn_radius, maximum_spawn_radius)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(minimum_radius, maximum_radius)
	return _follow_target.global_position + Vector2.from_angle(angle) * radius
