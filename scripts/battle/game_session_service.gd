extends Node

signal session_started(session: BattleSession)
signal session_ended(result: Dictionary)

var active_session: BattleSession
var pause_manager := PauseManager.new()
var game_clock := GameClock.new()
var _initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func initialize() -> bool:
	if _initialized:
		return true
	pause_manager.pause_state_changed.connect(_on_pause_state_changed)
	PlatformService.host_pause_requested.connect(_on_host_pause_requested)
	PlatformService.host_resume_requested.connect(_on_host_resume_requested)
	_initialized = true
	return true


func has_active_session() -> bool:
	return active_session != null


func start_session(king_id: StringName, faction_id: StringName, seed: int) -> BattleSession:
	pause_manager.clear_pause(PauseManager.LEVEL_UP)
	active_session = BattleSession.new()
	active_session.create(king_id, faction_id, seed)
	game_clock.reset()
	session_started.emit(active_session)
	GameEventBus.battle_started.emit(active_session.session_id)
	return active_session


func end_session(result: Dictionary) -> void:
	if active_session == null:
		return
	var ended_session_id := active_session.session_id
	pause_manager.clear_pause(PauseManager.LEVEL_UP)
	active_session = null
	game_clock.reset()
	session_ended.emit(result)
	GameEventBus.battle_finished.emit(ended_session_id, result)


func advance(delta: float) -> void:
	if active_session == null:
		return
	game_clock.advance(delta)
	active_session.elapsed_time = game_clock.elapsed_time


func set_king_movement_state(position: Vector2, current_velocity: Vector2) -> void:
	if active_session == null:
		return
	active_session.king_state["position"] = {"x": position.x, "y": position.y}
	active_session.king_state["velocity"] = {"x": current_velocity.x, "y": current_velocity.y}


func set_king_health_state(current_health: float, max_health: float) -> void:
	if active_session == null:
		return
	active_session.king_state["health"] = {
		"current": current_health,
		"max": max_health,
	}


func get_king_position(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if active_session == null:
		return fallback
	var position_value: Variant = active_session.king_state.get("position", {})
	if not position_value is Dictionary:
		return fallback
	var position_data: Dictionary = position_value
	return Vector2(
		float(position_data.get("x", fallback.x)),
		float(position_data.get("y", fallback.y))
	)


func get_king_health(fallback: float) -> float:
	if active_session == null:
		return fallback
	var health_value: Variant = active_session.king_state.get("health", {})
	if not health_value is Dictionary:
		return fallback
	var health_data: Dictionary = health_value
	var current := float(health_data.get("current", fallback))
	return fallback if current < 0.0 else current


func set_enemy_combat_state(
	living_enemies: Array[Dictionary],
	spawn_runtime_state: Dictionary,
	gold_pickups: Array[Dictionary],
	next_pickup_serial: int,
	healing_pickups: Array[Dictionary] = [],
	drop_runtime_state: Dictionary = {}
) -> void:
	if active_session == null:
		return
	active_session.enemy_wave_state = {
		"encounter_id": "phase4_survival_projectiles",
		"living_enemies": living_enemies.duplicate(true),
		"spawn_runtime_state": spawn_runtime_state.duplicate(true),
		"gold_pickups": gold_pickups.duplicate(true),
		"healing_pickups": healing_pickups.duplicate(true),
		"next_pickup_serial": maxi(next_pickup_serial, 1),
		"drop_runtime_state": drop_runtime_state.duplicate(true),
	}


func get_enemy_combat_state() -> Dictionary:
	if active_session == null:
		return {}
	return active_session.enemy_wave_state.duplicate(true)


func set_army_state(units: Array[Dictionary]) -> void:
	if active_session == null:
		return
	active_session.army = units.duplicate(true)


func get_army_state() -> Array[Dictionary]:
	if active_session == null:
		return []
	return active_session.army.duplicate(true)


func set_army_upgrade_state(upgrade_levels: Dictionary) -> void:
	if active_session == null:
		return
	active_session.upgrades["army"] = upgrade_levels.duplicate(true)


func get_army_upgrade_state() -> Dictionary:
	if active_session == null:
		return {}
	var value: Variant = active_session.upgrades.get("army", {})
	return value.duplicate(true) if value is Dictionary else {}


func set_skill_state(skill_levels: Dictionary, rng_state: int) -> void:
	if active_session == null:
		return
	active_session.skills = skill_levels.duplicate(true)
	active_session.rng_state["king_progression"] = rng_state


func get_skill_state() -> Dictionary:
	if active_session == null:
		return {}
	return active_session.skills.duplicate(true)


func get_progression_rng_state() -> int:
	if active_session == null:
		return 0
	return int(active_session.rng_state.get("king_progression", 0))


func _on_pause_state_changed(paused: bool) -> void:
	game_clock.paused = paused
	get_tree().paused = paused
	if active_session != null:
		active_session.pause_state = {"reasons": pause_manager.get_reasons()}


func _on_host_pause_requested() -> void:
	pause_manager.request_pause(PauseManager.PLATFORM)


func _on_host_resume_requested() -> void:
	pause_manager.clear_pause(PauseManager.PLATFORM)
