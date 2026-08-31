class_name SummonedUnitPlaceholderVisual
extends Node2D

const HEALTH_BAR_FILL_COLOR := Color(0.24, 0.58, 0.96, 1.0)

var _facing := Vector2.RIGHT
var _moving := false
var _health_ratio := 1.0
var _step_phase := 0.0
var _attack_pulse := 0.0
var _hurt_flash := 0.0
var _defeated := false
var _body_color := Color(0.19, 0.37, 0.53, 1.0)
var _accent_color := Color(0.88, 0.72, 0.28, 1.0)


func _process(delta: float) -> void:
	if _moving:
		_step_phase = fmod(_step_phase + delta * 9.0, TAU)
	else:
		_step_phase = move_toward(_step_phase, 0.0, delta * 8.0)
	_attack_pulse = maxf(_attack_pulse - delta * 5.5, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 4.5, 0.0)
	queue_redraw()


func configure(presentation: Dictionary) -> void:
	_body_color = Color.from_string(str(presentation.get("body_color", "")), _body_color)
	_accent_color = Color.from_string(str(presentation.get("accent_color", "")), _accent_color)
	queue_redraw()


func set_motion(current_velocity: Vector2) -> void:
	_moving = not current_velocity.is_zero_approx()
	if _moving:
		_facing = current_velocity.normalized()
	queue_redraw()


func set_health(current_health: float, max_health: float) -> void:
	_health_ratio = clampf(current_health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	queue_redraw()


func play_attack(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_facing = direction.normalized()
	_attack_pulse = 1.0
	queue_redraw()


func play_hurt() -> void:
	_hurt_flash = 1.0
	queue_redraw()


func set_defeated() -> void:
	_defeated = true
	_moving = false
	queue_redraw()


func get_health_ratio() -> float:
	return _health_ratio


func _draw() -> void:
	var side := Vector2(-_facing.y, _facing.x)
	var bob := sin(_step_phase) * 2.0 if _moving else 0.0
	var body_color := _body_color.lerp(Color(1.0, 0.92, 0.72, 1.0), _hurt_flash)
	if _defeated:
		body_color = body_color.darkened(0.62)
		draw_set_transform(Vector2(0.0, 12.0), 1.35, Vector2(1.0, 1.0))

	draw_set_transform(Vector2(0.0, 21.0), 0.0, Vector2(1.18, 0.34))
	draw_circle(Vector2.ZERO, 19.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, bob + 3.0), 20.0, body_color)
	draw_arc(Vector2(0.0, bob + 3.0), 20.0, 0.0, TAU, 32, body_color.darkened(0.5), 3.0, true)
	draw_arc(Vector2(0.0, bob - 3.0), 17.0, PI, TAU, 18, _accent_color, 6.0, true)
	draw_circle(Vector2(0.0, bob - 5.0), 13.0, Color(0.78, 0.55, 0.34, 1.0))
	draw_circle(Vector2(0.0, bob - 10.0), 14.0, _accent_color.darkened(0.22))
	draw_rect(Rect2(Vector2(-14.0, bob - 11.0), Vector2(28.0, 5.0)), _accent_color, true)
	draw_circle(Vector2(0.0, bob - 22.0), 3.0, _accent_color)

	var spear_start := -_facing * 21.0 + side * 10.0
	var spear_end := _facing * (49.0 + _attack_pulse * 19.0) + side * 10.0
	draw_line(spear_start, spear_end, Color(0.46, 0.27, 0.12, 1.0), 5.0, true)
	var spear_tip := spear_end + _facing * 13.0
	draw_colored_polygon(
		PackedVector2Array([spear_end + side * 6.0, spear_tip, spear_end - side * 6.0]),
		Color(0.78, 0.82, 0.85, 1.0)
	)

	if not _defeated:
		var bar_rect := Rect2(-27.0, -42.0, 54.0, 7.0)
		draw_rect(bar_rect, Color(0.04, 0.04, 0.05, 0.88), true)
		draw_rect(
			Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_rect.size.x - 2.0) * _health_ratio, bar_rect.size.y - 2.0)),
			HEALTH_BAR_FILL_COLOR,
			true
		)
