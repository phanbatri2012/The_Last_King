class_name BossController
extends GoblinController

signal boss_add_requested(request: Dictionary)

const STATE_INTRO := "intro"
const STATE_CHASE := "chase"
const STATE_TELEGRAPH := "telegraph"
const STATE_EXECUTE := "execute"
const STATE_RECOVERY := "recovery"

var boss_id: StringName = &"boss_goblin_brute"
var boss_tier := 1
var signature_skill_id: StringName = &"hammerfall"
var reward_data: Dictionary = {}
var boss_config: Dictionary = {}
var ascendant_cycle := 0

var _boss_target: Node2D
var _signature_config: Dictionary = {}
var _signature_state := STATE_INTRO
var _state_timer := 0.9
var _state_duration := 0.9
var _signature_cooldown := 3.5
var _cooldown_multiplier := 1.0
var _telegraph_multiplier := 1.0
var _enhanced_hp_threshold := 0.5
var _signature_enhanced := false
var _effect_elapsed := 0.0
var _effect_step := -1
var _effect_tick := 0.0
var _hazards: Array[Dictionary] = []
var _lanes: Array[Dictionary] = []
var _stagger_value := 0.0
var _stagger_max := 100.0
var _display_name := ""
var _visual_phase := 0.0


func _ready() -> void:
	super._ready()
	health.health_changed.connect(_on_boss_health_changed)


func configure_boss(
	new_boss_config: Dictionary,
	base_enemy_config: Dictionary,
	new_instance_id: String,
	display_name: String,
	runtime: Dictionary = {},
	restored_snapshot: Dictionary = {}
) -> void:
	boss_config = new_boss_config.duplicate(true)
	boss_id = StringName(str(boss_config.get("id", boss_id)))
	boss_tier = maxi(int(boss_config.get("tier", 1)), 1)
	signature_skill_id = StringName(str(boss_config.get("signature_skill_id", "hammerfall")))
	_signature_config = boss_config.get("signature", {}).duplicate(true)
	reward_data = boss_config.get("rewards", {}).duplicate(true)
	ascendant_cycle = maxi(int(runtime.get("ascendant_cycle", 0)), 0)
	_cooldown_multiplier = clampf(float(restored_snapshot.get("cooldown_multiplier", runtime.get("cooldown_multiplier", 1.0))), 0.2, 1.0)
	_telegraph_multiplier = clampf(float(restored_snapshot.get("telegraph_multiplier", runtime.get("telegraph_multiplier", 1.0))), 0.65, 1.0)
	_enhanced_hp_threshold = clampf(float(restored_snapshot.get("enhanced_hp_threshold", runtime.get("enhanced_hp_threshold", 0.5))), 0.1, 0.9)
	_display_name = display_name

	var scaled_config := base_enemy_config.duplicate(true)
	scaled_config["id"] = str(boss_id)
	scaled_config["name_key"] = str(boss_config.get("name_key", ""))
	scaled_config["ability"] = {"kind": "boss"}
	var health_data: Dictionary = scaled_config.get("health", {})
	health_data["max"] = float(boss_config.get("base_hp", 600.0)) * float(boss_config.get("hp_multiplier", 1.0))
	scaled_config["health"] = health_data
	var attack_data: Dictionary = scaled_config.get("attack", {})
	attack_data["damage"] = float(boss_config.get("base_damage", 18.0)) * float(boss_config.get("damage_multiplier", 1.0))
	scaled_config["attack"] = attack_data
	var presentation: Dictionary = scaled_config.get("presentation", {}).duplicate(true)
	presentation["elite_rank"] = boss_tier
	presentation["scale"] = 1.0
	scaled_config["presentation"] = presentation
	var boss_runtime := {
		"hp_multiplier": maxf(float(runtime.get("hp_multiplier", 1.0)), 0.01),
		"damage_multiplier": maxf(float(runtime.get("damage_multiplier", 1.0)), 0.01),
		"speed_multiplier": 1.0,
		"defense_multiplier": 1.0 + float(boss_tier - 1) * 0.08,
		"elite_rank": boss_tier,
		"ascendant_cycle": ascendant_cycle,
	}
	var restored_health := float(restored_snapshot.get("health", -1.0))
	var restored_engaged := bool(restored_snapshot.get("engaged", true))
	super.configure(scaled_config, new_instance_id, restored_health, restored_engaged, boss_runtime)
	enemy_id = boss_id
	name_key = str(boss_config.get("name_key", name_key))
	_stagger_max = 100.0 * maxf(float(boss_config.get("stagger_resistance", 1.0)), 0.2)
	_stagger_value = clampf(float(restored_snapshot.get("stagger_value", 0.0)), 0.0, _stagger_max)
	_signature_state = str(restored_snapshot.get("signature_state", STATE_INTRO))
	_state_timer = maxf(float(restored_snapshot.get("state_timer", 0.9)), 0.0)
	_state_duration = maxf(float(restored_snapshot.get("state_duration", _state_timer)), 0.01)
	_signature_cooldown = maxf(float(restored_snapshot.get("signature_cooldown", 3.5)), 0.0)
	_effect_elapsed = maxf(float(restored_snapshot.get("effect_elapsed", 0.0)), 0.0)
	_effect_step = int(restored_snapshot.get("effect_step", -1))
	_effect_tick = maxf(float(restored_snapshot.get("effect_tick", 0.0)), 0.0)
	_signature_enhanced = bool(restored_snapshot.get("signature_enhanced", false))
	visual.set_boss_identity(display_name, 1.32 + minf(float(boss_tier) * 0.025, 0.26))
	visual.set_stagger_ratio(_stagger_value / _stagger_max)
	if _signature_state in [STATE_TELEGRAPH, STATE_EXECUTE]:
		_prepare_signature_geometry()


func set_target(new_target: Node2D) -> void:
	_boss_target = new_target
	super.set_target(new_target)


func _physics_process(delta: float) -> void:
	_visual_phase = fmod(_visual_phase + delta * 4.2, TAU)
	if not is_combat_alive():
		_stop_moving()
		return
	queue_redraw()
	if _signature_state == STATE_CHASE:
		_signature_cooldown = maxf(_signature_cooldown - delta, 0.0)
		super._physics_process(delta)
		if _signature_cooldown <= 0.0 and _combat_enabled:
			_begin_signature()
		return
	_stop_moving()
	_state_timer = maxf(_state_timer - delta, 0.0)
	match _signature_state:
		STATE_INTRO:
			if _state_timer <= 0.0:
				_enter_chase()
		STATE_TELEGRAPH:
			if _state_timer <= 0.0:
				_execute_signature()
		STATE_EXECUTE:
			_update_signature_effect(delta)
			if _state_timer <= 0.0:
				_enter_recovery()
		STATE_RECOVERY:
			if _state_timer <= 0.0:
				_enter_chase()


func get_combat_snapshot() -> Dictionary:
	var snapshot := super.get_combat_snapshot()
	snapshot["is_boss"] = true
	snapshot["boss_id"] = str(boss_id)
	snapshot["boss_tier"] = boss_tier
	snapshot["ascendant_cycle"] = ascendant_cycle
	snapshot["signature_state"] = _signature_state
	snapshot["state_timer"] = _state_timer
	snapshot["state_duration"] = _state_duration
	snapshot["signature_cooldown"] = _signature_cooldown
	snapshot["effect_elapsed"] = _effect_elapsed
	snapshot["effect_step"] = _effect_step
	snapshot["effect_tick"] = _effect_tick
	snapshot["signature_enhanced"] = _signature_enhanced
	snapshot["stagger_value"] = _stagger_value
	snapshot["cooldown_multiplier"] = _cooldown_multiplier
	snapshot["telegraph_multiplier"] = _telegraph_multiplier
	snapshot["enhanced_hp_threshold"] = _enhanced_hp_threshold
	return snapshot


func get_signature_state() -> StringName:
	return StringName(_signature_state)


func is_signature_enhanced() -> bool:
	return _signature_enhanced


func refresh_display_name(display_name: String) -> void:
	_display_name = display_name
	visual.set_boss_identity(display_name, 1.32 + minf(float(boss_tier) * 0.025, 0.26))


func _begin_signature() -> void:
	_signature_enhanced = health.get_ratio() <= _enhanced_hp_threshold
	_signature_state = STATE_TELEGRAPH
	_state_duration = maxf(float(_signature_config.get("telegraph_duration", 1.0)) * _telegraph_multiplier, 0.45)
	_state_timer = _state_duration
	_effect_elapsed = 0.0
	_effect_step = -1
	_effect_tick = 0.0
	_cancel_pending_attack()
	_prepare_signature_geometry()


func _prepare_signature_geometry() -> void:
	_hazards.clear()
	_lanes.clear()
	var parameters := _get_effect_parameters()
	var center := _boss_target.global_position if is_instance_valid(_boss_target) else global_position
	match str(signature_skill_id):
		"hammerfall":
			var radius := float(parameters.get("radius", 165.0))
			if _signature_enhanced:
				radius *= float(parameters.get("radius_multiplier", 1.2))
			_hazards.append({"position": global_position, "radius": radius})
		"chain_detonation":
			_add_orbit_hazards(center, int(parameters.get("count", 6)), float(parameters.get("orbit_radius", 205.0)), float(parameters.get("radius", 82.0)))
		"war_banner":
			var radius := float(parameters.get("radius", 280.0))
			if _signature_enhanced:
				radius *= float(parameters.get("radius_multiplier", 1.25))
			_hazards.append({"position": global_position, "radius": radius})
		"kings_hunt":
			var direction := global_position.direction_to(center)
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			var charge_count := int(parameters.get("charge_count", 3))
			for index in charge_count:
				var rotated := direction.rotated(deg_to_rad(float(index - 1) * 24.0))
				_lanes.append({"origin": global_position, "direction": rotated, "length": float(parameters.get("charge_distance", 480.0)), "width": float(parameters.get("lane_width", 90.0))})
		"pack_release":
			_add_orbit_hazards(center, int(parameters.get("add_count", 4)), float(parameters.get("radius", 330.0)), 38.0)
		"hex_totems", "blood_moon_ritual":
			_add_orbit_hazards(center, int(parameters.get("count", 3)), float(parameters.get("orbit_radius", 220.0)), float(parameters.get("radius", 110.0)))
		"rolling_fortress":
			var direction := global_position.direction_to(center)
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			_lanes.append({"origin": global_position, "direction": direction, "length": float(parameters.get("charge_distance", 720.0)), "width": float(parameters.get("lane_width", 145.0))})
			if _signature_enhanced and bool(parameters.get("second_charge", false)):
				_lanes.append({"origin": center - direction.rotated(PI * 0.5) * 360.0, "direction": direction.rotated(PI * 0.5), "length": float(parameters.get("charge_distance", 720.0)), "width": float(parameters.get("lane_width", 145.0))})
		"imperial_encirclement", "last_dominion":
			_hazards.append({"position": center, "radius": float(parameters.get("start_radius", parameters.get("outer_radius", 520.0)))})
		"hellgate":
			_add_orbit_hazards(center, int(parameters.get("portal_count", 2)), 260.0, float(parameters.get("radius", 105.0)))
		"worldbreaker":
			var direction := global_position.direction_to(center)
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			var side := Vector2(-direction.y, direction.x)
			var line_count := int(parameters.get("line_count", 3))
			var spacing := float(parameters.get("line_spacing", 170.0))
			for index in line_count:
				var offset := (float(index) - float(line_count - 1) * 0.5) * spacing
				_lanes.append({"origin": center - direction * 450.0 + side * offset, "direction": direction, "length": 900.0, "width": float(parameters.get("lane_width", 82.0))})


func _execute_signature() -> void:
	_signature_state = STATE_EXECUTE
	var duration_multiplier := float(_get_effect_parameters().get("duration_multiplier", 1.0)) if _signature_enhanced else 1.0
	_state_duration = maxf(float(_signature_config.get("effect_duration", 1.0)) * duration_multiplier, 0.1)
	_state_timer = _state_duration
	_effect_elapsed = 0.0
	_effect_step = -1
	_effect_tick = 0.0
	match str(signature_skill_id):
		"hammerfall":
			_apply_circle_damage(global_position, float(_hazards[0].get("radius", 165.0)), float(_get_effect_parameters().get("damage_multiplier", 1.65)))
		"pack_release":
			_spawn_adds("goblin_wolf_rider", int(_get_effect_parameters().get("add_count", 4)))
		"war_banner":
			if _signature_enhanced:
				_spawn_adds("goblin", int(_get_effect_parameters().get("add_count", 5)))
		"imperial_encirclement":
			_spawn_adds("goblin_royal_guard", int(_get_effect_parameters().get("add_count", 4)))
		"hellgate":
			_spawn_adds("goblin_demonized", int(_get_effect_parameters().get("add_count", 6)))


func _update_signature_effect(delta: float) -> void:
	_effect_elapsed += delta
	_effect_tick = maxf(_effect_tick - delta, 0.0)
	var parameters := _get_effect_parameters()
	match str(signature_skill_id):
		"chain_detonation":
			var step := mini(floori(_effect_elapsed / maxf(_state_duration / float(maxi(_hazards.size(), 1)), 0.05)), _hazards.size() - 1)
			if step > _effect_step and step >= 0:
				_effect_step = step
				var hazard: Dictionary = _hazards[step]
				_apply_circle_damage(hazard.get("position", global_position), float(hazard.get("radius", 82.0)), float(parameters.get("damage_multiplier", 1.25)))
		"war_banner":
			if _effect_tick <= 0.0:
				_effect_tick = 0.55
				var radius := float(_hazards[0].get("radius", 280.0))
				for enemy_node in get_tree().get_nodes_in_group("combat_enemies"):
					var ally := enemy_node as GoblinController
					if is_instance_valid(ally) and ally != self and ally.is_combat_alive() and global_position.distance_squared_to(ally.global_position) <= radius * radius:
						ally.apply_temporary_haste(float(parameters.get("move_speed_multiplier", 1.2)), float(parameters.get("attack_speed_multiplier", 1.3)), 0.8)
		"kings_hunt":
			_update_lane_steps(parameters, int(parameters.get("charge_count", 3)), true)
		"hex_totems":
			if _effect_tick <= 0.0:
				_effect_tick = 0.7
				for hazard in _hazards:
					_apply_circle_damage(hazard.get("position", global_position), float(hazard.get("radius", 105.0)), float(parameters.get("damage_multiplier", 0.28)))
				if _signature_enhanced:
					for index in _hazards.size():
						var next := (index + 1) % _hazards.size()
						_apply_line_damage(_hazards[index].get("position", global_position), _hazards[next].get("position", global_position), 32.0, float(parameters.get("beam_damage_multiplier", 0.22)))
		"rolling_fortress":
			_update_lane_steps(parameters, _lanes.size(), true)
		"blood_moon_ritual":
			if _state_timer <= delta and _effect_step < 0:
				_effect_step = 0
				for hazard in _hazards:
					_apply_circle_damage(hazard.get("position", global_position), float(hazard.get("radius", 125.0)), float(parameters.get("damage_multiplier", 1.35)))
		"imperial_encirclement":
			if _effect_tick <= 0.0:
				_effect_tick = 0.65
				var progress := clampf(_effect_elapsed / _state_duration, 0.0, 1.0)
				var radius := lerpf(float(parameters.get("start_radius", 360.0)), float(parameters.get("end_radius", 110.0)), progress)
				_apply_ring_damage(_hazards[0].get("position", global_position), radius, 54.0, float(parameters.get("damage_multiplier", 0.42)))
		"hellgate":
			if _effect_tick <= 0.0:
				_effect_tick = 0.75 * (float(parameters.get("tick_multiplier", 1.0)) if _signature_enhanced else 1.0)
				for index in _hazards.size():
					var next := (index + 1) % _hazards.size()
					_apply_line_damage(_hazards[index].get("position", global_position), _hazards[next].get("position", global_position), float(parameters.get("beam_width", 70.0)), float(parameters.get("damage_multiplier", 0.35)))
		"worldbreaker":
			_update_lane_steps(parameters, _lanes.size(), false)
		"last_dominion":
			if _effect_tick <= 0.0:
				_effect_tick = 0.55
				var progress := clampf(_effect_elapsed / _state_duration, 0.0, 1.0)
				var wave := progress * 2.0 if progress <= 0.5 else (1.0 - progress) * 2.0
				var safe_radius := lerpf(float(parameters.get("outer_radius", 520.0)), float(parameters.get("inner_radius", 120.0)), wave)
				_apply_outside_safe_ring_damage(_hazards[0].get("position", global_position), safe_radius, float(parameters.get("safe_band_width", 90.0)), float(parameters.get("damage_multiplier", 0.42)))


func _update_lane_steps(parameters: Dictionary, step_count: int, move_boss: bool) -> void:
	if step_count <= 0 or _lanes.is_empty():
		return
	var step := mini(floori(_effect_elapsed / maxf(_state_duration / float(step_count), 0.05)), step_count - 1)
	if step <= _effect_step or step < 0:
		return
	_effect_step = step
	var lane: Dictionary = _lanes[mini(step, _lanes.size() - 1)]
	var origin: Vector2 = lane.get("origin", global_position)
	var direction: Vector2 = lane.get("direction", Vector2.RIGHT)
	var end := origin + direction * float(lane.get("length", 500.0))
	_apply_line_damage(origin, end, float(lane.get("width", 90.0)), float(parameters.get("damage_multiplier", 1.4)))
	if move_boss:
		global_position = end


func _enter_recovery() -> void:
	_signature_state = STATE_RECOVERY
	_state_duration = maxf(float(_signature_config.get("recovery_duration", 1.5)), 0.3)
	_state_timer = _state_duration
	_hazards.clear()
	_lanes.clear()


func _enter_chase() -> void:
	_signature_state = STATE_CHASE
	_signature_cooldown = maxf(float(_signature_config.get("cooldown", 10.0)) * _cooldown_multiplier, 1.0)
	_state_timer = 0.0
	_state_duration = 1.0
	_hazards.clear()
	_lanes.clear()


func _on_boss_health_changed(_current: float, _maximum: float, delta: float, _context: Dictionary) -> void:
	if delta >= 0.0 or not is_combat_alive() or _signature_state == STATE_RECOVERY:
		return
	_stagger_value = minf(_stagger_value + absf(delta), _stagger_max)
	visual.set_stagger_ratio(_stagger_value / _stagger_max)
	if _stagger_value + 0.001 < _stagger_max:
		return
	_stagger_value = 0.0
	visual.set_stagger_ratio(0.0)
	_signature_state = STATE_RECOVERY
	_state_duration = 1.25
	_state_timer = _state_duration
	_signature_cooldown = maxf(_signature_cooldown, 2.0)
	_hazards.clear()
	_lanes.clear()


func _get_effect_parameters() -> Dictionary:
	var parameters: Dictionary = _signature_config.get("effect_parameters", {}).duplicate(true)
	if _signature_enhanced:
		parameters.merge(_signature_config.get("enhanced_parameters", {}), true)
	return parameters


func _add_orbit_hazards(center: Vector2, count: int, orbit_radius: float, hazard_radius: float) -> void:
	for index in maxi(count, 1):
		var angle := TAU * float(index) / float(maxi(count, 1))
		_hazards.append({"position": center + Vector2.from_angle(angle) * orbit_radius, "radius": hazard_radius})


func _spawn_adds(add_enemy_id: String, count: int) -> void:
	for index in maxi(count, 0):
		var angle := TAU * float(index) / float(maxi(count, 1))
		boss_add_requested.emit({
			"enemy_id": add_enemy_id,
			"position": global_position + Vector2.from_angle(angle) * 180.0,
			"runtime_modifiers": {
				"hp_multiplier": 1.0 + float(boss_tier) * 0.08,
				"damage_multiplier": 1.0 + float(boss_tier) * 0.05,
				"speed_multiplier": 1.0,
				"defense_multiplier": 1.0,
				"elite_rank": 1,
			},
		})


func _apply_circle_damage(center: Vector2, radius: float, damage_multiplier: float) -> void:
	for ally_node in get_tree().get_nodes_in_group("combat_allies"):
		var ally := ally_node as Node2D
		if not _is_target_alive(ally) or center.distance_squared_to(ally.global_position) > radius * radius:
			continue
		_apply_signature_damage(ally, damage_multiplier)


func _apply_line_damage(start: Vector2, end: Vector2, width: float, damage_multiplier: float) -> void:
	for ally_node in get_tree().get_nodes_in_group("combat_allies"):
		var ally := ally_node as Node2D
		if not _is_target_alive(ally):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(ally.global_position, start, end)
		if closest.distance_squared_to(ally.global_position) <= width * width * 0.25:
			_apply_signature_damage(ally, damage_multiplier)


func _apply_ring_damage(center: Vector2, radius: float, band_width: float, damage_multiplier: float) -> void:
	for ally_node in get_tree().get_nodes_in_group("combat_allies"):
		var ally := ally_node as Node2D
		if _is_target_alive(ally) and absf(center.distance_to(ally.global_position) - radius) <= band_width:
			_apply_signature_damage(ally, damage_multiplier)


func _apply_outside_safe_ring_damage(center: Vector2, safe_radius: float, safe_band_width: float, damage_multiplier: float) -> void:
	for ally_node in get_tree().get_nodes_in_group("combat_allies"):
		var ally := ally_node as Node2D
		if not _is_target_alive(ally):
			continue
		if absf(center.distance_to(ally.global_position) - safe_radius) > safe_band_width * 0.5:
			_apply_signature_damage(ally, damage_multiplier)


func _apply_signature_damage(target: Node2D, damage_multiplier: float) -> void:
	DamageResolver.apply_damage(
		target.get("health") as HealthComponent,
		attack_damage * maxf(damage_multiplier, 0.01),
		{
			"source_kind": "boss_signature",
			"source_id": str(signature_skill_id),
			"source_instance_id": instance_id,
			"target_kind": "unit" if target is SummonedUnitController else "king",
			"damage_type": "magic" if str(signature_skill_id) in ["hex_totems", "blood_moon_ritual", "hellgate", "last_dominion"] else "physical",
			"attack_style": "area",
		},
		target.get("defense") as DefenseComponent
	)


func _draw() -> void:
	if not is_combat_alive():
		return
	var pulse := 0.5 + sin(_visual_phase) * 0.5
	draw_arc(Vector2.ZERO, 48.0 + pulse * 5.0, 0.0, TAU, 48, Color(0.9, 0.18, 0.42, 0.34), 3.0, true)
	if _signature_state not in [STATE_TELEGRAPH, STATE_EXECUTE]:
		return
	var telegraph_progress := 1.0 - (_state_timer / _state_duration) if _signature_state == STATE_TELEGRAPH else 1.0
	var warning_color := Color(1.0, 0.12, 0.08, 0.18 + telegraph_progress * 0.24)
	var outline_color := Color(1.0, 0.34, 0.14, 0.75 + pulse * 0.2)
	if str(signature_skill_id) in ["hex_totems", "blood_moon_ritual", "hellgate", "last_dominion"]:
		warning_color = Color(0.62, 0.12, 0.82, 0.2 + telegraph_progress * 0.2)
		outline_color = Color(0.92, 0.36, 1.0, 0.9)
	for index in _hazards.size():
		var hazard: Dictionary = _hazards[index]
		var center := to_local(hazard.get("position", global_position))
		var radius := float(hazard.get("radius", 80.0))
		if str(signature_skill_id) == "imperial_encirclement" and _signature_state == STATE_EXECUTE:
			var params := _get_effect_parameters()
			radius = lerpf(float(params.get("start_radius", 360.0)), float(params.get("end_radius", 110.0)), clampf(_effect_elapsed / _state_duration, 0.0, 1.0))
		if str(signature_skill_id) == "last_dominion" and _signature_state == STATE_EXECUTE:
			var params := _get_effect_parameters()
			var progress := clampf(_effect_elapsed / _state_duration, 0.0, 1.0)
			var wave := progress * 2.0 if progress <= 0.5 else (1.0 - progress) * 2.0
			radius = lerpf(float(params.get("outer_radius", 520.0)), float(params.get("inner_radius", 120.0)), wave)
		draw_circle(center, radius, warning_color)
		draw_arc(center, radius, 0.0, TAU, 72, outline_color, 4.0, true)
		if _signature_state == STATE_TELEGRAPH:
			draw_arc(center, radius * telegraph_progress, 0.0, TAU, 56, Color(1.0, 0.86, 0.3, 0.9), 3.0, true)
	for lane in _lanes:
		var origin := to_local(lane.get("origin", global_position))
		var direction: Vector2 = lane.get("direction", Vector2.RIGHT)
		var end := origin + direction * float(lane.get("length", 500.0))
		var width := float(lane.get("width", 90.0))
		draw_line(origin, end, warning_color, width, true)
		draw_line(origin, end, outline_color, 5.0, true)
	if str(signature_skill_id) == "war_banner" and not _hazards.is_empty():
		draw_line(Vector2(0.0, 16.0), Vector2(0.0, -92.0), Color(0.32, 0.18, 0.08, 1.0), 8.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -88.0), Vector2(72.0, -68.0), Vector2(0.0, -42.0)]), Color(0.82, 0.12, 0.12, 0.88))
