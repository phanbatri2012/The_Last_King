class_name GoblinPlaceholderVisual
extends Node2D

const HEALTH_BAR_FILL_COLOR := Color(0.74, 0.16, 0.12, 1.0)

var _facing := Vector2.LEFT
var _moving := false
var _targeted := false
var _engaged := false
var _health_ratio := 1.0
var _step_phase := 0.0
var _attack_pulse := 0.0
var _hurt_flash := 0.0
var _defeated := false
var _visual_kind := "raider"
var _body_color := Color(0.27, 0.54, 0.2, 1.0)
var _accent_color := Color(0.52, 0.28, 0.1, 1.0)


func _process(delta: float) -> void:
	if _moving and not _defeated:
		_step_phase += delta * 9.0
		position.y = sin(_step_phase) * 2.0
	else:
		position.y = lerpf(position.y, 0.0, minf(delta * 12.0, 1.0))
	_attack_pulse = maxf(_attack_pulse - delta * 5.0, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 6.0, 0.0)
	queue_redraw()


func set_motion(current_velocity: Vector2) -> void:
	_moving = current_velocity.length_squared() > 1.0
	if _moving:
		_facing = current_velocity.normalized()


func set_targeted(targeted: bool) -> void:
	_targeted = targeted
	queue_redraw()


func configure(presentation: Dictionary) -> void:
	_visual_kind = str(presentation.get("visual_kind", _visual_kind))
	_body_color = Color.from_string(str(presentation.get("body_color", "")), _body_color)
	_accent_color = Color.from_string(str(presentation.get("accent_color", "")), _accent_color)
	queue_redraw()


func set_engaged(engaged: bool) -> void:
	_engaged = engaged
	queue_redraw()


func set_health(current_health: float, max_health: float) -> void:
	_health_ratio = clampf(current_health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	queue_redraw()


func play_attack(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_facing = direction.normalized()
	_attack_pulse = 1.0


func play_hurt() -> void:
	_hurt_flash = 1.0


func set_defeated() -> void:
	_defeated = true
	_moving = false
	_targeted = false
	_engaged = false
	queue_redraw()


func _draw() -> void:
	var body_color := _body_color
	if _hurt_flash > 0.0:
		body_color = body_color.lerp(Color(1.0, 0.85, 0.72, 1.0), _hurt_flash)
	if _defeated:
		body_color = Color(0.18, 0.2, 0.16, 0.7)
		draw_set_transform(Vector2(0.0, 18.0), -0.9, Vector2(1.0, 0.55))

	if _targeted:
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 40, Color(1.0, 0.74, 0.18, 0.9), 4.0, true)
	elif _engaged and not _defeated:
		draw_arc(Vector2.ZERO, 34.0, -2.7, -0.45, 24, Color(0.92, 0.24, 0.16, 0.72), 3.0, true)
	draw_set_transform(Vector2(0.0, 24.0), 0.0, Vector2(1.25, 0.38))
	draw_circle(Vector2.ZERO, 21.0, Color(0.0, 0.0, 0.0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var side := Vector2(-_facing.y, _facing.x)
	var ear_points_left := PackedVector2Array([Vector2(-15.0, -10.0), Vector2(-35.0, -20.0), Vector2(-19.0, 2.0)])
	var ear_points_right := PackedVector2Array([Vector2(15.0, -10.0), Vector2(35.0, -20.0), Vector2(19.0, 2.0)])
	draw_colored_polygon(ear_points_left, body_color.darkened(0.1))
	draw_colored_polygon(ear_points_right, body_color.darkened(0.1))
	var body_radius := 27.0 if _visual_kind == "brute" else 24.0
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 36, body_color.darkened(0.58), 3.0, true)
	draw_circle(Vector2(-7.0, -5.0), 3.0, Color(0.96, 0.82, 0.2, 1.0))
	draw_circle(Vector2(7.0, -5.0), 3.0, Color(0.96, 0.82, 0.2, 1.0))
	draw_line(Vector2(-8.0, 10.0), Vector2(8.0, 10.0), Color(0.13, 0.07, 0.04, 1.0), 3.0, true)

	_draw_weapon(side)

	if not _defeated:
		var bar_rect := Rect2(-29.0, -42.0, 58.0, 7.0)
		draw_rect(bar_rect, Color(0.04, 0.04, 0.04, 0.88), true)
		draw_rect(Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_rect.size.x - 2.0) * _health_ratio, bar_rect.size.y - 2.0)), HEALTH_BAR_FILL_COLOR, true)


func _draw_weapon(side: Vector2) -> void:
	var weapon_start := _facing * 10.0 + side * 18.0
	match _visual_kind:
		"brute":
			var hammer_end := weapon_start + _facing * (39.0 + _attack_pulse * 12.0)
			draw_line(weapon_start, hammer_end, _accent_color.darkened(0.35), 10.0, true)
			draw_rect(Rect2(hammer_end - Vector2(10.0, 8.0), Vector2(20.0, 16.0)), _accent_color, true)
			draw_circle(-side * 23.0 + Vector2(0.0, 5.0), 13.0, Color(0.22, 0.26, 0.24, 1.0))
			draw_arc(-side * 23.0 + Vector2(0.0, 5.0), 13.0, 0.0, TAU, 24, _accent_color, 3.0, true)
		"archer":
			var bow_center := weapon_start + _facing * 3.0
			var upper_tip := bow_center + side * 19.0 - _facing * 6.0
			var lower_tip := bow_center - side * 19.0 - _facing * 6.0
			draw_polyline(PackedVector2Array([upper_tip, bow_center + _facing * 7.0, lower_tip]), _accent_color, 4.0, true)
			draw_line(upper_tip, lower_tip, Color(0.9, 0.86, 0.68, 0.95), 2.0, true)
			draw_line(bow_center - _facing * 7.0, bow_center + _facing * (34.0 + _attack_pulse * 9.0), Color(0.72, 0.76, 0.72, 1.0), 2.0, true)
		"hexer":
			var staff_end := weapon_start + _facing * (38.0 + _attack_pulse * 8.0)
			draw_line(weapon_start, staff_end, Color(0.3, 0.16, 0.08, 1.0), 7.0, true)
			draw_circle(staff_end, 10.0 + _attack_pulse * 3.0, Color(_accent_color, 0.25))
			draw_circle(staff_end, 6.0, _accent_color)
		_:
			var club_end := weapon_start + _facing * (44.0 + _attack_pulse * 13.0)
			draw_line(weapon_start, club_end, _accent_color.darkened(0.35), 9.0, true)
			draw_circle(club_end, 9.0, _accent_color.darkened(0.5))
