class_name SummonedUnitPlaceholderVisual
extends Node2D

const HEALTH_BAR_FILL_COLOR := Color(0.24, 0.58, 0.96, 1.0)

var _facing := Vector2.RIGHT
var _moving := false
var _health_ratio := 1.0
var _step_phase := 0.0
var _attack_pulse := 0.0
var _hurt_flash := 0.0
var _heal_pulse := 0.0
var _heal_amount := 0.0
var _defeated := false
var _body_color := Color(0.19, 0.37, 0.53, 1.0)
var _accent_color := Color(0.88, 0.72, 0.28, 1.0)
var _visual_kind := "spearman"
var _visual_scale := 1.0


func _process(delta: float) -> void:
	if _moving:
		_step_phase = fmod(_step_phase + delta * 9.0, TAU)
	else:
		_step_phase = move_toward(_step_phase, 0.0, delta * 8.0)
	_attack_pulse = maxf(_attack_pulse - delta * 5.5, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 4.5, 0.0)
	_heal_pulse = maxf(_heal_pulse - delta * 1.45, 0.0)
	queue_redraw()


func configure(presentation: Dictionary) -> void:
	_body_color = Color.from_string(str(presentation.get("body_color", "")), _body_color)
	_accent_color = Color.from_string(str(presentation.get("accent_color", "")), _accent_color)
	_visual_kind = str(presentation.get("visual_kind", _visual_kind))
	_visual_scale = clampf(float(presentation.get("scale", _visual_scale)), 0.5, 2.0)
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


func get_health_ratio() -> float:
	return _health_ratio


func _draw() -> void:
	var side := Vector2(-_facing.y, _facing.x)
	var bob := sin(_step_phase) * 2.0 if _moving else 0.0
	var body_color := _body_color.lerp(Color(1.0, 0.92, 0.72, 1.0), _hurt_flash)
	if _defeated:
		body_color = body_color.darkened(0.62)
	var draw_origin := Vector2(0.0, 12.0) if _defeated else Vector2.ZERO
	var draw_rotation := 1.35 if _defeated else 0.0
	draw_set_transform(draw_origin, draw_rotation, Vector2.ONE * _visual_scale)
	if _visual_kind in ["elephant_guard", "royal_war_elephant"]:
		_draw_elephant(body_color, bob, side)
	else:
		_draw_human(body_color, bob, side)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not _defeated:
		var overhead_y := -70.0 if _visual_kind in ["elephant_guard", "royal_war_elephant"] else -42.0
		overhead_y *= _visual_scale
		if _heal_pulse > 0.0:
			var heal_progress := 1.0 - _heal_pulse
			var heal_color := Color(0.28, 1.0, 0.48, _heal_pulse)
			draw_arc(Vector2.ZERO, (30.0 + heal_progress * 12.0) * _visual_scale, 0.0, TAU, 32, heal_color, 3.0, true)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-18.0, overhead_y - 6.0 - heal_progress * 14.0),
				"+%d" % roundi(_heal_amount),
				HORIZONTAL_ALIGNMENT_CENTER,
				36.0,
				15,
				heal_color
			)
		var bar_width := 66.0 if _visual_kind in ["elephant_guard", "royal_war_elephant"] else 54.0
		var bar_rect := Rect2(-bar_width * 0.5, overhead_y, bar_width, 7.0)
		draw_rect(bar_rect, Color(0.04, 0.04, 0.05, 0.88), true)
		draw_rect(
			Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_rect.size.x - 2.0) * _health_ratio, bar_rect.size.y - 2.0)),
			HEALTH_BAR_FILL_COLOR,
			true
		)


func _draw_human(body_color: Color, bob: float, side: Vector2) -> void:
	draw_set_transform(Vector2(0.0, 21.0), 0.0, Vector2(1.18, 0.34))
	draw_circle(Vector2.ZERO, 19.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _visual_scale)
	draw_circle(Vector2(0.0, bob + 3.0), 20.0, body_color)
	draw_arc(Vector2(0.0, bob + 3.0), 20.0, 0.0, TAU, 32, body_color.darkened(0.5), 3.0, true)
	draw_arc(Vector2(0.0, bob - 3.0), 17.0, PI, TAU, 18, _accent_color, 6.0, true)
	draw_circle(Vector2(0.0, bob - 5.0), 13.0, Color(0.78, 0.55, 0.34, 1.0))
	draw_circle(Vector2(0.0, bob - 10.0), 14.0, _accent_color.darkened(0.22))
	draw_rect(Rect2(Vector2(-14.0, bob - 11.0), Vector2(28.0, 5.0)), _accent_color, true)
	draw_circle(Vector2(0.0, bob - 22.0), 3.0, _accent_color)
	_draw_human_weapon(side)


func _draw_human_weapon(side: Vector2) -> void:
	var wood := Color(0.46, 0.27, 0.12, 1.0)
	var metal := Color(0.82, 0.88, 0.91, 1.0)
	if _visual_kind == "crossbowman":
		var crossbow_center := _facing * (24.0 + _attack_pulse * 7.0) + side * 9.0
		draw_line(crossbow_center - _facing * 20.0, crossbow_center + _facing * 20.0, wood, 5.0, true)
		draw_line(crossbow_center - side * 17.0, crossbow_center + side * 17.0, metal, 4.0, true)
		draw_line(crossbow_center - side * 17.0, crossbow_center + _facing * 8.0, Color(0.9, 0.82, 0.55, 1.0), 2.0, true)
		draw_line(crossbow_center + side * 17.0, crossbow_center + _facing * 8.0, Color(0.9, 0.82, 0.55, 1.0), 2.0, true)
		return
	if _visual_kind == "ambush_archer":
		var bow_center := _facing * 22.0 + side * 10.0
		var bow_forward := bow_center + _facing * (11.0 + _attack_pulse * 8.0)
		draw_line(bow_center - side * 22.0, bow_forward, wood, 4.0, true)
		draw_line(bow_forward, bow_center + side * 22.0, wood, 4.0, true)
		draw_line(bow_center - side * 22.0, bow_center + side * 22.0, Color(0.86, 0.82, 0.66, 1.0), 1.5, true)
		draw_line(bow_center - _facing * 8.0, bow_center + _facing * 26.0, metal, 2.0, true)
		return
	if _visual_kind == "royal_guard":
		var shield_center := -side * 15.0 + _facing * 6.0
		draw_circle(shield_center, 14.0, _accent_color.darkened(0.18))
		draw_arc(shield_center, 14.0, 0.0, TAU, 24, metal, 3.0, true)
		draw_line(shield_center - Vector2(7.0, 0.0), shield_center + Vector2(7.0, 0.0), _accent_color.lightened(0.25), 3.0, true)
		_draw_blade(side * 12.0, 38.0 + _attack_pulse * 13.0, 7.0)
		return
	if _visual_kind == "raider":
		_draw_blade(side * 12.0, 33.0 + _attack_pulse * 15.0, 9.0)
		_draw_blade(-side * 12.0, 28.0 + _attack_pulse * 10.0, 7.0)
		return
	var spear_start := -_facing * 21.0 + side * 10.0
	var spear_end := _facing * (49.0 + _attack_pulse * 19.0) + side * 10.0
	draw_line(spear_start, spear_end, wood, 5.0, true)
	var spear_tip := spear_end + _facing * 13.0
	draw_colored_polygon(PackedVector2Array([spear_end + side * 6.0, spear_tip, spear_end - side * 6.0]), metal)


func _draw_blade(side_offset: Vector2, length: float, width: float) -> void:
	var handle_start := -_facing * 11.0 + side_offset
	var blade_start := handle_start + _facing * 12.0
	var blade_end := blade_start + _facing * length
	draw_line(handle_start, blade_start, Color(0.37, 0.2, 0.1, 1.0), 5.0, true)
	draw_line(blade_start, blade_end, Color(0.86, 0.9, 0.92, 1.0), width, true)
	draw_line(blade_start - Vector2(-_facing.y, _facing.x) * 7.0, blade_start + Vector2(-_facing.y, _facing.x) * 7.0, _accent_color, 3.0, true)


func _draw_elephant(body_color: Color, bob: float, side: Vector2) -> void:
	draw_set_transform(Vector2(0.0, 28.0), 0.0, Vector2(1.45, 0.4) * _visual_scale)
	draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _visual_scale)
	var elephant_color := body_color.lightened(0.16)
	var head_center := _facing * 25.0 + Vector2(0.0, bob + 3.0)
	draw_circle(Vector2(0.0, bob + 5.0), 28.0, elephant_color)
	draw_circle(head_center, 19.0, elephant_color.lightened(0.06))
	draw_circle(head_center + side * 13.0, 12.0, elephant_color.darkened(0.08))
	draw_circle(head_center - side * 13.0, 12.0, elephant_color.darkened(0.08))
	var trunk_end := head_center + _facing * (29.0 + _attack_pulse * 13.0) + Vector2(0.0, 9.0)
	draw_line(head_center + _facing * 10.0, trunk_end, elephant_color.darkened(0.08), 12.0, true)
	draw_line(Vector2(-17.0, bob + 20.0), Vector2(-17.0, bob + 39.0), elephant_color.darkened(0.15), 12.0, true)
	draw_line(Vector2(17.0, bob + 20.0), Vector2(17.0, bob + 39.0), elephant_color.darkened(0.15), 12.0, true)
	draw_line(head_center + side * 8.0 + _facing * 8.0, head_center + side * 8.0 + _facing * 24.0, Color(0.96, 0.92, 0.75, 1.0), 4.0, true)
	draw_line(head_center - side * 8.0 + _facing * 8.0, head_center - side * 8.0 + _facing * 24.0, Color(0.96, 0.92, 0.75, 1.0), 4.0, true)
	draw_rect(Rect2(-25.0, bob - 12.0, 50.0, 25.0), _accent_color.darkened(0.22), true)
	draw_rect(Rect2(-21.0, bob - 28.0, 42.0, 17.0), _accent_color, true)
	draw_circle(Vector2(0.0, bob - 36.0), 10.0, Color(0.78, 0.55, 0.34, 1.0))
	draw_circle(Vector2(0.0, bob - 43.0), 11.0, _accent_color.darkened(0.26))
	if _visual_kind == "royal_war_elephant":
		draw_arc(Vector2(0.0, bob - 20.0), 25.0, PI, TAU, 20, Color(0.97, 0.79, 0.24, 1.0), 4.0, true)
