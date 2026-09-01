class_name KingSkillRuntime
extends Node2D

signal skill_cast(skill_id: StringName, affected_targets: int)

var _king: KingController
var _projectile_pool: AllyProjectilePool
var _skill_configs: Dictionary = {}
var _skill_levels: Dictionary = {}
var _cooldowns: Dictionary = {}
var _wave_pulse := 0.0
var _aura_pulse := 0.0
var _aura_radius := 0.0
var _upgrade_pulse := 0.0
var _upgrade_effect_type := ""
var _visual_phase := 0.0


func _ready() -> void:
	z_index = 2


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_king):
		return
	global_position = _king.global_position
	_visual_phase = fmod(_visual_phase + delta * 4.0, TAU)
	_wave_pulse = maxf(_wave_pulse - delta * 1.8, 0.0)
	_aura_pulse = maxf(_aura_pulse - delta * 1.5, 0.0)
	_upgrade_pulse = maxf(_upgrade_pulse - delta * 0.72, 0.0)
	queue_redraw()
	if not _king.is_combat_alive():
		return
	for skill_id_value in _skill_levels.keys():
		var skill_id := str(skill_id_value)
		var skill_level := int(_skill_levels.get(skill_id, 0))
		if skill_level <= 0:
			continue
		var config: Dictionary = _skill_configs.get(skill_id, {})
		var effect_type := str(config.get("effect_type", ""))
		if effect_type not in ["piercing_wave", "dragon_aura"]:
			continue
		var remaining := maxf(float(_cooldowns.get(skill_id, 0.4)) - delta, 0.0)
		_cooldowns[skill_id] = remaining
		if remaining > 0.0:
			continue
		var level_data := _get_level_data(config, skill_level)
		if effect_type == "piercing_wave":
			_cast_piercing_wave(StringName(skill_id), level_data)
		else:
			_cast_dragon_aura(StringName(skill_id), level_data)
		_cooldowns[skill_id] = maxf(float(level_data.get("cooldown", 5.0)), 0.1)


func configure(
	host_king: KingController,
	projectile_pool: AllyProjectilePool,
	skill_configs: Dictionary,
	restored_levels: Dictionary = {}
) -> void:
	_king = host_king
	_projectile_pool = projectile_pool
	_skill_configs = skill_configs.duplicate(true)
	_skill_levels.clear()
	_cooldowns.clear()
	for skill_id_value in restored_levels.keys():
		var skill_id := str(skill_id_value)
		if _skill_configs.has(skill_id):
			_skill_levels[skill_id] = clampi(int(restored_levels[skill_id]), 0, get_max_level(StringName(skill_id)))
			_cooldowns[skill_id] = 0.65
	_recompute_passives()


func set_skill_level(skill_id: StringName, level: int) -> bool:
	var key := str(skill_id)
	if not _skill_configs.has(key):
		return false
	var safe_level := clampi(level, 0, get_max_level(skill_id))
	_skill_levels[key] = safe_level
	_cooldowns[key] = minf(float(_cooldowns.get(key, 0.35)), 0.35)
	var config: Dictionary = _skill_configs.get(key, {})
	_upgrade_effect_type = str(config.get("effect_type", ""))
	_upgrade_pulse = 1.0
	_recompute_passives()
	return true


func get_skill_level(skill_id: StringName) -> int:
	return int(_skill_levels.get(str(skill_id), 0))


func get_max_level(skill_id: StringName) -> int:
	var config: Dictionary = _skill_configs.get(str(skill_id), {})
	var levels_value: Variant = config.get("levels", [])
	return levels_value.size() if levels_value is Array else 0


func get_skill_levels() -> Dictionary:
	return _skill_levels.duplicate(true)


func _recompute_passives() -> void:
	if not is_instance_valid(_king):
		return
	var damage_multiplier := 1.0
	var cooldown_multiplier := 1.0
	var range_multiplier := 1.0
	var slash_half_angle := 58.0
	var move_speed_multiplier := 1.0
	var max_health_bonus := 0.0
	var armor_bonus := 0.0
	var magic_resistance_bonus := 0.0
	for skill_id_value in _skill_levels.keys():
		var skill_id := str(skill_id_value)
		var skill_level := int(_skill_levels.get(skill_id, 0))
		if skill_level <= 0:
			continue
		var config: Dictionary = _skill_configs.get(skill_id, {})
		var level_data := _get_level_data(config, skill_level)
		match str(config.get("effect_type", "")):
			"royal_might":
				damage_multiplier = float(level_data.get("damage_multiplier", damage_multiplier))
			"swift_command":
				cooldown_multiplier = float(level_data.get("attack_cooldown_multiplier", cooldown_multiplier))
				move_speed_multiplier = float(level_data.get("move_speed_multiplier", move_speed_multiplier))
			"sovereign_reach":
				range_multiplier = float(level_data.get("range_multiplier", range_multiplier))
				slash_half_angle = float(level_data.get("slash_half_angle_degrees", slash_half_angle))
			"iron_will":
				max_health_bonus = float(level_data.get("max_health_bonus", max_health_bonus))
				armor_bonus = float(level_data.get("armor_bonus", armor_bonus))
				magic_resistance_bonus = float(level_data.get("magic_resistance_bonus", magic_resistance_bonus))
	_king.auto_attack.set_skill_modifiers(damage_multiplier, cooldown_multiplier, range_multiplier, slash_half_angle)
	_king.apply_skill_modifiers(move_speed_multiplier, max_health_bonus, armor_bonus, magic_resistance_bonus)


func _cast_piercing_wave(skill_id: StringName, level_data: Dictionary) -> void:
	if not is_instance_valid(_projectile_pool):
		return
	var projectile_count := maxi(int(level_data.get("projectile_count", 4)), 1)
	var starting_angle := 0.0
	var target := _king.auto_attack.get_current_target()
	if is_instance_valid(target):
		starting_angle = (_king.global_position.direction_to(target.global_position)).angle()
	var damage := _king.auto_attack.attack_damage * float(level_data.get("damage_multiplier", 0.7))
	for index in projectile_count:
		var direction := Vector2.from_angle(starting_angle + TAU * float(index) / float(projectile_count))
		_projectile_pool.request_projectile({
			"projectile_id": "%s_%d" % [str(skill_id), index],
			"position": _king.global_position + direction * (_king.collision_radius + 12.0),
			"direction": direction,
			"speed": float(level_data.get("projectile_speed", 620.0)),
			"radius": 10.0,
			"lifetime": float(level_data.get("projectile_lifetime", 1.25)),
			"visual_kind": "royal_wave",
			"damage": damage,
			"damage_type": "physical",
			"piercing": true,
			"maximum_hits": 0,
			"context": _create_skill_context(skill_id, "projectile"),
		})
	_wave_pulse = 1.0
	skill_cast.emit(skill_id, projectile_count)


func _cast_dragon_aura(skill_id: StringName, level_data: Dictionary) -> void:
	var radius := maxf(float(level_data.get("radius", 190.0)), 1.0)
	var damage := _king.auto_attack.attack_damage * float(level_data.get("damage_multiplier", 0.5))
	var affected := 0
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as GoblinController
		if not is_instance_valid(enemy) or not enemy.is_combat_alive():
			continue
		if _king.global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		DamageResolver.apply_damage(
			enemy.health,
			damage,
			_create_skill_context(skill_id, "area", enemy),
			enemy.defense
		)
		affected += 1
	_aura_radius = radius
	_aura_pulse = 1.0
	skill_cast.emit(skill_id, affected)


func _create_skill_context(skill_id: StringName, attack_style: String, target: GoblinController = null) -> Dictionary:
	var context := {
		"source_kind": "king_skill",
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


func _get_level_data(config: Dictionary, level: int) -> Dictionary:
	var levels_value: Variant = config.get("levels", [])
	if not levels_value is Array or levels_value.is_empty():
		return {}
	var levels: Array = levels_value
	var index := clampi(level - 1, 0, levels.size() - 1)
	return levels[index] if levels[index] is Dictionary else {}


func _draw() -> void:
	if _wave_pulse > 0.0:
		var wave_progress := 1.0 - _wave_pulse
		var wave_radius := 48.0 + wave_progress * 58.0
		draw_circle(Vector2.ZERO, wave_radius, Color(1.0, 0.54, 0.08, _wave_pulse * 0.08))
		draw_arc(Vector2.ZERO, wave_radius, 0.0, TAU, 64, Color(1.0, 0.76, 0.2, _wave_pulse), 6.0, true)
		draw_arc(Vector2.ZERO, wave_radius * 0.72, -_visual_phase, TAU - _visual_phase, 48, Color(1.0, 0.95, 0.58, _wave_pulse * 0.8), 3.0, true)
		for ray_index in 8:
			var direction := Vector2.from_angle(TAU * float(ray_index) / 8.0 + _visual_phase * 0.2)
			draw_line(direction * 35.0, direction * wave_radius, Color(1.0, 0.7, 0.15, _wave_pulse * 0.65), 3.0, true)
	if _aura_pulse > 0.0:
		var aura_progress := 1.0 - _aura_pulse
		var aura_radius := _aura_radius * minf(aura_progress * 1.8, 1.0)
		draw_circle(Vector2.ZERO, aura_radius, Color(0.08, 0.62, 0.96, _aura_pulse * 0.16))
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 72, Color(0.4, 0.92, 1.0, _aura_pulse * 0.9), 7.0, true)
		draw_arc(Vector2.ZERO, aura_radius * 0.72, _visual_phase, _visual_phase + 4.8, 48, Color(0.25, 1.0, 0.68, _aura_pulse), 5.0, true)
		draw_arc(Vector2.ZERO, aura_radius * 0.52, -_visual_phase, -_visual_phase + 4.5, 48, Color(0.82, 1.0, 0.95, _aura_pulse * 0.9), 4.0, true)
		var dragon_head := Vector2.from_angle(_visual_phase) * aura_radius * 0.72
		draw_colored_polygon(PackedVector2Array([dragon_head + Vector2(13.0, 0.0), dragon_head + Vector2(-9.0, -10.0), dragon_head + Vector2(-5.0, 10.0)]), Color(0.35, 1.0, 0.72, _aura_pulse))
	if _upgrade_pulse > 0.0:
		_draw_upgrade_effect(1.0 - _upgrade_pulse, _upgrade_pulse)


func _draw_upgrade_effect(progress: float, alpha: float) -> void:
	var radius := 50.0 + progress * 115.0
	match _upgrade_effect_type:
		"royal_might":
			for index in 12:
				var direction := Vector2.from_angle(TAU * float(index) / 12.0 + _visual_phase * 0.12)
				draw_line(direction * 42.0, direction * radius, Color(1.0, 0.68, 0.1, alpha), 7.0, true)
			draw_arc(Vector2.ZERO, radius * 0.68, 0.0, TAU, 56, Color(1.0, 0.9, 0.35, alpha), 5.0, true)
		"swift_command":
			for index in 7:
				var angle := TAU * float(index) / 7.0
				var direction := Vector2.from_angle(angle)
				var side := Vector2(-direction.y, direction.x)
				var tip := direction * radius
				draw_polyline(PackedVector2Array([tip - direction * 34.0 + side * 13.0, tip, tip - direction * 34.0 - side * 13.0]), Color(0.28, 0.9, 1.0, alpha), 5.0, true)
		"sovereign_reach":
			draw_arc(Vector2.ZERO, radius, -2.8, -0.25, 48, Color(0.83, 0.46, 1.0, alpha), 10.0, true)
			draw_arc(Vector2.ZERO, radius * 0.72, 0.35, 2.75, 48, Color(0.52, 0.76, 1.0, alpha), 7.0, true)
		"iron_will":
			var points := PackedVector2Array()
			for index in 7:
				points.append(Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 6.0) * radius * 0.72)
			draw_colored_polygon(points, Color(0.12, 0.55, 1.0, alpha * 0.18))
			draw_polyline(points, Color(0.48, 0.88, 1.0, alpha), 8.0, true)
		"piercing_wave":
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.55, 0.08, alpha), 9.0, true)
			for index in 8:
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				draw_line(direction * 35.0, direction * radius, Color(1.0, 0.82, 0.28, alpha), 5.0, true)
		"dragon_aura":
			draw_circle(Vector2.ZERO, radius, Color(0.08, 0.7, 0.9, alpha * 0.14))
			draw_arc(Vector2.ZERO, radius, _visual_phase, _visual_phase + 5.2, 64, Color(0.2, 1.0, 0.64, alpha), 9.0, true)
			draw_arc(Vector2.ZERO, radius * 0.62, -_visual_phase, -_visual_phase + 5.0, 56, Color(0.58, 0.94, 1.0, alpha), 6.0, true)
