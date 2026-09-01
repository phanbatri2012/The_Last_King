class_name GoblinController
extends CharacterBody2D

signal defeated(enemy: GoblinController, context: Dictionary)
signal engagement_changed(enemy: GoblinController, engaged: bool)
signal projectile_requested(request: Dictionary)

@onready var visual: GoblinPlaceholderVisual = %Visual
@onready var attack_visual: EnemyAttackVisual = %AttackVisual
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var health: HealthComponent = %Health
@onready var defense: DefenseComponent = %Defense

var enemy_id: StringName = &"goblin"
var instance_id := ""
var name_key := "enemy.goblin.name"
var combat_role := "melee_physical"
var move_speed := 115.0
var collision_radius := 24.0
var aggro_range := 520.0
var attack_damage := 22.0
var attack_range := 72.0
var attacks_per_second := 0.87
var attack_style := "melee"
var damage_type := "physical"
var attack_windup := 0.0
var projectile_speed := 0.0
var projectile_radius := 0.0
var projectile_lifetime := 0.0
var projectile_visual_kind := "arrow"
var contact_damage_multiplier := 0.35
var contact_damage_cooldown := 0.75
var contact_minimum_damage := 1.0
var contact_collision_margin := 2.0
var ability_config: Dictionary = {}
var runtime_modifiers: Dictionary = {}

var _primary_target: Node2D
var _target: Node2D
var _cooldown_remaining := 0.0
var _contact_cooldown_remaining := 0.0
var _combat_enabled := true
var _engaged := false
var _windup_remaining := 0.0
var _locked_attack_direction := Vector2.LEFT
var _base_move_speed := 115.0
var _base_attacks_per_second := 0.87
var _temporary_move_multiplier := 1.0
var _temporary_attack_multiplier := 1.0
var _temporary_haste_remaining := 0.0
var _ability_tick_remaining := 0.0
var _target_refresh_remaining := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("combat_enemies")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_apply_collision_radius()
	visual.set_health(health.current_health, health.max_health)
	visual.set_engaged(_engaged)


func _physics_process(delta: float) -> void:
	_update_temporary_haste(delta)
	_update_special_ability(delta)
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_contact_cooldown_remaining = maxf(_contact_cooldown_remaining - delta, 0.0)
	if _combat_enabled and is_combat_alive():
		_try_contact_damage()
	if _windup_remaining > 0.0:
		_windup_remaining = maxf(_windup_remaining - delta, 0.0)
		_stop_moving()
		if _windup_remaining <= 0.0:
			_release_projectile()
		return
	_refresh_target_fallback()
	if not _combat_enabled or not is_combat_alive() or not _is_target_alive(_target):
		_stop_moving()
		return

	var offset := _target.global_position - global_position
	var distance := offset.length()
	if not _engaged:
		if distance <= aggro_range:
			_set_engaged(true)
		else:
			_stop_moving()
			return

	if attack_style == "ranged" and distance < attack_range * 0.5:
		velocity = -offset.normalized() * move_speed
		move_and_slide()
	elif distance > attack_range:
		velocity = offset.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_try_attack(offset.normalized(), distance)
	visual.set_motion(velocity)


func configure(
	config: Dictionary,
	new_instance_id: String,
	restored_health: float = -1.0,
	restored_engaged: bool = false,
	new_runtime_modifiers: Dictionary = {}
) -> void:
	enemy_id = StringName(str(config.get("id", enemy_id)))
	instance_id = new_instance_id
	name_key = str(config.get("name_key", name_key))
	combat_role = str(config.get("combat_role", combat_role))
	var health_data: Dictionary = config.get("health", {})
	var defense_data: Dictionary = config.get("defense", {})
	var movement_data: Dictionary = config.get("movement", {})
	var attack_data: Dictionary = config.get("attack", {})
	var contact_data: Dictionary = config.get("contact_damage", {})
	var presentation_data: Dictionary = config.get("presentation", {}).duplicate(true)
	ability_config = config.get("ability", {}).duplicate(true)
	runtime_modifiers = new_runtime_modifiers.duplicate(true)
	var hp_multiplier := maxf(float(runtime_modifiers.get("hp_multiplier", 1.0)), 0.01)
	var damage_multiplier := maxf(float(runtime_modifiers.get("damage_multiplier", 1.0)), 0.01)
	var speed_multiplier := maxf(float(runtime_modifiers.get("speed_multiplier", 1.0)), 0.1)
	var defense_multiplier := maxf(float(runtime_modifiers.get("defense_multiplier", 1.0)), 0.0)
	health.configure(float(health_data.get("max", health.max_health)) * hp_multiplier, restored_health)
	defense.configure({
		"armor": float(defense_data.get("armor", 0.0)) * defense_multiplier,
		"magic_resistance": float(defense_data.get("magic_resistance", 0.0)) * defense_multiplier,
	})
	_base_move_speed = float(movement_data.get("speed", move_speed)) * speed_multiplier
	move_speed = _base_move_speed
	collision_radius = float(movement_data.get("collision_radius", collision_radius))
	aggro_range = float(movement_data.get("aggro_range", aggro_range))
	attack_damage = float(attack_data.get("damage", attack_damage)) * damage_multiplier
	attack_range = float(attack_data.get("range", attack_range))
	_base_attacks_per_second = maxf(float(attack_data.get("attacks_per_second", attacks_per_second)), 0.01)
	attacks_per_second = _base_attacks_per_second
	attack_style = str(attack_data.get("attack_style", attack_style))
	damage_type = str(attack_data.get("damage_type", damage_type))
	attack_windup = maxf(float(attack_data.get("windup", 0.0)), 0.0)
	var projectile_data: Dictionary = attack_data.get("projectile", {})
	projectile_speed = maxf(float(projectile_data.get("speed", 0.0)), 0.0)
	projectile_radius = maxf(float(projectile_data.get("radius", 0.0)), 0.0)
	projectile_lifetime = maxf(float(projectile_data.get("lifetime", 0.0)), 0.0)
	projectile_visual_kind = str(projectile_data.get("visual_kind", "arrow"))
	contact_damage_multiplier = maxf(float(contact_data.get("damage_multiplier", contact_damage_multiplier)), 0.01)
	contact_damage_cooldown = maxf(float(contact_data.get("cooldown", contact_damage_cooldown)), 0.05)
	contact_minimum_damage = maxf(float(contact_data.get("minimum_damage", contact_minimum_damage)), 0.01)
	contact_collision_margin = maxf(float(contact_data.get("collision_margin", contact_collision_margin)), 0.0)
	presentation_data["elite_rank"] = maxi(int(runtime_modifiers.get("elite_rank", 0)), 0)
	visual.configure(presentation_data)
	attack_visual.configure(attack_style, damage_type)
	_apply_collision_radius()
	_set_engaged(restored_engaged)


func set_target(new_target: Node2D) -> void:
	_primary_target = new_target
	_target = new_target


func set_retaliation_target(new_target: Node2D) -> void:
	if _is_target_alive(new_target):
		_target = new_target


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not enabled:
		_cancel_pending_attack()
		_stop_moving()


func is_combat_alive() -> bool:
	return health != null and health.is_alive()


func is_engaged() -> bool:
	return _engaged


func set_targeted(targeted: bool) -> void:
	visual.set_targeted(targeted)


func retire_without_reward() -> void:
	_combat_enabled = false
	_cancel_pending_attack()
	_stop_moving()
	remove_from_group("combat_enemies")
	collision_shape.set_deferred("disabled", true)


func get_combat_snapshot() -> Dictionary:
	return {
		"instance_id": instance_id,
		"enemy_id": str(enemy_id),
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health.current_health,
		"engaged": _engaged,
		"runtime_modifiers": runtime_modifiers.duplicate(true),
	}


func get_attack_cooldown() -> float:
	var effective_attack_speed := attacks_per_second
	if str(ability_config.get("kind", "")) == "low_health_frenzy" and health.get_ratio() <= float(ability_config.get("threshold", 0.5)):
		effective_attack_speed *= float(ability_config.get("attack_speed_multiplier", 1.65))
	return 1.0 / maxf(effective_attack_speed, 0.01)


func apply_temporary_haste(move_multiplier: float, attack_multiplier: float, duration: float) -> void:
	_temporary_move_multiplier = maxf(_temporary_move_multiplier, move_multiplier)
	_temporary_attack_multiplier = maxf(_temporary_attack_multiplier, attack_multiplier)
	_temporary_haste_remaining = maxf(_temporary_haste_remaining, duration)
	move_speed = _base_move_speed * _temporary_move_multiplier
	attacks_per_second = _base_attacks_per_second * _temporary_attack_multiplier


func _try_attack(direction: Vector2, target_distance: float) -> void:
	if _cooldown_remaining > 0.0:
		return
	if str(ability_config.get("kind", "")) == "suicide_blast":
		_perform_suicide_blast()
		return
	if attack_style == "ranged":
		_begin_ranged_attack(direction)
		return
	var target_health := _target.get("health") as HealthComponent
	var target_defense := _target.get("defense") as DefenseComponent
	if target_health == null:
		return
	_cooldown_remaining = get_attack_cooldown()
	visual.play_attack(direction)
	attack_visual.play_melee(direction, target_distance)
	DamageResolver.apply_damage(
		target_health,
		attack_damage,
		{
			"source_kind": "enemy",
			"source_id": str(enemy_id),
			"source_instance_id": instance_id,
			"target_kind": "unit" if _target is SummonedUnitController else "king",
			"damage_type": damage_type,
			"attack_style": attack_style,
		},
		target_defense
	)


func _try_contact_damage() -> void:
	if _contact_cooldown_remaining > 0.0 or not _primary_target is KingController:
		return
	var king := _primary_target as KingController
	if not _is_target_alive(king):
		return
	var contact_distance := collision_radius + king.collision_radius + contact_collision_margin
	if global_position.distance_squared_to(king.global_position) > contact_distance * contact_distance:
		return
	_contact_cooldown_remaining = contact_damage_cooldown
	_set_engaged(true)
	var direction := global_position.direction_to(king.global_position)
	visual.play_attack(direction if not direction.is_zero_approx() else Vector2.LEFT)
	DamageResolver.apply_damage(
		king.health,
		maxf(attack_damage * contact_damage_multiplier, contact_minimum_damage),
		{
			"source_kind": "enemy_contact",
			"source_id": str(enemy_id),
			"source_instance_id": instance_id,
			"target_kind": "king",
			"damage_type": damage_type,
			"attack_style": "contact",
		},
		king.defense
	)


func _begin_ranged_attack(direction: Vector2) -> void:
	_locked_attack_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.LEFT
	_cooldown_remaining = get_attack_cooldown()
	_windup_remaining = maxf(attack_windup, 0.05)
	visual.play_attack(_locked_attack_direction)
	attack_visual.play_telegraph(_locked_attack_direction, attack_range, _windup_remaining)


func _release_projectile() -> void:
	if not _combat_enabled or not is_combat_alive():
		return
	projectile_requested.emit({
		"projectile_id": "%s_projectile" % instance_id,
		"position": global_position + _locked_attack_direction * (collision_radius + projectile_radius + 4.0),
		"direction": _locked_attack_direction,
		"speed": projectile_speed,
		"radius": projectile_radius,
		"lifetime": projectile_lifetime,
		"visual_kind": projectile_visual_kind,
		"damage": attack_damage,
		"damage_type": damage_type,
		"context": {
			"source_kind": "enemy",
			"source_id": str(enemy_id),
			"source_instance_id": instance_id,
			"damage_type": damage_type,
			"attack_style": "ranged",
		},
	})


func _cancel_pending_attack() -> void:
	_windup_remaining = 0.0
	attack_visual.cancel()


func _refresh_target_fallback() -> void:
	if _is_target_alive(_target):
		return
	_target = _primary_target if _is_target_alive(_primary_target) else null


func _update_temporary_haste(delta: float) -> void:
	if _temporary_haste_remaining <= 0.0:
		return
	_temporary_haste_remaining = maxf(_temporary_haste_remaining - delta, 0.0)
	if _temporary_haste_remaining > 0.0:
		return
	_temporary_move_multiplier = 1.0
	_temporary_attack_multiplier = 1.0
	move_speed = _base_move_speed
	attacks_per_second = _base_attacks_per_second


func _update_special_ability(delta: float) -> void:
	_ability_tick_remaining = maxf(_ability_tick_remaining - delta, 0.0)
	_target_refresh_remaining = maxf(_target_refresh_remaining - delta, 0.0)
	var ability_kind := str(ability_config.get("kind", ""))
	if ability_kind == "haste_aura" and _ability_tick_remaining <= 0.0 and is_combat_alive():
		_ability_tick_remaining = 0.8
		var radius := float(ability_config.get("radius", 250.0))
		for enemy_node in get_tree().get_nodes_in_group("combat_enemies"):
			var ally := enemy_node as GoblinController
			if not is_instance_valid(ally) or ally == self or not ally.is_combat_alive():
				continue
			if global_position.distance_squared_to(ally.global_position) <= radius * radius:
				ally.apply_temporary_haste(
					float(ability_config.get("move_speed_multiplier", 1.2)),
					float(ability_config.get("attack_speed_multiplier", 1.3)),
					1.0
				)
	if str(ability_config.get("target_priority", "")) == "support" and _target_refresh_remaining <= 0.0 and _engaged:
		_target_refresh_remaining = 0.75
		var nearest: Node2D
		var nearest_distance := INF
		for ally_node in get_tree().get_nodes_in_group("combat_allies"):
			var candidate := ally_node as Node2D
			if not _is_target_alive(candidate) or candidate is KingController:
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
		if is_instance_valid(nearest):
			_target = nearest


func _perform_suicide_blast() -> void:
	_cooldown_remaining = get_attack_cooldown()
	visual.play_attack(Vector2.RIGHT)
	var radius := maxf(float(ability_config.get("radius", 112.0)), 1.0)
	for ally_node in get_tree().get_nodes_in_group("combat_allies"):
		var ally := ally_node as Node2D
		if not _is_target_alive(ally) or global_position.distance_squared_to(ally.global_position) > radius * radius:
			continue
		DamageResolver.apply_damage(
			ally.get("health") as HealthComponent,
			attack_damage,
			{
				"source_kind": "enemy",
				"source_id": str(enemy_id),
				"source_instance_id": instance_id,
				"target_kind": "unit" if ally is SummonedUnitController else "king",
				"damage_type": damage_type,
				"attack_style": "area",
			},
			ally.get("defense") as DefenseComponent
		)
	DamageResolver.apply_damage(
		health,
		health.current_health,
		{"source_kind": "enemy_ability", "source_id": str(enemy_id), "damage_type": "physical", "no_reward": false},
		null
	)


func _is_target_alive(candidate: Node2D) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate.has_method("is_combat_alive")
		and bool(candidate.call("is_combat_alive"))
	)


func _set_engaged(engaged: bool) -> void:
	if _engaged == engaged:
		return
	_engaged = engaged
	visual.set_engaged(_engaged)
	engagement_changed.emit(self, _engaged)


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	visual.set_motion(velocity)


func _apply_collision_radius() -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _on_health_changed(current: float, maximum: float, delta: float, context: Dictionary) -> void:
	visual.set_health(current, maximum)
	if delta < 0.0:
		visual.play_hurt()
		if str(context.get("source_team", "")) == "player" or str(context.get("source_kind", "")) == "king":
			_set_engaged(true)
			var source_node: Variant = context.get("source_node", null)
			if source_node is SummonedUnitController:
				set_retaliation_target(source_node)


func _on_died(context: Dictionary) -> void:
	_combat_enabled = false
	_cancel_pending_attack()
	_stop_moving()
	remove_from_group("combat_enemies")
	collision_shape.set_deferred("disabled", true)
	visual.set_defeated()
	defeated.emit(self, context.duplicate(true))
	var event_context := context.duplicate(true)
	event_context["instance_id"] = instance_id
	var event_bus := get_node_or_null("/root/GameEventBus")
	if event_bus != null:
		event_bus.enemy_killed.emit(enemy_id, event_context)
