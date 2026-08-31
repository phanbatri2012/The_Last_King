class_name MovementInputResolver
extends RefCounted

const ACTIVE_EPSILON_SQUARED := 0.0001


static func resolve(keyboard_direction: Vector2, virtual_direction: Vector2) -> Vector2:
	var keyboard := keyboard_direction.limit_length(1.0)
	var virtual := virtual_direction.limit_length(1.0)
	if virtual.length_squared() > ACTIVE_EPSILON_SQUARED:
		return virtual
	return keyboard


static func to_velocity(direction: Vector2, speed: float) -> Vector2:
	return direction.limit_length(1.0) * maxf(speed, 0.0)
