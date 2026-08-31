extends Node

signal session_started(session: BattleSession)
signal session_ended(result: Dictionary)

var active_session: BattleSession
var pause_manager := PauseManager.new()
var game_clock := GameClock.new()
var _initialized := false


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
	active_session.king_state = {
		"position": {"x": position.x, "y": position.y},
		"velocity": {"x": current_velocity.x, "y": current_velocity.y},
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


func _on_pause_state_changed(paused: bool) -> void:
	game_clock.paused = paused
	if active_session != null:
		active_session.pause_state = {"reasons": pause_manager.get_reasons()}


func _on_host_pause_requested() -> void:
	pause_manager.request_pause(PauseManager.PLATFORM)


func _on_host_resume_requested() -> void:
	pause_manager.clear_pause(PauseManager.PLATFORM)
