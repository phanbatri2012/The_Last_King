class_name KingController
extends CharacterBody2D

signal movement_changed(world_position: Vector2, current_velocity: Vector2)

@export_range(1.0, 1000.0, 1.0) var move_speed := 340.0
@export_range(1.0, 100.0, 1.0) var collision_radius := 30.0
@export var movement_bounds := Rect2(-1600.0, -900.0, 3200.0, 1800.0)

@onready var visual: KingPlaceholderVisual = %Visual
@onready var collision_shape: CollisionShape2D = %CollisionShape
@onready var follow_camera: Camera2D = %FollowCamera

var _virtual_direction := Vector2.ZERO
var _keyboard_enabled := true
var _movement_enabled := true


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_apply_collision_radius()


func _physics_process(_delta: float) -> void:
	var keyboard_direction := Vector2.ZERO
	if _keyboard_enabled and _movement_enabled:
		keyboard_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_direction := Vector2.ZERO
	if _movement_enabled:
		desired_direction = MovementInputResolver.resolve(keyboard_direction, _virtual_direction)
	velocity = MovementInputResolver.to_velocity(desired_direction, move_speed)
	move_and_slide()
	_clamp_to_movement_bounds()
	visual.set_motion(velocity)
	movement_changed.emit(global_position, velocity)


func configure(config: Dictionary) -> void:
	var movement_value: Variant = config.get("movement", {})
	if not movement_value is Dictionary:
		return
	var movement: Dictionary = movement_value
	move_speed = float(movement.get("speed", move_speed))
	collision_radius = float(movement.get("collision_radius", collision_radius))
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
	_clamp_to_movement_bounds()


func _apply_collision_radius() -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _clamp_to_movement_bounds() -> void:
	var minimum := movement_bounds.position + Vector2.ONE * collision_radius
	var maximum := movement_bounds.end - Vector2.ONE * collision_radius
	global_position = global_position.clamp(minimum, maximum)
