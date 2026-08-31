class_name SummonedUnitController
extends CharacterBody2D

signal defeated(unit: SummonedUnitController, context: Dictionary)

@onready var visual: SummonedUnitPlaceholderVisual = %Visual
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var detection_shape: CollisionShape2D = %DetectionShape
@onready var health: HealthComponent = %Health
@onready var defense: DefenseComponent = %Defense

var unit_id: StringName = &"dai_viet_spearman"
var instance_id := ""
var name_key := "unit.dai_viet_spearman.name"
var capacity_cost := 2
var move_speed := 285.0
var collision_radius := 17.0
var attack_damage := 24.0
var attack_range := 70.0
var detection_range := 270.0
var leash_range := 330.0
var attacks_per_second := 1.05
var target_refresh_interval := 0.16
var damage_type := "physical"

var _king: KingController
var _formation_offset := Vector2.ZERO
var _current_target: GoblinController
var _cooldown_remaining := 0.0
var _refresh_remaining := 0.0
var _combat_enabled := true


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("combat_allies")
	add_to_group("combat_units")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_apply_collision_radius()
	_apply_detection_range()
	visual.set_health(health.current_health, health.max_health)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_refresh_remaining = maxf(_refresh_remaining - delta, 0.0)
	if not _combat_enabled or not is_combat_alive() or not is_instance_valid(_king) or not _king.is_combat_alive():
		_stop_moving()
		return

	var formation_position := get_formation_world_position()
	if global_position.distance_to(formation_position) > leash_range:
		_set_target(null)
	if not _is_target_valid(_current_target, formation_position) or _refresh_remaining <= 0.0:
		_refresh_target(formation_position)

	if is_instance_valid(_current_target):
		var target_offset := _current_target.global_position - global_position
		if target_offset.length() > attack_range:
			_move_toward(target_offset)
		else:
			_stop_moving()
			_try_attack(target_offset.normalized())
	else:
		var formation_offset := formation_position - global_position
		if formation_offset.length() > 10.0:
			_move_toward(formation_offset)
		else:
			_stop_moving()


func configure(
	config: Dictionary,
	new_instance_id: String,
	host_king: KingController,
	restored_health: float = -1.0
) -> void:
	unit_id = StringName(str(config.get("id", unit_id)))
	instance_id = new_instance_id
	name_key = str(config.get("name_key", name_key))
	_king = host_king
	var health_data: Dictionary = config.get("health", {})
	var defense_data: Dictionary = config.get("defense", {})
	var movement_data: Dictionary = config.get("movement", {})
	var attack_data: Dictionary = config.get("attack", {})
	var summon_data: Dictionary = config.get("summon", {})
	var presentation_data: Dictionary = config.get("presentation", {})
	health.configure(float(health_data.get("max", health.max_health)), restored_health)
	defense.configure(defense_data)
	move_speed = float(movement_data.get("speed", move_speed))
	collision_radius = float(movement_data.get("collision_radius", collision_radius))
	attack_damage = float(attack_data.get("damage", attack_damage))
	attack_range = float(attack_data.get("range", attack_range))
	detection_range = float(attack_data.get("detection_range", detection_range))
	leash_range = float(attack_data.get("leash_range", leash_range))
	attacks_per_second = maxf(float(attack_data.get("attacks_per_second", attacks_per_second)), 0.01)
	target_refresh_interval = maxf(float(attack_data.get("target_refresh", target_refresh_interval)), 0.01)
	damage_type = str(attack_data.get("damage_type", damage_type))
	capacity_cost = maxi(int(summon_data.get("capacity_cost", capacity_cost)), 1)
	visual.configure(presentation_data)
	_apply_collision_radius()
	_apply_detection_range()


func set_formation_offset(new_offset: Vector2) -> void:
	_formation_offset = new_offset


func get_formation_world_position() -> Vector2:
	return _king.global_position + _formation_offset if is_instance_valid(_king) else global_position


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not enabled:
		_set_target(null)
		_stop_moving()


func is_combat_alive() -> bool:
	return health != null and health.is_alive()


func get_combat_snapshot() -> Dictionary:
	return {
		"instance_id": instance_id,
		"unit_id": str(unit_id),
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health.current_health,
	}


func _refresh_target(formation_position: Vector2) -> void:
	_refresh_remaining = target_refresh_interval
	var candidates: Array = %DetectionArea.get_overlapping_bodies()
	var selected := CombatTargetSelector.nearest(global_position, candidates, detection_range) as GoblinController
	if not _is_target_valid(selected, formation_position):
		selected = null
	_set_target(selected)


func _is_target_valid(target: GoblinController, formation_position: Vector2) -> bool:
	return (
		is_instance_valid(target)
		and target.is_combat_alive()
		and formation_position.distance_squared_to(target.global_position) <= leash_range * leash_range
	)


func _set_target(new_target: GoblinController) -> void:
	_current_target = new_target


func _move_toward(offset: Vector2) -> void:
	velocity = offset.normalized() * move_speed
	move_and_slide()
	visual.set_motion(velocity)


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	visual.set_motion(velocity)


func _try_attack(direction: Vector2) -> void:
	if _cooldown_remaining > 0.0 or not is_instance_valid(_current_target):
		return
	_cooldown_remaining = 1.0 / attacks_per_second
	visual.play_attack(direction)
	DamageResolver.apply_damage(
		_current_target.health,
		attack_damage,
		{
			"source_kind": "unit",
			"source_team": "player",
			"source_id": str(unit_id),
			"source_instance_id": instance_id,
			"source_node": self,
			"target_kind": "enemy",
			"target_id": str(_current_target.enemy_id),
			"target_instance_id": _current_target.instance_id,
			"damage_type": damage_type,
			"attack_style": "melee",
		},
		_current_target.defense
	)


func _apply_collision_radius() -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _apply_detection_range() -> void:
	if detection_shape == null:
		return
	var circle := detection_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = detection_range


func _on_health_changed(current: float, maximum: float, delta: float, _context: Dictionary) -> void:
	visual.set_health(current, maximum)
	if delta < 0.0:
		visual.play_hurt()


func _on_died(context: Dictionary) -> void:
	_combat_enabled = false
	_set_target(null)
	_stop_moving()
	remove_from_group("combat_allies")
	remove_from_group("combat_units")
	collision_shape.set_deferred("disabled", true)
	visual.set_defeated()
	defeated.emit(self, context.duplicate(true))
