class_name KingPlaceholderVisual
extends Node2D

var _facing := Vector2.RIGHT
var _moving := false
var _step_phase := 0.0


func _process(delta: float) -> void:
	if _moving:
		_step_phase += delta * 10.0
		position.y = sin(_step_phase) * 2.5
	else:
		position.y = lerpf(position.y, 0.0, minf(delta * 12.0, 1.0))
	queue_redraw()


func set_motion(current_velocity: Vector2) -> void:
	_moving = current_velocity.length_squared() > 1.0
	if _moving:
		_facing = current_velocity.normalized()


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 29.0), 0.0, Vector2(1.35, 0.38))
	draw_circle(Vector2.ZERO, 25.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var side := Vector2(-_facing.y, _facing.x)
	var cape_points := PackedVector2Array([
		Vector2(-25.0, 7.0),
		Vector2(25.0, 7.0),
		Vector2(18.0, 34.0),
		Vector2(-18.0, 34.0),
	])
	draw_colored_polygon(cape_points, Color(0.36, 0.055, 0.07, 1.0))
	draw_circle(Vector2(0.0, 7.0), 26.0, Color(0.08, 0.23, 0.34, 1.0))
	draw_arc(Vector2(0.0, 7.0), 26.0, 0.0, TAU, 48, Color(0.88, 0.67, 0.2, 1.0), 3.0, true)

	var weapon_start := _facing * 16.0 + side * 10.0 + Vector2(0.0, 8.0)
	var weapon_end := weapon_start + _facing * 48.0
	draw_line(weapon_start, weapon_end, Color(0.82, 0.86, 0.9, 1.0), 7.0, true)
	draw_line(weapon_start + _facing * 4.0 - side * 10.0, weapon_start + _facing * 4.0 + side * 10.0, Color(0.9, 0.68, 0.2, 1.0), 5.0, true)

	draw_circle(Vector2(0.0, -12.0), 18.0, Color(0.88, 0.68, 0.48, 1.0))
	draw_circle(Vector2(-6.0, -14.0), 2.0, Color(0.08, 0.08, 0.1, 1.0))
	draw_circle(Vector2(6.0, -14.0), 2.0, Color(0.08, 0.08, 0.1, 1.0))
	draw_line(Vector2(-5.0, -5.0), Vector2(5.0, -5.0), Color(0.32, 0.14, 0.1, 1.0), 2.0, true)

	var crown_points := PackedVector2Array([
		Vector2(-19.0, -23.0),
		Vector2(-17.0, -40.0),
		Vector2(-7.0, -31.0),
		Vector2(0.0, -44.0),
		Vector2(7.0, -31.0),
		Vector2(17.0, -40.0),
		Vector2(19.0, -23.0),
	])
	draw_colored_polygon(crown_points, Color(0.96, 0.73, 0.18, 1.0))
	draw_polyline(crown_points, Color(1.0, 0.9, 0.45, 1.0), 2.0, true)
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 64, Color(0.96, 0.75, 0.24, 0.34), 2.0, true)
