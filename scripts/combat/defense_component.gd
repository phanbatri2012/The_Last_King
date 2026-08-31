class_name DefenseComponent
extends Node

@export_range(0.0, 10000.0, 1.0) var armor := 0.0
@export_range(0.0, 10000.0, 1.0) var magic_resistance := 0.0


func configure(config: Dictionary) -> void:
	armor = maxf(float(config.get("armor", armor)), 0.0)
	magic_resistance = maxf(float(config.get("magic_resistance", magic_resistance)), 0.0)


func mitigate(requested_damage: float, damage_type: String) -> float:
	if requested_damage <= 0.0:
		return 0.0
	var resistance := magic_resistance if damage_type == "magic" else armor
	return maxf(requested_damage - resistance, minf(requested_damage, 1.0))
