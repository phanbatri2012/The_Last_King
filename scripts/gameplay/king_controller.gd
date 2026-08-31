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
var _virtual_direction := Vector2.ZERO
var _keyboard_enabled := true
var _movement_enabled := true
var _movement_bounds_enabled := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
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
		desired_direction = MovementInputResolver.resolve(keyboard_direction, _virtual_direction)
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
		move_speed = float(movement.get("speed", move_speed))
		collision_radius = float(movement.get("collision_radius", collision_radius))
	var health_value: Variant = config.get("health", {})
	if health_value is Dictionary:
		health.configure(float(health_value.get("max", health.max_health)))
	var defense_value: Variant = config.get("defense", {})
	if defense_value is Dictionary:
		defense.configure(defense_value)
	var attack_value: Variant = config.get("attack", {})
	if attack_value is Dictionary:
		auto_attack.configure(attack_value, weapon_archetype)
	if is_node_ready():
		_apply_collision_radius()


func set_virtual_direction(direction: Vector2) -> void:
	_virtual_direction = direction.limit_length(1.0)


func set_keyboard_enabled(enabled: bool) -> void:
	_keyboard_enabled = enabled


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		_virtual_direction = Vector2.ZERO


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


func is_combat_alive() -> bool:
	return health != null and health.is_alive()


func _apply_collision_radius() -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _clamp_to_movement_bounds() -> void:
	var minimum := movement_bounds.position + Vector2.ONE * collision_radius
	var maximum := movement_bounds.end - Vector2.ONE * collision_radius
	global_position = global_position.clamp(minimum, maximum)


func _on_health_changed(current: float, maximum: float, delta: float, _context: Dictionary) -> void:
	visual.set_health(current, maximum)
	if delta < 0.0:
		visual.play_hurt()


func _on_died(context: Dictionary) -> void:
	set_movement_enabled(false)
	set_keyboard_enabled(false)
	auto_attack.set_combat_enabled(false)
	velocity = Vector2.ZERO
	visual.set_defeated()
	defeated.emit(context.duplicate(true))
