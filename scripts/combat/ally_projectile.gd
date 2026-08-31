class_name AllyProjectile
extends Area2D

signal resolved(projectile: AllyProjectile)

@onready var collision_shape: CollisionShape2D = %CollisionShape

var projectile_id := ""
var visual_kind := "arrow"
var damage_type := "physical"
var damage := 1.0
var speed := 600.0
var radius := 4.0
var lifetime := 1.0

var _direction := Vector2.RIGHT
var _remaining_lifetime := 0.0
var _context: Dictionary = {}
var _active := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	deactivate()


func activate(request: Dictionary) -> void:
	projectile_id = str(request.get("projectile_id", "ally_projectile"))
	visual_kind = str(request.get("visual_kind", "arrow"))
	damage_type = str(request.get("damage_type", "physical"))
	damage = maxf(float(request.get("damage", 1.0)), 1.0)
	speed = maxf(float(request.get("speed", 600.0)), 1.0)
	radius = maxf(float(request.get("radius", 4.0)), 1.0)
	lifetime = maxf(float(request.get("lifetime", 1.0)), 0.05)
	global_position = request.get("position", Vector2.ZERO)
	var requested_direction: Vector2 = request.get("direction", Vector2.RIGHT)
	_direction = requested_direction.normalized() if not requested_direction.is_zero_approx() else Vector2.RIGHT
	_context = request.get("context", {}).duplicate(true)
	_remaining_lifetime = lifetime
	_apply_radius()
	_active = true
	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)
	queue_redraw()


func deactivate() -> void:
	if not _active and not visible:
		return
	_active = false
	visible = false
	set_physics_process(false)
	set_deferred("monitoring", false)
	queue_redraw()


func is_active() -> bool:
	return _active


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_remaining_lifetime = maxf(_remaining_lifetime - delta, 0.0)
	global_position += _direction * speed * delta
	queue_redraw()
	if _remaining_lifetime <= 0.0:
		_resolve()


func _draw() -> void:
	if not _active:
		return
	var side := Vector2(-_direction.y, _direction.x)
	var shaft_color := Color(0.62, 0.88, 1.0, 1.0) if visual_kind == "bolt" else Color(0.9, 0.84, 0.58, 1.0)
	var shaft_start := -_direction * (12.0 if visual_kind == "bolt" else 16.0)
	var shaft_end := _direction * 11.0
	draw_line(shaft_start, shaft_end, shaft_color, 4.0 if visual_kind == "bolt" else 3.0, true)
	draw_line(shaft_end, _direction * 2.0 + side * 5.0, Color(0.9, 0.94, 0.98, 1.0), 2.0, true)
	draw_line(shaft_end, _direction * 2.0 - side * 5.0, Color(0.9, 0.94, 0.98, 1.0), 2.0, true)
	if visual_kind == "arrow":
		draw_line(shaft_start, -_direction * 8.0 + side * 5.0, Color(0.42, 0.68, 0.48, 1.0), 2.0, true)
		draw_line(shaft_start, -_direction * 8.0 - side * 5.0, Color(0.42, 0.68, 0.48, 1.0), 2.0, true)


func _apply_radius() -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius


func _on_body_entered(body: Node2D) -> void:
	if not _active or not body is GoblinController:
		return
	var enemy := body as GoblinController
	if not enemy.is_combat_alive():
		return
	var hit_context := _context.duplicate(true)
	hit_context["projectile_id"] = projectile_id
	hit_context["target_kind"] = "enemy"
	hit_context["target_id"] = str(enemy.enemy_id)
	hit_context["target_instance_id"] = enemy.instance_id
	DamageResolver.apply_damage(enemy.health, damage, hit_context, enemy.defense)
	_resolve()


func _resolve() -> void:
	if not _active:
		return
	deactivate()
	resolved.emit(self)
