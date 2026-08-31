class_name KingPlaceholderVisual
extends Node2D

const HEALTH_BAR_FILL_COLOR := Color(0.08, 0.72, 0.94, 1.0)
const HEALTH_BAR_BORDER_COLOR := Color(1.0, 0.78, 0.2, 1.0)
const HEALTH_BAR_OFFSET_Y := -64.0

var _facing := Vector2.RIGHT
var _moving := false
var _step_phase := 0.0
var _attack_pulse := 0.0
var _hurt_flash := 0.0
var _heal_pulse := 0.0
var _heal_amount := 0.0
var _defeated := false
var _health_ratio := 1.0
var _weapon_kind := "sword"


func _process(delta: float) -> void:
	if _moving and not _defeated:
		_step_phase += delta * 10.0
		position.y = sin(_step_phase) * 2.5
	else:
		position.y = lerpf(position.y, 0.0, minf(delta * 12.0, 1.0))
	_attack_pulse = maxf(_attack_pulse - delta * 5.0, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 6.0, 0.0)
	_heal_pulse = maxf(_heal_pulse - delta * 1.45, 0.0)
	queue_redraw()


func set_motion(current_velocity: Vector2) -> void:
	_moving = current_velocity.length_squared() > 1.0
	if _moving:
		_facing = current_velocity.normalized()


func set_health(current_health: float, max_health: float) -> void:
	_health_ratio = clampf(current_health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	queue_redraw()


func get_health_ratio() -> float:
	return _health_ratio


func set_weapon_kind(weapon_kind: String) -> void:
	_weapon_kind = weapon_kind if weapon_kind in ["sword", "blade", "bow", "crossbow"] else "sword"
	queue_redraw()


func play_attack(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_facing = direction.normalized()
	_attack_pulse = 1.0


func play_hurt() -> void:
	_hurt_flash = 1.0


func play_heal(amount: float) -> void:
	_heal_amount = maxf(amount, 0.0)
	_heal_pulse = 1.0
	queue_redraw()


func is_heal_feedback_active() -> bool:
	return _heal_pulse > 0.0


func set_defeated() -> void:
	_defeated = true
	_moving = false
	queue_redraw()


func _draw() -> void:
	var armor_color := Color(0.08, 0.23, 0.34, 1.0)
	var cape_color := Color(0.36, 0.055, 0.07, 1.0)
	if _hurt_flash > 0.0:
		armor_color = armor_color.lerp(Color(0.86, 0.34, 0.24, 1.0), _hurt_flash)
		cape_color = cape_color.lerp(Color(0.95, 0.52, 0.32, 1.0), _hurt_flash)
	if _defeated:
		armor_color = Color(0.12, 0.14, 0.16, 0.76)
		cape_color = Color(0.18, 0.08, 0.08, 0.68)

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
	draw_colored_polygon(cape_points, cape_color)
	draw_circle(Vector2(0.0, 7.0), 26.0, armor_color)
	draw_arc(Vector2(0.0, 7.0), 26.0, 0.0, TAU, 48, Color(0.88, 0.67, 0.2, 1.0), 3.0, true)

	_draw_weapon(side)

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
	if _heal_pulse > 0.0 and not _defeated:
		var heal_progress := 1.0 - _heal_pulse
		var heal_color := Color(0.28, 1.0, 0.48, _heal_pulse)
		draw_arc(Vector2.ZERO, 46.0 + heal_progress * 18.0, 0.0, TAU, 48, heal_color, 4.0, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-24.0, -74.0 - heal_progress * 20.0),
			"+%d" % roundi(_heal_amount),
			HORIZONTAL_ALIGNMENT_CENTER,
			48.0,
			20,
			heal_color
		)

	if not _defeated:
		_draw_health_bar()


func _draw_weapon(side: Vector2) -> void:
	var weapon_start := _facing * 16.0 + side * 10.0 + Vector2(0.0, 8.0)
	match _weapon_kind:
		"bow":
			var bow_center := weapon_start + _facing * 4.0
			var upper_tip := bow_center + side * 23.0 - _facing * 7.0
			var lower_tip := bow_center - side * 23.0 - _facing * 7.0
			draw_polyline(PackedVector2Array([upper_tip, bow_center + _facing * 8.0, lower_tip]), Color(0.65, 0.34, 0.12, 1.0), 5.0, true)
			draw_line(upper_tip, lower_tip, Color(0.9, 0.88, 0.72, 0.95), 2.0, true)
			draw_line(bow_center - _facing * 8.0, bow_center + _facing * (40.0 + _attack_pulse * 10.0), Color(0.82, 0.86, 0.9, 1.0), 3.0, true)
		"crossbow":
			var crossbow_center := weapon_start + _facing * 8.0
			draw_line(crossbow_center - _facing * 12.0, crossbow_center + _facing * (42.0 + _attack_pulse * 9.0), Color(0.46, 0.25, 0.1, 1.0), 7.0, true)
			draw_line(crossbow_center - side * 22.0, crossbow_center + side * 22.0, Color(0.72, 0.42, 0.16, 1.0), 5.0, true)
			draw_line(crossbow_center - side * 22.0, crossbow_center + _facing * 8.0, Color(0.9, 0.88, 0.72, 0.95), 2.0, true)
			draw_line(crossbow_center + side * 22.0, crossbow_center + _facing * 8.0, Color(0.9, 0.88, 0.72, 0.95), 2.0, true)
		"blade":
			var blade_end := weapon_start + _facing * (52.0 + _attack_pulse * 20.0) + side * 5.0
			draw_line(weapon_start, blade_end, Color(0.78, 0.84, 0.9, 1.0), 10.0, true)
			draw_line(blade_end, blade_end + _facing * 9.0 - side * 5.0, Color(0.94, 0.72, 0.22, 1.0), 6.0, true)
		_:
			var weapon_end := weapon_start + _facing * (48.0 + _attack_pulse * 18.0)
			draw_line(weapon_start, weapon_end, Color(0.82, 0.86, 0.9, 1.0), 7.0, true)
			draw_line(weapon_start + _facing * 4.0 - side * 10.0, weapon_start + _facing * 4.0 + side * 10.0, Color(0.9, 0.68, 0.2, 1.0), 5.0, true)


func _draw_health_bar() -> void:
	var bar_rect := Rect2(-41.0, HEALTH_BAR_OFFSET_Y, 82.0, 10.0)
	draw_rect(bar_rect, Color(0.015, 0.025, 0.04, 0.94), true)
	draw_rect(
		Rect2(bar_rect.position + Vector2(2.0, 2.0), Vector2((bar_rect.size.x - 4.0) * _health_ratio, bar_rect.size.y - 4.0)),
		HEALTH_BAR_FILL_COLOR,
		true
	)
	draw_rect(bar_rect, HEALTH_BAR_BORDER_COLOR, false, 2.0)
