class_name GoblinPlaceholderVisual
extends Node2D

const HEALTH_BAR_FILL_COLOR := Color(0.74, 0.16, 0.12, 1.0)
const BOSS_HEALTH_BAR_FILL_COLOR := Color(0.88, 0.18, 0.5, 1.0)

var _facing := Vector2.LEFT
var _moving := false
var _targeted := false
var _engaged := false
var _health_ratio := 1.0
var _current_health := 1.0
var _max_health := 1.0
var _step_phase := 0.0
var _attack_pulse := 0.0
var _hurt_flash := 0.0
var _defeated := false
var _visual_kind := "raider"
var _body_color := Color(0.27, 0.54, 0.2, 1.0)
var _accent_color := Color(0.52, 0.28, 0.1, 1.0)
var _elite_rank := 0
var _is_boss := false
var _boss_name := ""
var _stagger_ratio := 0.0


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
	_elite_rank = maxi(int(presentation.get("elite_rank", 0)), 0)
	var visual_scale := clampf(float(presentation.get("scale", 1.0)), 0.6, 2.0)
	scale = Vector2.ONE * visual_scale
	queue_redraw()


func set_boss_identity(display_name: String, boss_scale: float = 1.45) -> void:
	_is_boss = true
	_boss_name = display_name
	scale = Vector2.ONE * clampf(boss_scale, 1.2, 2.0)
	queue_redraw()


func set_stagger_ratio(ratio: float) -> void:
	_stagger_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func set_engaged(engaged: bool) -> void:
	_engaged = engaged
	queue_redraw()


func set_health(current_health: float, max_health: float) -> void:
	_current_health = maxf(current_health, 0.0)
	_max_health = maxf(max_health, 1.0)
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
	if _elite_rank > 0 and not _defeated:
		draw_arc(Vector2.ZERO, 31.0 + minf(float(_elite_rank), 4.0) * 2.0, 0.0, TAU, 40, Color(1.0, 0.58, 0.14, 0.4), 2.0 + minf(float(_elite_rank), 3.0), true)
	draw_set_transform(Vector2(0.0, 24.0), 0.0, Vector2(1.25, 0.38))
	draw_circle(Vector2.ZERO, 21.0, Color(0.0, 0.0, 0.0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var side := Vector2(-_facing.y, _facing.x)
	var ear_points_left := PackedVector2Array([Vector2(-15.0, -10.0), Vector2(-35.0, -20.0), Vector2(-19.0, 2.0)])
	var ear_points_right := PackedVector2Array([Vector2(15.0, -10.0), Vector2(35.0, -20.0), Vector2(19.0, 2.0)])
	draw_colored_polygon(ear_points_left, body_color.darkened(0.1))
	draw_colored_polygon(ear_points_right, body_color.darkened(0.1))
	var body_radius := 27.0 if _visual_kind in ["brute", "berserker"] else 24.0
	if _visual_kind in ["champion", "royal_guard"]:
		body_radius = 29.0
	elif _visual_kind == "demonized":
		body_radius = 28.0
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 36, body_color.darkened(0.58), 3.0, true)
	draw_circle(Vector2(-7.0, -5.0), 3.0, Color(0.96, 0.82, 0.2, 1.0))
	draw_circle(Vector2(7.0, -5.0), 3.0, Color(0.96, 0.82, 0.2, 1.0))
	draw_line(Vector2(-8.0, 10.0), Vector2(8.0, 10.0), Color(0.13, 0.07, 0.04, 1.0), 3.0, true)

	_draw_weapon(side)

	if not _defeated:
		var bar_rect := Rect2(-55.0, -58.0, 110.0, 10.0) if _is_boss else Rect2(-29.0, -42.0, 58.0, 7.0)
		draw_rect(bar_rect, Color(0.04, 0.04, 0.04, 0.88), true)
		draw_rect(Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_rect.size.x - 2.0) * _health_ratio, bar_rect.size.y - 2.0)), BOSS_HEALTH_BAR_FILL_COLOR if _is_boss else HEALTH_BAR_FILL_COLOR, true)
		if _is_boss:
			draw_string(ThemeDB.fallback_font, Vector2(-70.0, -66.0), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, Color(1.0, 0.78, 0.3, 1.0))
			draw_string(ThemeDB.fallback_font, Vector2(-55.0, -49.0), "%d/%d" % [ceili(_current_health), ceili(_max_health)], HORIZONTAL_ALIGNMENT_CENTER, 110.0, 10, Color.WHITE)
			var stagger_rect := Rect2(-45.0, -43.0, 90.0, 4.0)
			draw_rect(stagger_rect, Color(0.08, 0.08, 0.1, 0.9), true)
			draw_rect(Rect2(stagger_rect.position, Vector2(stagger_rect.size.x * _stagger_ratio, stagger_rect.size.y)), Color(1.0, 0.72, 0.16, 1.0), true)


func _draw_weapon(side: Vector2) -> void:
	var weapon_start := _facing * 10.0 + side * 18.0
	match _visual_kind:
		"brute", "berserker", "champion":
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
		"hexer", "shaman", "warlock":
			var staff_end := weapon_start + _facing * (38.0 + _attack_pulse * 8.0)
			draw_line(weapon_start, staff_end, Color(0.3, 0.16, 0.08, 1.0), 7.0, true)
			draw_circle(staff_end, 10.0 + _attack_pulse * 3.0, Color(_accent_color, 0.25))
			draw_circle(staff_end, 6.0, _accent_color)
		"shield", "royal_guard":
			var spear_end := weapon_start + _facing * (46.0 + _attack_pulse * 12.0)
			draw_line(weapon_start, spear_end, Color(0.6, 0.38, 0.16, 1.0), 6.0, true)
			draw_colored_polygon(PackedVector2Array([spear_end + _facing * 9.0, spear_end + side * 5.0, spear_end - side * 5.0]), _accent_color)
			var shield_center := -side * 22.0 + Vector2(0.0, 4.0)
			draw_circle(shield_center, 14.0, Color(0.2, 0.25, 0.26, 1.0))
			draw_arc(shield_center, 14.0, 0.0, TAU, 24, _accent_color, 4.0, true)
		"bomber":
			var bomb_center := weapon_start + _facing * (25.0 + _attack_pulse * 8.0)
			draw_circle(bomb_center, 13.0, Color(0.08, 0.08, 0.08, 1.0))
			draw_arc(bomb_center, 17.0 + _attack_pulse * 5.0, 0.0, TAU, 24, Color(1.0, 0.24, 0.1, 0.65), 3.0, true)
		"wolf_rider":
			var fang_end := weapon_start + _facing * (48.0 + _attack_pulse * 14.0)
			draw_line(weapon_start, fang_end, _accent_color, 7.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-25.0, 20.0), Vector2(-13.0, 34.0), Vector2(0.0, 22.0), Vector2(13.0, 34.0), Vector2(27.0, 18.0)]), Color(0.27, 0.3, 0.32, 1.0))
		"demonized":
			var claw_end := weapon_start + _facing * (45.0 + _attack_pulse * 18.0)
			draw_line(weapon_start, claw_end, _accent_color, 10.0, true)
			draw_circle(claw_end, 14.0 + _attack_pulse * 5.0, Color(_accent_color, 0.22))
		_:
			var club_end := weapon_start + _facing * (44.0 + _attack_pulse * 13.0)
			draw_line(weapon_start, club_end, _accent_color.darkened(0.35), 9.0, true)
			draw_circle(club_end, 9.0, _accent_color.darkened(0.5))
