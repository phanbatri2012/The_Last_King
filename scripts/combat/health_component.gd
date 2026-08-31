class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float, delta: float, context: Dictionary)
signal died(context: Dictionary)

@export_range(1.0, 1000000.0, 1.0) var max_health := 100.0

var current_health := 100.0
var alive := true
var _configured := false


func _ready() -> void:
	if not _configured:
		configure(max_health)


func configure(new_max_health: float, restored_health: float = -1.0) -> void:
	max_health = maxf(new_max_health, 1.0)
	current_health = max_health if restored_health < 0.0 else clampf(restored_health, 0.0, max_health)
	alive = current_health > 0.0
	_configured = true
	health_changed.emit(current_health, max_health, 0.0, {})


func is_alive() -> bool:
	return alive


func get_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


# DamageResolver is the only gameplay system that should call this method.
func apply_resolved_damage(amount: float, context: Dictionary) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health, -applied, context.duplicate(true))
	if current_health <= 0.0:
		current_health = 0.0
		alive = false
		died.emit(context.duplicate(true))
	return applied
