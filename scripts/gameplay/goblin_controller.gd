class_name GoblinController
extends CharacterBody2D

signal defeated(enemy: GoblinController, context: Dictionary)
signal engagement_changed(enemy: GoblinController, engaged: bool)

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

var _target: KingController
var _cooldown_remaining := 0.0
var _combat_enabled := true
var _engaged := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("combat_enemies")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_apply_collision_radius()
	visual.set_health(health.current_health, health.max_health)
	visual.set_engaged(_engaged)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not _combat_enabled or not is_combat_alive() or not is_instance_valid(_target) or not _target.is_combat_alive():
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

	if distance > attack_range:
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
	restored_engaged: bool = false
) -> void:
	enemy_id = StringName(str(config.get("id", enemy_id)))
	instance_id = new_instance_id
	name_key = str(config.get("name_key", name_key))
	combat_role = str(config.get("combat_role", combat_role))
	var health_data: Dictionary = config.get("health", {})
	var defense_data: Dictionary = config.get("defense", {})
	var movement_data: Dictionary = config.get("movement", {})
	var attack_data: Dictionary = config.get("attack", {})
	var presentation_data: Dictionary = config.get("presentation", {})
	health.configure(float(health_data.get("max", health.max_health)), restored_health)
	defense.configure(defense_data)
	move_speed = float(movement_data.get("speed", move_speed))
	collision_radius = float(movement_data.get("collision_radius", collision_radius))
	aggro_range = float(movement_data.get("aggro_range", aggro_range))
	attack_damage = float(attack_data.get("damage", attack_damage))
	attack_range = float(attack_data.get("range", attack_range))
	attacks_per_second = maxf(float(attack_data.get("attacks_per_second", attacks_per_second)), 0.01)
	attack_style = str(attack_data.get("attack_style", attack_style))
	damage_type = str(attack_data.get("damage_type", damage_type))
	visual.configure(presentation_data)
	attack_visual.configure(attack_style, damage_type)
	_apply_collision_radius()
	_set_engaged(restored_engaged)


func set_target(new_target: KingController) -> void:
	_target = new_target


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not enabled:
		_stop_moving()


func is_combat_alive() -> bool:
	return health != null and health.is_alive()


func is_engaged() -> bool:
	return _engaged


func set_targeted(targeted: bool) -> void:
	visual.set_targeted(targeted)


func retire_without_reward() -> void:
	_combat_enabled = false
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
	}


func get_attack_cooldown() -> float:
	return 1.0 / attacks_per_second


func _try_attack(direction: Vector2, target_distance: float) -> void:
	if _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = get_attack_cooldown()
	visual.play_attack(direction)
	attack_visual.play(direction, target_distance)
	DamageResolver.apply_damage(
		_target.health,
		attack_damage,
		{
			"source_kind": "enemy",
			"source_id": str(enemy_id),
			"source_instance_id": instance_id,
			"target_kind": "king",
			"damage_type": damage_type,
			"attack_style": attack_style,
		},
		_target.defense
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
		if str(context.get("source_kind", "")) == "king":
			_set_engaged(true)


func _on_died(context: Dictionary) -> void:
	_combat_enabled = false
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
