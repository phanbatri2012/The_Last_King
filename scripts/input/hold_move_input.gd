class_name HoldMoveInput
extends RefCounted


static func direction_from_screen_points(
	pointer_position: Vector2,
	actor_position: Vector2,
	stop_radius: float,
	full_speed_radius: float
) -> Vector2:
	var offset := pointer_position - actor_position
	var distance := offset.length()
	var safe_stop_radius := maxf(stop_radius, 0.0)
	if distance <= safe_stop_radius or offset.is_zero_approx():
		return Vector2.ZERO
	var safe_full_speed_radius := maxf(full_speed_radius, safe_stop_radius + 1.0)
	var strength := clampf(
		(distance - safe_stop_radius) / (safe_full_speed_radius - safe_stop_radius),
		0.0,
		1.0
	)
	return offset.normalized() * strength
