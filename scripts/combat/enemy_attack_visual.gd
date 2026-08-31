class_name EnemyAttackVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var melee_duration := 0.18
var attack_style := "melee"
var damage_type := "physical"
var _remaining := 0.0
var _duration := 0.18
var _direction := Vector2.LEFT
var _reach := 70.0
var _telegraphing := false


func _ready() -> void:
	set_process(false)


func configure(new_attack_style: String, new_damage_type: String) -> void:
	attack_style = new_attack_style if new_attack_style in ["melee", "ranged"] else "melee"
	damage_type = new_damage_type if new_damage_type in ["physical", "magic"] else "physical"


func play_melee(direction: Vector2, reach: float) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.LEFT
	_reach = clampf(reach, 45.0, 110.0)
	_duration = melee_duration
	_telegraphing = false
	_remaining = _duration
	set_process(true)
	queue_redraw()


func play_telegraph(direction: Vector2, reach: float, duration: float) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.LEFT
	_reach = clampf(reach, 70.0, 700.0)
	_duration = maxf(duration, 0.05)
	_remaining = _duration
	_telegraphing = true
	set_process(true)
	queue_redraw()


func cancel() -> void:
	_remaining = 0.0
	_telegraphing = false
	set_process(false)
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
	if _telegraphing:
		_draw_telegraph(progress, base_color)
	else:
		var alpha := 1.0 - progress
		var angle := _direction.angle()
		draw_arc(Vector2.ZERO, _reach * 0.62, angle - 0.7 + progress * 0.4, angle + 0.38 + progress * 0.4, 16, Color(base_color, base_color.a * alpha), 7.0, true)


func _draw_telegraph(progress: float, color: Color) -> void:
	var charge_position := _direction * 30.0
	var charge_radius := lerpf(12.0, 5.0, progress)
	draw_circle(charge_position, charge_radius * 1.8, Color(color, 0.08 + progress * 0.16))
	draw_circle(charge_position, charge_radius, Color(color, 0.4 + progress * 0.5))
	draw_arc(Vector2.ZERO, 35.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 28, Color(color, 0.52 + progress * 0.36), 3.0, true)
