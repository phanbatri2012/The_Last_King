class_name CombatTargetSelector
extends RefCounted


static func nearest(origin: Vector2, candidates: Array, max_range: float) -> Node2D:
	if max_range <= 0.0:
		return null
	var nearest_target: Node2D
	var nearest_distance_squared := max_range * max_range
	for candidate_value in candidates:
		var candidate := candidate_value as Node2D
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_combat_alive") and not bool(candidate.call("is_combat_alive")):
			continue
		var distance_squared := origin.distance_squared_to(candidate.global_position)
		if distance_squared > nearest_distance_squared:
			continue
		nearest_distance_squared = distance_squared
		nearest_target = candidate
	return nearest_target
