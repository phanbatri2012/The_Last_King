class_name EnemyAttackVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var melee_duration := 0.18
@export_range(0.05, 1.0, 0.01) var projectile_duration := 0.28

var attack_style := "melee"
var damage_type := "physical"
var _remaining := 0.0
var _duration := 0.18
var _direction := Vector2.LEFT
var _reach := 70.0


func _ready() -> void:
	set_process(false)


func configure(new_attack_style: String, new_damage_type: String) -> void:
	attack_style = new_attack_style if new_attack_style in ["melee", "ranged"] else "melee"
	damage_type = new_damage_type if new_damage_type in ["physical", "magic"] else "physical"


func play(direction: Vector2, reach: float) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.LEFT
	if attack_style == "ranged":
		_reach = clampf(reach, 70.0, 700.0)
		_duration = projectile_duration
	else:
		_reach = clampf(reach, 45.0, 110.0)
		_duration = melee_duration
	_remaining = _duration
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()
	if _remaining <= 0.0:
		set_process(false)


func _draw() -> void:
	if _remaining <= 0.0:
		return
	var progress := 1.0 - _remaining / _duration
	var base_color := Color(0.72, 0.38, 0.16, 0.95) if damage_type == "physical" else Color(0.73, 0.34, 1.0, 0.95)
	if attack_style == "ranged":
		_draw_projectile(progress, base_color)
	else:
		var alpha := 1.0 - progress
		var angle := _direction.angle()
		draw_arc(Vector2.ZERO, _reach * 0.62, angle - 0.7 + progress * 0.4, angle + 0.38 + progress * 0.4, 16, Color(base_color, base_color.a * alpha), 7.0, true)


func _draw_projectile(progress: float, color: Color) -> void:
	var side := Vector2(-_direction.y, _direction.x)
	var projectile_position := _direction * lerpf(28.0, _reach, minf(progress * 1.25, 1.0))
	var alpha := 1.0 - maxf(progress - 0.72, 0.0) / 0.28
	var projectile_color := Color(color, color.a * alpha)
	if damage_type == "magic":
		draw_circle(projectile_position, 9.0, Color(projectile_color, projectile_color.a * 0.28))
		draw_circle(projectile_position, 5.0, projectile_color)
		draw_line(_direction * 22.0, projectile_position - _direction * 8.0, Color(projectile_color, projectile_color.a * 0.22), 3.0, true)
	else:
		draw_line(projectile_position - _direction * 18.0, projectile_position + _direction * 10.0, projectile_color, 3.0, true)
		draw_line(projectile_position + _direction * 10.0, projectile_position - _direction * 1.0 + side * 6.0, projectile_color, 2.0, true)
		draw_line(projectile_position + _direction * 10.0, projectile_position - _direction * 1.0 - side * 6.0, projectile_color, 2.0, true)
