class_name HealingResolver
extends RefCounted


static func apply_healing(
	target: HealthComponent,
	requested_healing: float,
	context: Dictionary = {}
) -> Dictionary:
	var result := {
		"requested": maxf(requested_healing, 0.0),
		"applied": 0.0,
		"remaining_health": 0.0,
		"accepted": false,
	}
	if target == null or requested_healing <= 0.0 or not target.is_alive():
		if target != null:
			result["remaining_health"] = target.current_health
		return result
	var applied := target.apply_resolved_healing(requested_healing, context)
	result["applied"] = applied
	result["remaining_health"] = target.current_health
	result["accepted"] = applied > 0.0
	return result
