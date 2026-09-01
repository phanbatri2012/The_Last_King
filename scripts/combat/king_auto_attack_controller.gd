class_name KingAutoAttackController
extends Node2D

signal target_changed(target: GoblinController)
signal attack_performed(target: GoblinController, applied_damage: float)

@onready var detection_area: Area2D = %DetectionArea
@onready var detection_shape: CollisionShape2D = %DetectionShape
@onready var strike_visual: KingAttackVisual = %StrikeVisual

var attack_damage := 40.0
var attack_range := 225.0
var attack_cooldown := 0.55
var target_refresh_interval := 0.12
var attack_style := "melee"
var damage_type := "physical"
var weapon_archetype_id: StringName = &"sword"
var slash_half_angle_degrees := 58.0

var _base_attack_damage := 40.0
var _base_attack_range := 225.0
var _base_attack_cooldown := 0.55
var _damage_multiplier := 1.0
var _range_multiplier := 1.0
var _cooldown_multiplier := 1.0
var _projectile_pool: AllyProjectilePool

var _host: KingController
var _current_target: GoblinController
var _cooldown_remaining := 0.0
var _refresh_remaining := 0.0
var _combat_enabled := true


func _ready() -> void:
	_host = get_parent() as KingController
	_apply_attack_range()


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_refresh_remaining = maxf(_refresh_remaining - delta, 0.0)
	if not _combat_enabled or not is_instance_valid(_host) or not _host.is_combat_alive():
		_set_target(null)
		return
	if not _is_target_valid(_current_target) or _refresh_remaining <= 0.0:
		refresh_target()
	if _current_target != null and _cooldown_remaining <= 0.0:
		_attack_current_target()


func configure(config: Dictionary, weapon_archetype: Dictionary = {}) -> void:
	_base_attack_damage = float(config.get("damage", _base_attack_damage))
	_base_attack_range = float(config.get("range", _base_attack_range))
	_base_attack_cooldown = float(config.get("cooldown", _base_attack_cooldown))
	target_refresh_interval = float(config.get("target_refresh", target_refresh_interval))
	weapon_archetype_id = StringName(str(weapon_archetype.get("id", weapon_archetype_id)))
	attack_style = str(weapon_archetype.get("attack_style", attack_style))
	damage_type = str(weapon_archetype.get("damage_type", damage_type))
	strike_visual.configure(attack_style)
	_recompute_modified_stats()


func set_projectile_pool(projectile_pool: AllyProjectilePool) -> void:
	_projectile_pool = projectile_pool


func set_skill_modifiers(
	damage_multiplier: float,
	cooldown_multiplier: float,
	range_multiplier: float,
	new_slash_half_angle_degrees: float
) -> void:
	_damage_multiplier = maxf(damage_multiplier, 0.01)
	_cooldown_multiplier = maxf(cooldown_multiplier, 0.05)
	_range_multiplier = maxf(range_multiplier, 0.1)
	slash_half_angle_degrees = clampf(new_slash_half_angle_degrees, 10.0, 180.0)
	_recompute_modified_stats()


func get_base_attack_damage() -> float:
	return _base_attack_damage


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not enabled:
		_set_target(null)


func get_current_target() -> GoblinController:
	return _current_target


func refresh_target() -> GoblinController:
	_refresh_remaining = target_refresh_interval
	var candidates: Array = detection_area.get_overlapping_bodies()
	return select_target_from_candidates(candidates)


func select_target_from_candidates(candidates: Array) -> GoblinController:
	var selected := CombatTargetSelector.nearest(global_position, candidates, attack_range) as GoblinController
	_set_target(selected)
	return _current_target


func _attack_current_target() -> void:
	if not _is_target_valid(_current_target):
		_set_target(null)
		return
	_cooldown_remaining = attack_cooldown
	var direction := (_current_target.global_position - global_position).normalized()
	_host.visual.play_attack(direction)
	strike_visual.play(direction, attack_range)
	if attack_style == "ranged" and is_instance_valid(_projectile_pool):
		_projectile_pool.request_projectile({
			"projectile_id": "%s_piercing_shot" % str(_host.king_id),
			"position": global_position + direction * (_host.collision_radius + 10.0),
			"direction": direction,
			"speed": 900.0,
			"radius": 6.0,
			"lifetime": attack_range / 900.0 + 0.3,
			"visual_kind": "bolt" if weapon_archetype_id == &"crossbow" else "arrow",
			"damage": attack_damage,
			"damage_type": damage_type,
			"piercing": true,
			"maximum_hits": 0,
			"context": _create_damage_context("ranged"),
		})
		return
	var targets := _collect_path_targets(direction, attack_style == "melee")
	for target in targets:
		_damage_target(target)
	_refresh_remaining = 0.0


func _collect_path_targets(direction: Vector2, melee: bool) -> Array[GoblinController]:
	var targets: Array[GoblinController] = []
	var minimum_dot := cos(deg_to_rad(slash_half_angle_degrees))
	for body in detection_area.get_overlapping_bodies():
		var enemy := body as GoblinController
		if not is_instance_valid(enemy) or not enemy.is_combat_alive():
			continue
		var offset := enemy.global_position - global_position
		var distance := offset.length()
		if distance > attack_range or distance <= 0.001:
			continue
		var forward_distance := direction.dot(offset)
		if forward_distance < 0.0:
			continue
		if melee:
			if direction.dot(offset / distance) < minimum_dot:
				continue
		else:
			var perpendicular_distance := absf(Vector2(-direction.y, direction.x).dot(offset))
			if perpendicular_distance > 34.0 + enemy.collision_radius:
				continue
		targets.append(enemy)
	if is_instance_valid(_current_target) and not targets.has(_current_target):
		targets.append(_current_target)
	targets.sort_custom(func(left: GoblinController, right: GoblinController) -> bool:
		return global_position.distance_squared_to(left.global_position) < global_position.distance_squared_to(right.global_position)
	)
	return targets


func _damage_target(target: GoblinController) -> void:
	if not is_instance_valid(target) or not target.is_combat_alive():
		return
	var result := DamageResolver.apply_damage(
		target.health,
		attack_damage,
		_create_damage_context(attack_style, target),
		target.defense
	)
	attack_performed.emit(target, float(result.get("applied", 0.0)))


func _create_damage_context(style: String, target: GoblinController = null) -> Dictionary:
	var context := {
		"source_kind": "king",
		"source_team": "player",
		"source_id": str(_host.king_id),
		"source_node": _host,
		"weapon_archetype_id": str(weapon_archetype_id),
		"attack_style": style,
		"target_kind": "enemy",
		"damage_type": damage_type,
		"piercing": true,
	}
	if is_instance_valid(target):
		context["target_id"] = str(target.enemy_id)
		context["target_instance_id"] = target.instance_id
	return context


func _is_target_valid(target: GoblinController) -> bool:
	return (
		is_instance_valid(target)
		and target.is_combat_alive()
		and global_position.distance_squared_to(target.global_position) <= attack_range * attack_range
	)


func _set_target(new_target: GoblinController) -> void:
	if _current_target == new_target:
		return
	if is_instance_valid(_current_target):
		_current_target.set_targeted(false)
	_current_target = new_target
	if is_instance_valid(_current_target):
		_current_target.set_targeted(true)
	target_changed.emit(_current_target)


func _apply_attack_range() -> void:
	if detection_shape == null:
		return
	var circle := detection_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = maxf(attack_range, 1.0)


func _recompute_modified_stats() -> void:
	attack_damage = _base_attack_damage * _damage_multiplier
	attack_range = _base_attack_range * _range_multiplier
	attack_cooldown = maxf(_base_attack_cooldown * _cooldown_multiplier, 0.03)
	_apply_attack_range()
