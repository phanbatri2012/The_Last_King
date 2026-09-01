class_name ArmyController
extends Node2D

signal capacity_changed(used: int, maximum: int)
signal unit_summoned(unit: SummonedUnitController)
signal unit_died(unit_id: StringName, context: Dictionary)
signal upgrade_changed(unit_id: StringName, level: int, next_cost: int)

const SUMMONED_UNIT_SCENE := preload("res://scenes/gameplay/summoned_unit.tscn")
const DEFEATED_UNIT_CLEANUP_SEC := 0.65

var maximum_capacity := 20
var unlimited_summons := false
var _king: KingController
var _projectile_pool: AllyProjectilePool
var _unit_configs: Dictionary = {}
var _units: Dictionary = {}
var _next_unit_serial := 1
var _combat_enabled := true
var _upgrade_levels: Dictionary = {}


func configure(
	host_king: KingController,
	new_maximum_capacity: int,
	unit_configs: Dictionary,
	restored_units: Array = [],
	projectile_pool: AllyProjectilePool = null,
	new_unlimited_summons: bool = false,
	restored_upgrades: Dictionary = {}
) -> void:
	_king = host_king
	_projectile_pool = projectile_pool
	maximum_capacity = maxi(new_maximum_capacity, 1)
	unlimited_summons = new_unlimited_summons
	_unit_configs = unit_configs.duplicate(true)
	_upgrade_levels.clear()
	for unit_id_value in _unit_configs.keys():
		var unit_id := str(unit_id_value)
		var upgrade_data: Dictionary = _unit_configs[unit_id].get("upgrade", {})
		var max_level := maxi(int(upgrade_data.get("max_level", 1)), 1)
		_upgrade_levels[unit_id] = clampi(int(restored_upgrades.get(unit_id, 0)), 0, max_level)
	for snapshot_value in restored_units:
		if snapshot_value is Dictionary:
			var snapshot_unit_id := str(snapshot_value.get("unit_id", ""))
			if _upgrade_levels.has(snapshot_unit_id):
				_upgrade_levels[snapshot_unit_id] = maxi(int(_upgrade_levels[snapshot_unit_id]), int(snapshot_value.get("upgrade_level", 0)))
			_restore_unit(snapshot_value)
	_refresh_formation_slots()
	capacity_changed.emit(get_used_capacity(), maximum_capacity)


func try_summon(unit_id: StringName) -> Dictionary:
	var result := {
		"accepted": false,
		"reason": "unknown_unit",
		"unit": null,
		"gold_cost": 0,
		"capacity_cost": 0,
	}
	if not _combat_enabled or not is_instance_valid(_king) or not _king.is_combat_alive():
		result["reason"] = "battle_inactive"
		return result
	var config: Dictionary = _unit_configs.get(str(unit_id), {})
	if config.is_empty():
		return result
	var summon_data: Dictionary = config.get("summon", {})
	var gold_cost := maxi(int(summon_data.get("run_gold_cost", 0)), 1)
	var unit_capacity_cost := maxi(int(summon_data.get("capacity_cost", 0)), 1)
	result["gold_cost"] = gold_cost
	result["capacity_cost"] = unit_capacity_cost
	var reward_service := get_node_or_null("/root/RewardGrantService")
	if reward_service == null:
		result["reason"] = "currency_unavailable"
		return result
	if not unlimited_summons and get_used_capacity() + unit_capacity_cost > maximum_capacity:
		result["reason"] = "capacity_full"
		return result
	if int(reward_service.get_run_gold()) < gold_cost:
		result["reason"] = "insufficient_gold"
		return result
	if not bool(reward_service.try_spend_run_gold(
		gold_cost,
		{"sink": "summon", "unit_id": str(unit_id)}
	)):
		result["reason"] = "insufficient_gold"
		return result
	var instance_key := "ally_%08d" % _next_unit_serial
	_next_unit_serial += 1
	var unit := _create_unit(instance_key, unit_id, _king.global_position, -1.0)
	if unit == null:
		reward_service.grant_run_gold(gold_cost, {"source_id": "summon_refund", "unit_id": str(unit_id)})
		result["reason"] = "spawn_failed"
		return result
	result["accepted"] = true
	result["reason"] = "ok"
	result["unit"] = unit
	_refresh_formation_slots()
	capacity_changed.emit(get_used_capacity(), maximum_capacity)
	unit_summoned.emit(unit)
	var event_bus := get_node_or_null("/root/GameEventBus")
	if event_bus != null:
		event_bus.unit_summoned.emit(
			unit.unit_id,
			{"instance_id": unit.instance_id, "gold_cost": gold_cost, "capacity_cost": unit.capacity_cost}
		)
	return result


func can_summon(unit_id: StringName) -> bool:
	var config: Dictionary = _unit_configs.get(str(unit_id), {})
	if config.is_empty() or not _combat_enabled or not is_instance_valid(_king) or not _king.is_combat_alive():
		return false
	var reward_service := get_node_or_null("/root/RewardGrantService")
	if reward_service == null:
		return false
	var summon_data: Dictionary = config.get("summon", {})
	return (
		int(reward_service.get_run_gold()) >= int(summon_data.get("run_gold_cost", 0))
		and (unlimited_summons or get_used_capacity() + int(summon_data.get("capacity_cost", 0)) <= maximum_capacity)
	)


func try_upgrade(unit_id: StringName) -> Dictionary:
	var result := {"accepted": false, "reason": "unknown_unit", "level": 0, "gold_cost": 0}
	var key := str(unit_id)
	var config: Dictionary = _unit_configs.get(key, {})
	if config.is_empty():
		return result
	if not _combat_enabled or not is_instance_valid(_king) or not _king.is_combat_alive():
		result["reason"] = "battle_inactive"
		return result
	var upgrade_data: Dictionary = config.get("upgrade", {})
	var current_level := int(_upgrade_levels.get(key, 0))
	var max_level := maxi(int(upgrade_data.get("max_level", 1)), 1)
	result["level"] = current_level
	if current_level >= max_level:
		result["reason"] = "max_level"
		return result
	var gold_cost := get_upgrade_cost(unit_id)
	result["gold_cost"] = gold_cost
	var reward_service := get_node_or_null("/root/RewardGrantService")
	if reward_service == null or not bool(reward_service.try_spend_run_gold(gold_cost, {"sink": "unit_upgrade", "unit_id": key, "level": current_level + 1})):
		result["reason"] = "insufficient_gold"
		return result
	var new_level := current_level + 1
	_upgrade_levels[key] = new_level
	for unit_value in _units.values():
		var unit := unit_value as SummonedUnitController
		if is_instance_valid(unit) and str(unit.unit_id) == key:
			unit.apply_upgrade_level(new_level)
	var session_service := get_node_or_null("/root/GameSessionService")
	if session_service != null:
		session_service.set_army_upgrade_state(_upgrade_levels)
	result["accepted"] = true
	result["reason"] = "ok"
	result["level"] = new_level
	upgrade_changed.emit(unit_id, new_level, get_upgrade_cost(unit_id))
	return result


func can_upgrade(unit_id: StringName) -> bool:
	var key := str(unit_id)
	var config: Dictionary = _unit_configs.get(key, {})
	if config.is_empty() or not _combat_enabled:
		return false
	var upgrade_data: Dictionary = config.get("upgrade", {})
	if int(_upgrade_levels.get(key, 0)) >= int(upgrade_data.get("max_level", 0)):
		return false
	var reward_service := get_node_or_null("/root/RewardGrantService")
	return reward_service != null and int(reward_service.get_run_gold()) >= get_upgrade_cost(unit_id)


func get_upgrade_level(unit_id: StringName) -> int:
	return int(_upgrade_levels.get(str(unit_id), 0))


func get_upgrade_cost(unit_id: StringName) -> int:
	var key := str(unit_id)
	var config: Dictionary = _unit_configs.get(key, {})
	var upgrade_data: Dictionary = config.get("upgrade", {})
	var current_level := int(_upgrade_levels.get(key, 0))
	var max_level := int(upgrade_data.get("max_level", 0))
	if config.is_empty() or current_level >= max_level:
		return 0
	var base_cost := float(upgrade_data.get("base_gold_cost", 1))
	var growth := float(upgrade_data.get("cost_growth", 1.0))
	return maxi(roundi(base_cost * pow(growth, current_level)), 1)


func get_upgrade_levels() -> Dictionary:
	return _upgrade_levels.duplicate(true)


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	for unit_value in _units.values():
		var unit := unit_value as SummonedUnitController
		if is_instance_valid(unit):
			unit.set_combat_enabled(enabled)


func get_used_capacity() -> int:
	var used := 0
	for unit_value in _units.values():
		var unit := unit_value as SummonedUnitController
		if is_instance_valid(unit) and unit.is_combat_alive():
			used += unit.capacity_cost
	return used


func get_living_unit_count() -> int:
	return _units.size()


func get_units() -> Array[SummonedUnitController]:
	var result: Array[SummonedUnitController] = []
	for unit_value in _units.values():
		var unit := unit_value as SummonedUnitController
		if is_instance_valid(unit):
			result.append(unit)
	return result


func get_army_snapshot() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for unit_value in _units.values():
		var unit := unit_value as SummonedUnitController
		if is_instance_valid(unit) and unit.is_combat_alive():
			snapshots.append(unit.get_combat_snapshot())
	return snapshots


func _restore_unit(snapshot: Dictionary) -> void:
	var instance_key := str(snapshot.get("instance_id", ""))
	var unit_id := StringName(str(snapshot.get("unit_id", "")))
	if instance_key.is_empty() or unit_id.is_empty():
		return
	var position_data: Dictionary = snapshot.get("position", {})
	var restored_position := Vector2(
		float(position_data.get("x", _king.global_position.x)),
		float(position_data.get("y", _king.global_position.y))
	)
	_create_unit(instance_key, unit_id, restored_position, float(snapshot.get("health", -1.0)))
	var serial_text := instance_key.trim_prefix("ally_")
	if serial_text.is_valid_int():
		_next_unit_serial = maxi(_next_unit_serial, int(serial_text) + 1)


func _create_unit(
	instance_key: String,
	unit_id: StringName,
	world_position: Vector2,
	restored_health: float
) -> SummonedUnitController:
	if _units.has(instance_key) and is_instance_valid(_units[instance_key]):
		return _units[instance_key] as SummonedUnitController
	var config: Dictionary = _unit_configs.get(str(unit_id), {})
	if config.is_empty():
		return null
	var unit := SUMMONED_UNIT_SCENE.instantiate() as SummonedUnitController
	if unit == null:
		return null
	unit.global_position = world_position
	add_child(unit)
	unit.configure(config, instance_key, _king, restored_health, _projectile_pool, int(_upgrade_levels.get(str(unit_id), 0)))
	unit.defeated.connect(_on_unit_defeated)
	_units[instance_key] = unit
	return unit


func _refresh_formation_slots() -> void:
	var role_indices: Dictionary = {}
	for instance_key in _units.keys():
		var unit := _units[instance_key] as SummonedUnitController
		if not is_instance_valid(unit) or not unit.is_combat_alive():
			continue
		var config: Dictionary = _unit_configs.get(str(unit.unit_id), {})
		var formation: Dictionary = config.get("formation", {})
		var role := str(formation.get("role", "default"))
		var formation_index := int(role_indices.get(role, 0))
		unit.set_formation_offset(FormationSlotCalculator.ring_slot(formation_index, formation))
		role_indices[role] = formation_index + 1


func _on_unit_defeated(unit: SummonedUnitController, context: Dictionary) -> void:
	_units.erase(unit.instance_id)
	_refresh_formation_slots()
	capacity_changed.emit(get_used_capacity(), maximum_capacity)
	var event_context := context.duplicate(true)
	event_context["instance_id"] = unit.instance_id
	unit_died.emit(unit.unit_id, event_context)
	var event_bus := get_node_or_null("/root/GameEventBus")
	if event_bus != null:
		event_bus.unit_died.emit(unit.unit_id, event_context)
	get_tree().create_timer(DEFEATED_UNIT_CLEANUP_SEC).timeout.connect(unit.queue_free)
