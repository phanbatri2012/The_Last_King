class_name HealingOrbPickup
extends Area2D

signal collected(pickup: HealingOrbPickup, applied_healing: float)

var pickup_id := ""
var max_health_fraction := 0.14
var _animation_phase := 0.0
var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_phase = fmod(_animation_phase + delta * 2.8, TAU)
	queue_redraw()


func configure(new_pickup_id: String, new_max_health_fraction: float) -> void:
	pickup_id = new_pickup_id
	max_health_fraction = clampf(new_max_health_fraction, 0.01, 1.0)
	queue_redraw()


func get_combat_snapshot() -> Dictionary:
	return {
		"pickup_id": pickup_id,
		"max_health_fraction": max_health_fraction,
		"position": {"x": global_position.x, "y": global_position.y},
	}


func _draw() -> void:
	var bob := Vector2(0.0, sin(_animation_phase) * 5.0)
	var pulse := 1.0 + sin(_animation_phase * 2.0) * 0.08
	var green := Color(0.22, 0.96, 0.42, 1.0)
	draw_circle(bob, 28.0 * pulse, Color(green, 0.14))
	draw_circle(bob, 18.0 * pulse, Color(0.08, 0.5, 0.2, 0.96))
	draw_arc(bob, 18.0 * pulse, 0.0, TAU, 32, Color(0.52, 1.0, 0.66, 1.0), 3.0, true)
	draw_rect(Rect2(bob + Vector2(-4.0, -12.0), Vector2(8.0, 24.0)), Color(0.82, 1.0, 0.84, 1.0), true)
	draw_rect(Rect2(bob + Vector2(-12.0, -4.0), Vector2(24.0, 8.0)), Color(0.82, 1.0, 0.84, 1.0), true)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body is KingController:
		return
	var collecting_king := body as KingController
	if not collecting_king.is_combat_alive():
		return
	var requested_healing := collecting_king.health.max_health * max_health_fraction
	var result := HealingResolver.apply_healing(
		collecting_king.health,
		requested_healing,
		{
			"source_kind": "pickup",
			"source_id": pickup_id,
			"recovery_kind": "healing_orb",
		}
	)
	if not bool(result.get("accepted", false)):
		return
	_collected = true
	set_deferred("monitoring", false)
	collected.emit(self, float(result.get("applied", 0.0)))
	queue_free()
