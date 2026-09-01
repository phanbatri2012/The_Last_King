class_name KingController
extends CharacterBody2D

signal movement_changed(world_position: Vector2, current_velocity: Vector2)
signal defeated(context: Dictionary)

@export_range(1.0, 1000.0, 1.0) var move_speed := 340.0
@export_range(1.0, 100.0, 1.0) var collision_radius := 30.0
@export var movement_bounds := Rect2(-1600.0, -900.0, 3200.0, 1800.0)

@onready var visual: KingPlaceholderVisual = %Visual
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var follow_camera: Camera2D = %FollowCamera
@onready var health: HealthComponent = %Health
@onready var defense: DefenseComponent = %Defense
@onready var auto_attack: KingAutoAttackController = %AutoAttack

var king_id: StringName = &"tran_hung_dao"
var weapon_archetype_id: StringName = &"sword"
var _base_move_speed := 340.0
var _base_max_health := 260.0
var _base_armor := 0.0
var _base_magic_resistance := 0.0
var _skill_armor_bonus := 0.0
var _skill_magic_resistance_bonus := 0.0
var _temporary_armor_bonus := 0.0
var _temporary_magic_resistance_bonus := 0.0
var _virtual_direction := Vector2.ZERO
var _pointer_direction := Vector2.ZERO
var _keyboard_enabled := true
var _movement_enabled := true
var _movement_bounds_enabled := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("combat_allies")
	add_to_group("combat_king")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_apply_collision_radius()
	visual.set_health(health.current_health, health.max_health)


func _physics_process(_delta: float) -> void:
	var keyboard_direction := Vector2.ZERO
	if _keyboard_enabled and _movement_enabled:
		keyboard_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_direction := Vector2.ZERO
	if _movement_enabled:
		desired_direction = MovementInputResolver.resolve(
			keyboard_direction,
			_virtual_direction,
			_pointer_direction
		)
	velocity = MovementInputResolver.to_velocity(desired_direction, move_speed)
	move_and_slide()
	if _movement_bounds_enabled:
		_clamp_to_movement_bounds()
	visual.set_motion(velocity)
	movement_changed.emit(global_position, velocity)


func configure(config: Dictionary) -> void:
	king_id = StringName(str(config.get("id", king_id)))
	weapon_archetype_id = StringName(str(config.get("weapon_archetype_id", weapon_archetype_id)))
	var weapon_archetype_value: Variant = config.get("weapon_archetype", {})
	var weapon_archetype: Dictionary = weapon_archetype_value if weapon_archetype_value is Dictionary else {}
	if weapon_archetype.is_empty():
		weapon_archetype = {
			"id": str(weapon_archetype_id),
			"attack_style": "melee",
			"visual_kind": str(weapon_archetype_id),
		}
	visual.set_weapon_kind(str(weapon_archetype.get("visual_kind", weapon_archetype_id)))
	var movement_value: Variant = config.get("movement", {})
	if movement_value is Dictionary:
		var movement: Dictionary = movement_value
		_base_move_speed = float(movement.get("speed", move_speed))
		move_speed = _base_move_speed
		collision_radius = float(movement.get("collision_radius", collision_radius))
	var health_value: Variant = config.get("health", {})
	if health_value is Dictionary:
		_base_max_health = float(health_value.get("max", health.max_health))
		health.configure(_base_max_health)
	var defense_value: Variant = config.get("defense", {})
	if defense_value is Dictionary:
		_base_armor = float(defense_value.get("armor", defense.armor))
		_base_magic_resistance = float(defense_value.get("magic_resistance", defense.magic_resistance))
		_recompute_defense()
	var attack_value: Variant = config.get("attack", {})
	if attack_value is Dictionary:
		auto_attack.configure(attack_value, weapon_archetype)
	if is_node_ready():
		_apply_collision_radius()


func set_virtual_direction(direction: Vector2) -> void:
	_virtual_direction = direction.limit_length(1.0)


func set_pointer_direction(direction: Vector2) -> void:
	_pointer_direction = direction.limit_length(1.0)


func set_keyboard_enabled(enabled: bool) -> void:
	_keyboard_enabled = enabled


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		_virtual_direction = Vector2.ZERO
		_pointer_direction = Vector2.ZERO


func set_level_display(level_text: String) -> void:
	visual.set_level_text(level_text)


func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds.abs()
	_movement_bounds_enabled = true
	_clamp_to_movement_bounds()


func clear_movement_bounds() -> void:
	_movement_bounds_enabled = false


func has_movement_bounds() -> bool:
	return _movement_bounds_enabled


func restore_health(current_health: float) -> void:
	health.configure(health.max_health, current_health)
	if health.is_alive():
		_movement_enabled = true
		_keyboard_enabled = true
		auto_attack.set_combat_enabled(true)
	else:
		_movement_enabled = false
		_keyboard_enabled = false
		auto_attack.set_combat_enabled(false)
		visual.set_defeated()


func apply_skill_modifiers(
	move_speed_multiplier: float,
	max_health_bonus: float,
	armor_bonus: float,
	magic_resistance_bonus: float
) -> void:
	move_speed = _base_move_speed * maxf(move_speed_multiplier, 0.1)
	var old_max_health := health.max_health
	var old_current_health := health.current_health
	var new_max_health := maxf(_base_max_health + max_health_bonus, 1.0)
	var added_health := maxf(new_max_health - old_max_health, 0.0)
	health.configure(new_max_health, minf(old_current_health + added_health, new_max_health))
	_skill_armor_bonus = maxf(armor_bonus, 0.0)
	_skill_magic_resistance_bonus = maxf(magic_resistance_bonus, 0.0)
	_recompute_defense()


func set_temporary_defense_bonus(armor_bonus: float, magic_resistance_bonus: float) -> void:
	_temporary_armor_bonus = maxf(armor_bonus, 0.0)
	_temporary_magic_resistance_bonus = maxf(magic_resistance_bonus, 0.0)
	_recompute_defense()


func is_combat_alive() -> bool:
	return health != null and health.is_alive()


func _apply_collision_radius() -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _recompute_defense() -> void:
	if defense == null:
		return
	defense.configure({
		"armor": _base_armor + _skill_armor_bonus + _temporary_armor_bonus,
		"magic_resistance": _base_magic_resistance + _skill_magic_resistance_bonus + _temporary_magic_resistance_bonus,
	})


func _clamp_to_movement_bounds() -> void:
	var minimum := movement_bounds.position + Vector2.ONE * collision_radius
	var maximum := movement_bounds.end - Vector2.ONE * collision_radius
	global_position = global_position.clamp(minimum, maximum)


func _on_health_changed(current: float, maximum: float, delta: float, _context: Dictionary) -> void:
	visual.set_health(current, maximum)
	if delta < 0.0:
		visual.play_hurt()
	elif delta > 0.0:
		visual.play_heal(delta)


func _on_died(context: Dictionary) -> void:
	set_temporary_defense_bonus(0.0, 0.0)
	set_movement_enabled(false)
	set_keyboard_enabled(false)
	auto_attack.set_combat_enabled(false)
	velocity = Vector2.ZERO
	visual.set_defeated()
	defeated.emit(context.duplicate(true))
