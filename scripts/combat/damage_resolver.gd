class_name DamageResolver
extends RefCounted


static func apply_damage(
	target: HealthComponent,
	requested_damage: float,
	context: Dictionary = {},
	defense: DefenseComponent = null
) -> Dictionary:
	var result := {
		"requested": maxf(requested_damage, 0.0),
		"mitigated": 0.0,
		"applied": 0.0,
		"remaining_health": 0.0,
		"killed": false,
		"accepted": false,
	}
	if target == null or requested_damage <= 0.0 or not target.is_alive():
		if target != null:
			result["remaining_health"] = target.current_health
		return result

	var damage_type := str(context.get("damage_type", "physical"))
	var resolved_damage := defense.mitigate(requested_damage, damage_type) if defense != null else requested_damage
	result["mitigated"] = requested_damage - resolved_damage
	var applied := target.apply_resolved_damage(resolved_damage, context)
	result["applied"] = applied
	result["remaining_health"] = target.current_health
	result["killed"] = not target.is_alive()
	result["accepted"] = applied > 0.0
	return result
