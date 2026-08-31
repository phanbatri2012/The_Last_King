class_name KingAttackVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var melee_duration := 0.16
@export_range(0.05, 1.0, 0.01) var ranged_duration := 0.24
@export var melee_color := Color(1.0, 0.82, 0.28, 0.9)
@export var ranged_color := Color(0.35, 0.88, 1.0, 0.95)

var attack_style := "melee"
var _remaining := 0.0
var _duration := 0.16
var _direction := Vector2.RIGHT
var _reach := 80.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()
	if _remaining <= 0.0:
		set_process(false)


func configure(new_attack_style: String) -> void:
	attack_style = new_attack_style if new_attack_style in ["melee", "ranged"] else "melee"


func play(direction: Vector2, reach: float) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	if attack_style == "ranged":
		_reach = clampf(reach, 80.0, 1000.0)
		_duration = ranged_duration
	else:
		_reach = clampf(reach, 55.0, 140.0)
		_duration = melee_duration
	_remaining = _duration
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _remaining <= 0.0:
		return
	var progress := 1.0 - (_remaining / _duration)
	if attack_style == "ranged":
		_draw_ranged_projectile(progress)
	else:
		_draw_melee_strike(progress)


func _draw_melee_strike(progress: float) -> void:
	var alpha := 1.0 - progress
	var angle := _direction.angle()
	var color := Color(melee_color, melee_color.a * alpha)
	draw_arc(Vector2.ZERO, _reach * 0.58, angle - 0.78 + progress * 0.45, angle + 0.42 + progress * 0.45, 20, color, 10.0, true)
	draw_line(_direction * 30.0, _direction * _reach, Color(color, color.a * 0.55), 4.0, true)


func _draw_ranged_projectile(progress: float) -> void:
	var side := Vector2(-_direction.y, _direction.x)
	var projectile_position := _direction * lerpf(34.0, _reach, minf(progress * 1.35, 1.0))
	var alpha := 1.0 - maxf(progress - 0.7, 0.0) / 0.3
	var color := Color(ranged_color, ranged_color.a * alpha)
	draw_line(projectile_position - _direction * 24.0, projectile_position + _direction * 12.0, color, 4.0, true)
	draw_line(projectile_position + _direction * 12.0, projectile_position - _direction * 1.0 + side * 8.0, color, 3.0, true)
	draw_line(projectile_position + _direction * 12.0, projectile_position - _direction * 1.0 - side * 8.0, color, 3.0, true)
	draw_line(_direction * 28.0, projectile_position - _direction * 20.0, Color(color, color.a * 0.22), 2.0, true)
