class_name KingProgressionController
extends Node

signal state_changed(run_level: int, run_xp: int, xp_required: int)
signal level_up_started(choices: Array[Dictionary])
signal level_up_completed(skill_id: StringName, new_skill_level: int)

var _progression_config: Dictionary = {}
var _skill_configs: Dictionary = {}
var _skill_runtime: KingSkillRuntime
var _rng := RandomNumberGenerator.new()
var _current_choices: Array[Dictionary] = []
var _selection_pending := false


func configure(
	seed: int,
	progression_config: Dictionary,
	skill_configs: Dictionary,
	skill_runtime: KingSkillRuntime,
	restored_level: int = 1,
	restored_xp: int = 0,
	restored_skills: Dictionary = {},
	restored_rng_state: int = 0
) -> void:
	_progression_config = progression_config.duplicate(true)
	_skill_configs = skill_configs.duplicate(true)
	_skill_runtime = skill_runtime
	_rng.seed = seed ^ 0x51A7C11
	if restored_rng_state != 0:
		_rng.state = restored_rng_state
	var session_service := _get_session_service()
	if session_service != null:
		session_service.initialize()
	if session_service != null and session_service.has_active_session():
		session_service.active_session.run_level = maxi(restored_level, 1)
		session_service.active_session.run_xp = maxi(restored_xp, 0)
		session_service.set_skill_state(restored_skills, _rng.state)
	var reward_service := _get_reward_service()
	if reward_service != null and not reward_service.run_xp_granted.is_connected(_on_run_xp_granted):
		reward_service.run_xp_granted.connect(_on_run_xp_granted)
	_emit_state()
	call_deferred("_try_begin_level_up")


func get_run_level() -> int:
	var session_service := _get_session_service()
	return session_service.active_session.run_level if session_service != null and session_service.has_active_session() else 1


func get_run_xp() -> int:
	var session_service := _get_session_service()
	return session_service.active_session.run_xp if session_service != null and session_service.has_active_session() else 0


func get_xp_required() -> int:
	var level := get_run_level()
	var base_xp := maxi(int(_progression_config.get("base_xp_to_level", 24)), 1)
	var growth := maxi(int(_progression_config.get("xp_growth_per_level", 14)), 0)
	return base_xp + maxi(level - 1, 0) * growth


func is_selection_pending() -> bool:
	return _selection_pending


func get_current_choices() -> Array[Dictionary]:
	return _current_choices.duplicate(true)


func select_skill(skill_id: StringName) -> bool:
	if not _selection_pending:
		return false
	var key := str(skill_id)
	var selected_config: Dictionary = {}
	for choice in _current_choices:
		if str(choice.get("id", "")) == key:
			selected_config = choice
			break
	if selected_config.is_empty() or not is_instance_valid(_skill_runtime):
		return false
	var current_level := _skill_runtime.get_skill_level(skill_id)
	var max_level := _skill_runtime.get_max_level(skill_id)
	if current_level >= max_level:
		return false
	var new_level := current_level + 1
	if not _skill_runtime.set_skill_level(skill_id, new_level):
		return false
	_selection_pending = false
	_current_choices.clear()
	var session_service := _get_session_service()
	if session_service != null:
		session_service.set_skill_state(_skill_runtime.get_skill_levels(), _rng.state)
		session_service.pause_manager.clear_pause(PauseManager.LEVEL_UP)
	level_up_completed.emit(skill_id, new_level)
	_emit_state()
	call_deferred("_try_begin_level_up")
	return true


func _on_run_xp_granted(_amount: int, _total: int, _context: Dictionary) -> void:
	_emit_state()
	_try_begin_level_up()


func _try_begin_level_up() -> void:
	var session_service := _get_session_service()
	if _selection_pending or session_service == null or not session_service.has_active_session():
		return
	var required := get_xp_required()
	if session_service.active_session.run_xp < required:
		return
	session_service.active_session.run_xp -= required
	session_service.active_session.run_level += 1
	_current_choices = _generate_choices()
	session_service.set_skill_state(_skill_runtime.get_skill_levels(), _rng.state)
	var event_bus := get_node_or_null("/root/GameEventBus")
	if event_bus != null:
		event_bus.king_level_up.emit(session_service.active_session.run_level)
	_emit_state()
	if _current_choices.is_empty():
		call_deferred("_try_begin_level_up")
		return
	_selection_pending = true
	level_up_started.emit(_current_choices.duplicate(true))
	session_service.pause_manager.request_pause(PauseManager.LEVEL_UP)


func _generate_choices() -> Array[Dictionary]:
	var eligible_ids: Array[String] = []
	for skill_id_value in _skill_configs.keys():
		var skill_id := str(skill_id_value)
		if _skill_runtime.get_skill_level(StringName(skill_id)) < _skill_runtime.get_max_level(StringName(skill_id)):
			eligible_ids.append(skill_id)
	for index in range(eligible_ids.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := eligible_ids[index]
		eligible_ids[index] = eligible_ids[swap_index]
		eligible_ids[swap_index] = temporary
	var result: Array[Dictionary] = []
	var choice_count := mini(maxi(int(_progression_config.get("choice_count", 3)), 1), eligible_ids.size())
	for index in choice_count:
		var skill_id := eligible_ids[index]
		var choice: Dictionary = _skill_configs[skill_id].duplicate(true)
		choice["current_level"] = _skill_runtime.get_skill_level(StringName(skill_id))
		choice["max_level"] = _skill_runtime.get_max_level(StringName(skill_id))
		result.append(choice)
	return result


func _emit_state() -> void:
	state_changed.emit(get_run_level(), get_run_xp(), get_xp_required())


func _get_session_service() -> Node:
	return get_node_or_null("/root/GameSessionService")


func _get_reward_service() -> Node:
	return get_node_or_null("/root/RewardGrantService")
