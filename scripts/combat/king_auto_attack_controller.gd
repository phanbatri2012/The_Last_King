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
	attack_damage = float(config.get("damage", attack_damage))
	attack_range = float(config.get("range", attack_range))
	attack_cooldown = float(config.get("cooldown", attack_cooldown))
	target_refresh_interval = float(config.get("target_refresh", target_refresh_interval))
	weapon_archetype_id = StringName(str(weapon_archetype.get("id", weapon_archetype_id)))
	attack_style = str(weapon_archetype.get("attack_style", attack_style))
	damage_type = str(weapon_archetype.get("damage_type", damage_type))
	strike_visual.configure(attack_style)
	_apply_attack_range()


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
	strike_visual.play(direction, global_position.distance_to(_current_target.global_position))
	var result := DamageResolver.apply_damage(
		_current_target.health,
		attack_damage,
		{
			"source_kind": "king",
			"source_id": str(_host.king_id),
			"weapon_archetype_id": str(weapon_archetype_id),
			"attack_style": attack_style,
			"target_kind": "enemy",
			"target_id": str(_current_target.enemy_id),
			"target_instance_id": _current_target.instance_id,
			"damage_type": damage_type,
		},
		_current_target.defense
	)
	attack_performed.emit(_current_target, float(result.get("applied", 0.0)))
	if bool(result.get("killed", false)):
		_refresh_remaining = 0.0


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
