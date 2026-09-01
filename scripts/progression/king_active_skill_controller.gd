class_name KingActiveSkillController
extends Node2D

signal resource_changed(current: float, maximum: float)
signal skill_state_changed
signal skill_cast(skill_id: StringName, affected_targets: int)

var _king: KingController
var _projectile_pool: AllyProjectilePool
var _system: Dictionary = {}
var _skills_by_slot: Dictionary = {}
var _cooldowns: Dictionary = {}
var _rage := 0.0
var _maximum_rage := 100.0
var _guard_remaining := 0.0
var _guard_armor_bonus := 0.0
var _guard_magic_resistance_bonus := 0.0
var _cast_pulse := 0.0
var _cast_effect_type := ""
var _cast_direction := Vector2.RIGHT
var _cast_radius := 0.0
var _cast_half_angle := 0.0
var _visual_phase := 0.0


func _ready() -> void:
	z_index = 4
	var event_bus := get_node_or_null("/root/GameEventBus")
	if event_bus != null:
		if not event_bus.damage_resolved.is_connected(_on_damage_resolved):
			event_bus.damage_resolved.connect(_on_damage_resolved)
		if not event_bus.enemy_killed.is_connected(_on_enemy_killed):
			event_bus.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_king):
		return
	global_position = _king.global_position
	_visual_phase = fmod(_visual_phase + delta * 4.5, TAU)
	_cast_pulse = maxf(_cast_pulse - delta * 1.7, 0.0)
	var cooldown_changed := false
	for slot_value in _cooldowns.keys():
		var old_remaining := float(_cooldowns.get(slot_value, 0.0))
		var new_remaining := maxf(old_remaining - delta, 0.0)
		_cooldowns[slot_value] = new_remaining
		cooldown_changed = cooldown_changed or (old_remaining > 0.0 and new_remaining <= 0.0)
	if _guard_remaining > 0.0:
		_guard_remaining = maxf(_guard_remaining - delta, 0.0)
		if _guard_remaining <= 0.0:
			_guard_armor_bonus = 0.0
			_guard_magic_resistance_bonus = 0.0
			_king.set_temporary_defense_bonus(0.0, 0.0)
			cooldown_changed = true
	if _king.is_combat_alive():
		add_rage(float(_system.get("passive_gain_per_second", 0.0)) * delta)
	if cooldown_changed:
		skill_state_changed.emit()
	queue_redraw()


func configure(
	host_king: KingController,
	projectile_pool: AllyProjectilePool,
	system: Dictionary,
	loadout: Array[Dictionary],
	restored_state: Dictionary = {}
) -> void:
	_king = host_king
	_projectile_pool = projectile_pool
	_system = system.duplicate(true)
	_maximum_rage = maxf(float(_system.get("maximum", 100.0)), 1.0)
	_skills_by_slot.clear()
	_cooldowns.clear()
	for skill in loadout:
		var slot := clampi(int(skill.get("slot", 0)), 1, 3)
		_skills_by_slot[slot] = skill.duplicate(true)
		_cooldowns[slot] = 0.0
	var restored_cooldowns: Dictionary = restored_state.get("cooldowns", {})
	for slot in _skills_by_slot.keys():
		_cooldowns[slot] = maxf(float(restored_cooldowns.get(str(slot), restored_cooldowns.get(slot, 0.0))), 0.0)
	_rage = clampf(float(restored_state.get("rage", _system.get("starting", 0.0))), 0.0, _maximum_rage)
	_guard_remaining = maxf(float(restored_state.get("guard_remaining", 0.0)), 0.0)
	_guard_armor_bonus = maxf(float(restored_state.get("guard_armor_bonus", 0.0)), 0.0)
	_guard_magic_resistance_bonus = maxf(float(restored_state.get("guard_magic_resistance_bonus", 0.0)), 0.0)
	if is_instance_valid(_king):
		_king.set_temporary_defense_bonus(_guard_armor_bonus, _guard_magic_resistance_bonus)
	resource_changed.emit(_rage, _maximum_rage)
	skill_state_changed.emit()


func try_cast_slot(slot: int) -> Dictionary:
	var result := {"accepted": false, "reason": "invalid_slot", "slot": slot, "skill_id": "", "affected_targets": 0}
	if not _skills_by_slot.has(slot) or not is_instance_valid(_king) or not _king.is_combat_alive():
		return result
	var skill: Dictionary = _skills_by_slot[slot]
	var skill_id := StringName(str(skill.get("id", "")))
	result["skill_id"] = str(skill_id)
	if float(_cooldowns.get(slot, 0.0)) > 0.0:
		result["reason"] = "cooldown"
		return result
	var rage_cost := maxf(float(skill.get("rage_cost", 0.0)), 0.0)
	if _rage + 0.001 < rage_cost:
		result["reason"] = "insufficient_rage"
		return result
	if str(skill.get("effect_type", "")) == "piercing_fan" and not is_instance_valid(_projectile_pool):
		result["reason"] = "projectile_pool_unavailable"
		return result
	set_rage(_rage - rage_cost)
	_cooldowns[slot] = maxf(float(skill.get("cooldown", 1.0)), 0.05)
	var affected := _execute_skill(skill)
	result["accepted"] = true
	result["reason"] = ""
	result["affected_targets"] = affected
	skill_state_changed.emit()
	skill_cast.emit(skill_id, affected)
	return result


func add_rage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var old_rage := _rage
	set_rage(_rage + amount)
	return _rage - old_rage


func set_rage(amount: float) -> void:
	var safe_value := clampf(amount, 0.0, _maximum_rage)
	if is_equal_approx(safe_value, _rage):
		return
	var old_display_value := floori(_rage)
	_rage = safe_value
	if floori(_rage) != old_display_value or is_zero_approx(_rage) or is_equal_approx(_rage, _maximum_rage):
		resource_changed.emit(_rage, _maximum_rage)


func get_rage() -> float:
	return _rage


func get_maximum_rage() -> float:
	return _maximum_rage


func get_skill_config(slot: int) -> Dictionary:
	return _skills_by_slot.get(slot, {}).duplicate(true)


func get_slot_state(slot: int) -> Dictionary:
	var skill: Dictionary = _skills_by_slot.get(slot, {})
	if skill.is_empty():
		return {}
	var cooldown := maxf(float(_cooldowns.get(slot, 0.0)), 0.0)
	var cost := maxf(float(skill.get("rage_cost", 0.0)), 0.0)
	return {
		"slot": slot,
		"skill_id": str(skill.get("id", "")),
		"rage_cost": cost,
		"cooldown_remaining": cooldown,
		"ready": cooldown <= 0.0 and _rage + 0.001 >= cost and is_instance_valid(_king) and _king.is_combat_alive(),
		"has_rage": _rage + 0.001 >= cost,
	}


func get_runtime_snapshot() -> Dictionary:
	var cooldown_snapshot: Dictionary = {}
	for slot in _cooldowns.keys():
		cooldown_snapshot[str(slot)] = maxf(float(_cooldowns[slot]), 0.0)
	return {
		"rage": _rage,
		"cooldowns": cooldown_snapshot,
		"guard_remaining": _guard_remaining,
		"guard_armor_bonus": _guard_armor_bonus,
		"guard_magic_resistance_bonus": _guard_magic_resistance_bonus,
	}


func _execute_skill(skill: Dictionary) -> int:
	var effect_type := str(skill.get("effect_type", ""))
	var effect: Dictionary = skill.get("effect", {})
	_cast_effect_type = effect_type
	_cast_direction = _get_aim_direction()
	_cast_radius = float(effect.get("radius", 0.0))
	_cast_half_angle = deg_to_rad(float(effect.get("half_angle_degrees", 0.0)))
	_cast_pulse = 1.0
	_king.visual.play_attack(_cast_direction)
	match effect_type:
		"directional_cone":
			return _cast_directional_cone(StringName(str(skill.get("id", ""))), effect)
		"royal_guard":
			return _cast_royal_guard(StringName(str(skill.get("id", ""))), effect)
		"piercing_fan":
			return _cast_piercing_fan(StringName(str(skill.get("id", ""))), effect)
	return 0


func _cast_directional_cone(skill_id: StringName, effect: Dictionary) -> int:
	var radius := maxf(float(effect.get("radius", 280.0)), 1.0)
	var minimum_dot := cos(deg_to_rad(clampf(float(effect.get("half_angle_degrees", 65.0)), 1.0, 180.0)))
	var damage := _king.auto_attack.attack_damage * maxf(float(effect.get("damage_multiplier", 1.0)), 0.01)
	var affected := 0
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as GoblinController
		if not is_instance_valid(enemy) or not enemy.is_combat_alive():
			continue
		var offset := enemy.global_position - _king.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance > radius or _cast_direction.dot(offset / distance) < minimum_dot:
			continue
		DamageResolver.apply_damage(enemy.health, damage, _create_damage_context(skill_id, "melee", enemy), enemy.defense)
		affected += 1
	return affected


func _cast_royal_guard(skill_id: StringName, effect: Dictionary) -> int:
	_guard_remaining = maxf(float(effect.get("duration", 4.0)), 0.1)
	_guard_armor_bonus = maxf(float(effect.get("armor_bonus", 0.0)), 0.0)
	_guard_magic_resistance_bonus = maxf(float(effect.get("magic_resistance_bonus", 0.0)), 0.0)
	_king.set_temporary_defense_bonus(_guard_armor_bonus, _guard_magic_resistance_bonus)
	var healing := _king.health.max_health * clampf(float(effect.get("heal_max_health_fraction", 0.0)), 0.0, 1.0)
	var healing_result := HealingResolver.apply_healing(_king.health, healing, {
		"source_kind": "king_active_skill",
		"source_id": str(skill_id),
		"target_kind": "king",
	})
	return 1 if bool(healing_result.get("accepted", false)) else 0


func _cast_piercing_fan(skill_id: StringName, effect: Dictionary) -> int:
	var projectile_count := maxi(int(effect.get("projectile_count", 7)), 1)
	var spread := deg_to_rad(maxf(float(effect.get("spread_degrees", 60.0)), 0.0))
	var starting_angle := _cast_direction.angle() - spread * 0.5
	var angle_step := spread / float(projectile_count - 1) if projectile_count > 1 else 0.0
	var damage := _king.auto_attack.attack_damage * maxf(float(effect.get("damage_multiplier", 1.0)), 0.01)
	var spawned := 0
	for index in projectile_count:
		var direction := Vector2.from_angle(starting_angle + angle_step * float(index))
		var projectile := _projectile_pool.request_projectile({
			"projectile_id": "%s_%d" % [str(skill_id), index],
			"position": _king.global_position + direction * (_king.collision_radius + 14.0),
			"direction": direction,
			"speed": float(effect.get("projectile_speed", 900.0)),
			"radius": float(effect.get("projectile_radius", 10.0)),
			"lifetime": float(effect.get("projectile_lifetime", 1.4)),
			"visual_kind": "royal_wave",
			"damage": damage,
			"damage_type": "physical",
			"piercing": true,
			"maximum_hits": 0,
			"context": _create_damage_context(skill_id, "projectile"),
		})
		if projectile != null:
			spawned += 1
	return spawned


func _get_aim_direction() -> Vector2:
	var target := _king.auto_attack.get_current_target()
	if is_instance_valid(target) and target.is_combat_alive():
		return _king.global_position.direction_to(target.global_position)
	var nearest: GoblinController
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var candidate := node as GoblinController
		if not is_instance_valid(candidate) or not candidate.is_combat_alive():
			continue
		var distance := _king.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if is_instance_valid(nearest):
		return _king.global_position.direction_to(nearest.global_position)
	if not _king.velocity.is_zero_approx():
		return _king.velocity.normalized()
	return Vector2.RIGHT


func _create_damage_context(skill_id: StringName, attack_style: String, target: GoblinController = null) -> Dictionary:
	var context := {
		"source_kind": "king_active_skill",
		"source_team": "player",
		"source_id": str(skill_id),
		"source_node": _king,
		"attack_style": attack_style,
		"damage_type": "physical",
		"piercing": true,
		"target_kind": "enemy",
	}
	if is_instance_valid(target):
		context["target_id"] = str(target.enemy_id)
		context["target_instance_id"] = target.instance_id
	return context


func _on_damage_resolved(result: Dictionary, context: Dictionary) -> void:
	if not is_instance_valid(_king) or not _king.is_combat_alive():
		return
	var applied := float(result.get("applied", 0.0))
	if applied <= 0.0:
		return
	var source_kind := str(context.get("source_kind", ""))
	if context.get("source_node", null) == _king or source_kind in ["king", "king_skill", "king_active_skill"]:
		add_rage(applied * float(_system.get("damage_dealt_gain_per_point", 0.0)))
	if str(context.get("target_kind", "")) == "king":
		add_rage(applied * float(_system.get("damage_taken_gain_per_point", 0.0)))


func _on_enemy_killed(enemy_id: StringName, context: Dictionary) -> void:
	if not is_instance_valid(_king) or not _king.is_combat_alive() or str(context.get("source_team", "")) != "player":
		return
	var gain_key := "boss_kill_gain" if str(enemy_id).begins_with("boss_") else "enemy_kill_gain"
	add_rage(float(_system.get(gain_key, 0.0)))


func _draw() -> void:
	if _guard_remaining > 0.0:
		var guard_pulse := 0.5 + sin(_visual_phase * 1.7) * 0.5
		draw_circle(Vector2.ZERO, 58.0 + guard_pulse * 6.0, Color(0.16, 0.64, 1.0, 0.12))
		draw_arc(Vector2.ZERO, 60.0 + guard_pulse * 5.0, 0.0, TAU, 48, Color(0.35, 0.88, 1.0, 0.82), 5.0, true)
		for index in 6:
			var direction := Vector2.from_angle(TAU * float(index) / 6.0 + _visual_phase * 0.15)
			draw_line(direction * 48.0, direction * 70.0, Color(0.72, 0.96, 1.0, 0.72), 4.0, true)
	if _cast_pulse <= 0.0:
		return
	var alpha := _cast_pulse
	var progress := 1.0 - _cast_pulse
	match _cast_effect_type:
		"directional_cone":
			var radius := _cast_radius * (0.72 + progress * 0.28)
			var center_angle := _cast_direction.angle()
			draw_arc(Vector2.ZERO, radius, center_angle - _cast_half_angle, center_angle + _cast_half_angle, 36, Color(1.0, 0.7, 0.16, alpha), 12.0, true)
			draw_line(Vector2.ZERO, Vector2.from_angle(center_angle - _cast_half_angle) * radius, Color(1.0, 0.42, 0.08, alpha * 0.7), 4.0, true)
			draw_line(Vector2.ZERO, Vector2.from_angle(center_angle + _cast_half_angle) * radius, Color(1.0, 0.42, 0.08, alpha * 0.7), 4.0, true)
		"royal_guard":
			draw_arc(Vector2.ZERO, 48.0 + progress * 75.0, 0.0, TAU, 52, Color(0.28, 0.92, 1.0, alpha), 9.0, true)
		"piercing_fan":
			for index in 9:
				var offset_angle := deg_to_rad(-34.0 + 68.0 * float(index) / 8.0)
				var direction := _cast_direction.rotated(offset_angle)
				draw_line(direction * 38.0, direction * (150.0 + progress * 120.0), Color(1.0, 0.82, 0.26, alpha * 0.82), 5.0, true)
