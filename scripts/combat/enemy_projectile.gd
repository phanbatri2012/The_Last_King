class_name EnemyProjectile
extends Area2D

signal resolved(projectile: EnemyProjectile)

@onready var collision_shape: CollisionShape2D = %CollisionShape

var projectile_id := ""
var visual_kind := "arrow"
var damage_type := "physical"
var damage := 1.0
var speed := 500.0
var radius := 5.0
var lifetime := 1.0

var _direction := Vector2.RIGHT
var _remaining_lifetime := 0.0
var _context: Dictionary = {}
var _active := false
var _animation_phase := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	deactivate()


func activate(request: Dictionary) -> void:
	projectile_id = str(request.get("projectile_id", "enemy_projectile"))
	visual_kind = str(request.get("visual_kind", "arrow"))
	damage_type = str(request.get("damage_type", "physical"))
	damage = maxf(float(request.get("damage", 1.0)), 1.0)
	speed = maxf(float(request.get("speed", 500.0)), 1.0)
	radius = maxf(float(request.get("radius", 5.0)), 1.0)
	lifetime = maxf(float(request.get("lifetime", 1.0)), 0.05)
	global_position = request.get("position", Vector2.ZERO)
	var requested_direction: Vector2 = request.get("direction", Vector2.RIGHT)
	_direction = requested_direction.normalized() if not requested_direction.is_zero_approx() else Vector2.RIGHT
	_context = request.get("context", {}).duplicate(true)
	_remaining_lifetime = lifetime
	_animation_phase = 0.0
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
	_animation_phase = fmod(_animation_phase + delta * 9.0, TAU)
	global_position += _direction * speed * delta
	queue_redraw()
	if _remaining_lifetime <= 0.0:
		_resolve()


func _draw() -> void:
	if not _active:
		return
	var side := Vector2(-_direction.y, _direction.x)
	if visual_kind == "magic_orb":
		var pulse := 1.0 + sin(_animation_phase) * 0.13
		var magic_color := Color(0.76, 0.3, 1.0, 0.96)
		draw_circle(Vector2.ZERO, radius * 2.3 * pulse, Color(magic_color, 0.16))
		draw_circle(Vector2.ZERO, radius * pulse, magic_color)
		draw_arc(Vector2.ZERO, radius * 1.45, _animation_phase, _animation_phase + 4.4, 18, Color(0.95, 0.65, 1.0, 0.9), 2.0, true)
		return
	var arrow_color := Color(0.86, 0.88, 0.78, 1.0)
	draw_line(-_direction * 16.0, _direction * 11.0, arrow_color, 3.0, true)
	draw_line(_direction * 11.0, _direction * 2.0 + side * 5.0, arrow_color, 2.0, true)
	draw_line(_direction * 11.0, _direction * 2.0 - side * 5.0, arrow_color, 2.0, true)
	draw_line(-_direction * 15.0, -_direction * 8.0 + side * 5.0, Color(0.74, 0.45, 0.18, 1.0), 2.0, true)
	draw_line(-_direction * 15.0, -_direction * 8.0 - side * 5.0, Color(0.74, 0.45, 0.18, 1.0), 2.0, true)


func _apply_radius() -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius


func _on_body_entered(body: Node2D) -> void:
	if not _active or not body.has_method("is_combat_alive") or not bool(body.call("is_combat_alive")):
		return
	if not (body is KingController or body is SummonedUnitController):
		return
	var target_health := body.get("health") as HealthComponent
	var target_defense := body.get("defense") as DefenseComponent
	if target_health == null:
		return
	var hit_context := _context.duplicate(true)
	hit_context["projectile_id"] = projectile_id
	hit_context["target_kind"] = "unit" if body is SummonedUnitController else "king"
	DamageResolver.apply_damage(target_health, damage, hit_context, target_defense)
	_resolve()


func _resolve() -> void:
	if not _active:
		return
	deactivate()
	resolved.emit(self)
