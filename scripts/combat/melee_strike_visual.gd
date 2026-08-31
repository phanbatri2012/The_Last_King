class_name MeleeStrikeVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var duration := 0.16
@export var strike_color := Color(1.0, 0.82, 0.28, 0.9)

var _remaining := 0.0
var _direction := Vector2.RIGHT
var _reach := 80.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()
	if _remaining <= 0.0:
		set_process(false)


func play(direction: Vector2, reach: float) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_reach = clampf(reach, 55.0, 125.0)
	_remaining = duration
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _remaining <= 0.0:
		return
	var progress := 1.0 - (_remaining / duration)
	var alpha := 1.0 - progress
	var angle := _direction.angle()
	var color := Color(strike_color, strike_color.a * alpha)
	draw_arc(Vector2.ZERO, _reach * 0.58, angle - 0.78 + progress * 0.45, angle + 0.42 + progress * 0.45, 20, color, 10.0, true)
	draw_line(_direction * 30.0, _direction * _reach, Color(color, color.a * 0.55), 4.0, true)
