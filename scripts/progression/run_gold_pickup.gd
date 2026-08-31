class_name RunGoldPickup
extends Area2D

signal collected(pickup: RunGoldPickup, amount: int)

var pickup_id := ""
var amount := 1
var _animation_phase := 0.0
var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_animation_phase = fmod(_animation_phase + delta * 3.2, TAU)
	queue_redraw()


func configure(new_pickup_id: String, new_amount: int) -> void:
	pickup_id = new_pickup_id
	amount = maxi(new_amount, 1)
	queue_redraw()


func get_combat_snapshot() -> Dictionary:
	return {
		"pickup_id": pickup_id,
		"amount": amount,
		"position": {"x": global_position.x, "y": global_position.y},
	}


func _draw() -> void:
	var bob := Vector2(0.0, sin(_animation_phase) * 5.0)
	var pulse := 1.0 + sin(_animation_phase * 2.0) * 0.06
	draw_circle(bob, 25.0 * pulse, Color(1.0, 0.72, 0.08, 0.16))
	draw_circle(bob, 17.0 * pulse, Color(1.0, 0.75, 0.08, 1.0))
	draw_arc(bob, 17.0 * pulse, 0.0, TAU, 32, Color(1.0, 0.94, 0.48, 1.0), 3.0)
	draw_circle(bob + Vector2(-5.0, -5.0), 3.5, Color(1.0, 1.0, 0.78, 0.95))
	draw_line(bob + Vector2(-24.0, 0.0), bob + Vector2(-34.0, 0.0), Color(1.0, 0.88, 0.3, 0.8), 2.0)
	draw_line(bob + Vector2(24.0, 0.0), bob + Vector2(34.0, 0.0), Color(1.0, 0.88, 0.3, 0.8), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		bob + Vector2(-10.0, 6.0),
		str(amount),
		HORIZONTAL_ALIGNMENT_CENTER,
		20.0,
		16,
		Color(0.28, 0.16, 0.02, 1.0)
	)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body is KingController:
		return
	var collecting_king := body as KingController
	if not collecting_king.is_combat_alive():
		return
	var reward_grant_service := get_node_or_null("/root/RewardGrantService")
	if reward_grant_service == null:
		return
	var granted := int(reward_grant_service.grant_run_gold(
		amount,
		{
			"source_kind": "pickup",
			"source_id": pickup_id,
			"reward_kind": "run_gold",
		}
	))
	if granted <= 0:
		return
	_collected = true
	set_deferred("monitoring", false)
	collected.emit(self, granted)
	queue_free()
