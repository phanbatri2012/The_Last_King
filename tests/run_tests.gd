extends SceneTree

var _failures: Array[String] = []
var _assertion_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[TEST] The Last King Phase 1")
	_test_project_configuration()
	_test_scenes_load()
	_test_faction_roster()
	_test_king_catalog()
	_test_localization_catalogs()
	_test_platform_adapter()
	_test_battle_session_serialization()
	_test_movement_input()
	_test_movement_arena_layout()
	await _test_king_scene_movement()
	_test_pause_manager()
	_test_default_profile()

	if _failures.is_empty():
		print("[TEST] PASS (%d assertions)" % _assertion_count)
		quit(0)
		return

	for failure in _failures:
		push_error("[TEST] %s" % failure)
	print("[TEST] FAIL (%d failures, %d assertions)" % [_failures.size(), _assertion_count])
	quit(1)


func _test_project_configuration() -> void:
	_expect(ProjectSettings.get_setting("application/config/name") == "The Last King", "Project name is canonical.")
	_expect(ProjectSettings.get_setting("application/config/version") == "0.1.0", "Game version is independent and explicit.")
	var project_file := _read_text("res://project.godot")
	_expect(project_file.contains("run/main_scene=\"res://scenes/bootstrap/bootstrap.tscn\""), "Bootstrap is configured as the main scene.")
	_expect(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer is enabled.")
	_expect(FileAccess.file_exists("res://export_presets.cfg"), "Export presets exist.")
	_expect(FileAccess.file_exists("res://AGENTS.md"), "Project rules exist.")
	for action_name in ["move_left", "move_right", "move_up", "move_down"]:
		_expect(InputMap.has_action(action_name), "Movement input action exists: %s" % action_name)
		_expect(not InputMap.action_get_events(action_name).is_empty(), "Movement input action has bindings: %s" % action_name)


func _test_scenes_load() -> void:
	var bootstrap := load("res://scenes/bootstrap/bootstrap.tscn")
	var main_menu := load("res://scenes/menus/main_menu.tscn")
	var king := load("res://scenes/gameplay/king.tscn")
	var movement_arena := load("res://scenes/gameplay/movement_arena.tscn")
	_expect(bootstrap is PackedScene, "Bootstrap scene loads.")
	_expect(main_menu is PackedScene, "Main menu scene loads.")
	_expect(king is PackedScene, "King scene loads.")
	_expect(movement_arena is PackedScene, "Movement arena scene loads.")


func _test_faction_roster() -> void:
	var roster := _load_json("res://data/factions/faction_roster.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(roster.get("schema_version", 0)) == 1, "Faction roster schema is versioned.")
	_expect(roster.get("roster_policy", "") == "open_ended", "Faction roster is open-ended.")
	var factions: Array = roster.get("factions", [])
	_expect(factions.size() >= 21, "Initial planning roster contains at least 21 factions.")

	var seen_ids: Dictionary = {}
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9]+(?:_[a-z0-9]+)*$")
	for faction_value in factions:
		_expect(faction_value is Dictionary, "Each faction entry is an object.")
		if not faction_value is Dictionary:
			continue
		var faction: Dictionary = faction_value
		var faction_id := str(faction.get("id", ""))
		var name_key := str(faction.get("name_key", ""))
		_expect(id_pattern.search(faction_id) != null, "Faction ID is stable snake_case: %s" % faction_id)
		_expect(not seen_ids.has(faction_id), "Faction ID is unique: %s" % faction_id)
		_expect(english.has(name_key), "Faction has an English display name: %s" % faction_id)
		_expect(vietnamese.has(name_key), "Faction has a Vietnamese display name: %s" % faction_id)
		seen_ids[faction_id] = true

	_expect(seen_ids.has("dai_viet"), "Dai Viet is retained as the MVP faction.")
	_expect(seen_ids.has("united_states_lakota"), "The United States-associated faction is retained.")
	_expect(seen_ids.has("achaemenid_persia"), "Persia is retained as a separate faction.")


func _test_king_catalog() -> void:
	var catalog := _load_json("res://data/kings/kings.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "King catalog schema is versioned.")
	_expect(not str(catalog.get("content_version", "")).is_empty(), "King catalog has an independent content version.")
	var kings: Array = catalog.get("kings", [])
	_expect(kings.size() == 1, "Phase 1 implements one MVP King.")
	if kings.is_empty() or not kings[0] is Dictionary:
		return
	var king: Dictionary = kings[0]
	_expect(king.get("id") == "tran_hung_dao", "Trần Hưng Đạo is the Phase 1 King.")
	_expect(king.get("faction_id") == "dai_viet", "The Phase 1 King belongs to Dai Viet.")
	_expect(english.has(str(king.get("name_key", ""))), "King name is localized in English.")
	_expect(vietnamese.has(str(king.get("name_key", ""))), "King name is localized in Vietnamese.")
	_expect(english.has(str(king.get("title_key", ""))), "King title is localized in English.")
	_expect(vietnamese.has(str(king.get("title_key", ""))), "King title is localized in Vietnamese.")
	var movement: Dictionary = king.get("movement", {})
	_expect(float(movement.get("speed", 0.0)) > 0.0, "King movement speed is positive.")
	_expect(float(movement.get("collision_radius", 0.0)) > 0.0, "King collision radius is positive.")


func _test_localization_catalogs() -> void:
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(not english.is_empty(), "English canonical catalog loads.")
	_expect(not vietnamese.is_empty(), "Vietnamese catalog loads.")
	for key in english.keys():
		_expect(vietnamese.has(key), "Vietnamese catalog contains key: %s" % key)


func _test_platform_adapter() -> void:
	var adapter_script := load("res://scripts/platform/adapters/desktop_platform_adapter.gd")
	_expect(adapter_script != null, "Desktop platform adapter script loads.")
	if adapter_script == null:
		return
	var adapter: PlatformAdapter = adapter_script.new()
	_expect(adapter.initialize(), "Desktop platform adapter initializes.")
	_expect(adapter.get_platform_name() == "desktop", "Desktop adapter reports its platform.")
	_expect(not adapter.supports(PlatformAdapter.Capability.IAP), "Desktop adapter does not invent IAP support.")
	for adapter_path in [
		"res://scripts/platform/adapters/android_platform_adapter.gd",
		"res://scripts/platform/adapters/ios_platform_adapter.gd",
	]:
		var mobile_adapter_script := load(adapter_path)
		_expect(mobile_adapter_script != null, "Mobile platform adapter script loads: %s" % adapter_path)
		if mobile_adapter_script != null:
			var mobile_adapter: PlatformAdapter = mobile_adapter_script.new()
			_expect(
				not mobile_adapter.supports(PlatformAdapter.Capability.IAP),
				"Mobile adapter keeps IAP disabled until its bridge exists: %s" % adapter_path
			)


func _test_battle_session_serialization() -> void:
	var session := BattleSession.new()
	session.create(&"tran_hung_dao", &"dai_viet", 12345)
	var snapshot := session.to_dict()
	_expect(snapshot.get("schema_version") == 1, "Battle session snapshot is versioned.")
	_expect(snapshot.get("king_id") == "tran_hung_dao", "Battle session keeps the King ID.")
	_expect(snapshot.get("faction_id") == "dai_viet", "Battle session keeps the faction ID.")
	_expect(snapshot.get("run_gold") == 0, "Battle session uses temporary run_gold.")
	_expect(snapshot.get("king_state") is Dictionary, "Battle session snapshots the King movement state.")


func _test_movement_input() -> void:
	var diagonal := MovementInputResolver.resolve(Vector2.ONE, Vector2.ZERO)
	_expect(is_equal_approx(diagonal.length(), 1.0), "Keyboard diagonal input is normalized.")
	_expect(diagonal.is_equal_approx(Vector2.ONE.normalized()), "Keyboard direction is preserved after normalization.")
	var analog := Vector2(0.35, -0.2)
	_expect(MovementInputResolver.resolve(Vector2.LEFT, analog).is_equal_approx(analog), "Active joystick input takes priority over keyboard input.")
	var velocity := MovementInputResolver.to_velocity(Vector2.ONE, 340.0)
	_expect(is_equal_approx(velocity.length(), 340.0), "Movement speed is direction-independent.")
	_expect(MovementInputResolver.to_velocity(Vector2.RIGHT, -1.0).is_zero_approx(), "Negative movement speed is rejected.")

	_expect(
		MovementJoystick.direction_from_offset(Vector2(4.0, 0.0), 72.0, 0.12).is_zero_approx(),
		"Joystick deadzone suppresses tiny pointer movement."
	)
	var full_right := MovementJoystick.direction_from_offset(Vector2(72.0, 0.0), 72.0, 0.12)
	_expect(full_right.is_equal_approx(Vector2.RIGHT), "Joystick reaches full cardinal input at its radius.")
	var clamped := MovementJoystick.direction_from_offset(Vector2(500.0, 0.0), 72.0, 0.12)
	_expect(clamped.is_equal_approx(Vector2.RIGHT), "Joystick input is clamped outside its radius.")
	var partial := MovementJoystick.direction_from_offset(Vector2(36.0, 0.0), 72.0, 0.12)
	_expect(partial.x > 0.0 and partial.x < 1.0, "Joystick preserves analog strength.")


func _test_movement_arena_layout() -> void:
	var packed_arena := load("res://scenes/gameplay/movement_arena.tscn") as PackedScene
	if packed_arena == null:
		_expect(false, "Movement arena layout fixture loads.")
		return
	var arena := packed_arena.instantiate()
	var joystick_control := arena.get_node("HudLayer/Hud/VirtualJoystick") as Control
	_expect(joystick_control != null, "Movement arena contains the virtual joystick.")
	if joystick_control != null:
		_expect(is_zero_approx(joystick_control.anchor_left), "Joystick is anchored to the left edge.")
		_expect(is_zero_approx(joystick_control.anchor_right), "Joystick does not anchor outside the right edge.")
		_expect(is_equal_approx(joystick_control.anchor_top, 1.0), "Joystick is anchored to the bottom edge.")
		_expect(joystick_control.offset_left >= 0.0, "Joystick has a visible left safe margin.")
		_expect(joystick_control.offset_top < joystick_control.offset_bottom, "Joystick control has positive height.")
	var back_button := arena.get_node("HudLayer/Hud/TopMargin/TopPanel/TopRow/BackButton") as Button
	_expect(back_button != null and back_button.custom_minimum_size.y >= 48.0, "Back button meets the touch target baseline.")
	arena.free()


func _test_king_scene_movement() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	if packed_king == null:
		_expect(false, "King movement integration fixture loads.")
		return
	var king := packed_king.instantiate() as KingController
	root.add_child(king)
	await process_frame
	king.follow_camera.enabled = false
	king.set_movement_bounds(Rect2(-100.0, -100.0, 200.0, 200.0))
	king.global_position = Vector2.ZERO
	king.set_virtual_direction(Vector2.ZERO)
	Input.action_press("move_right")
	for _frame in 4:
		await physics_frame
	Input.action_release("move_right")
	_expect(king.global_position.x > 0.0, "Configured keyboard input moves the King.")
	_expect(absf(king.global_position.y) < 0.01, "Keyboard horizontal movement does not drift vertically.")

	king.set_keyboard_enabled(false)
	king.global_position = Vector2.ZERO
	king.set_virtual_direction(Vector2.RIGHT)
	for _frame in 4:
		await physics_frame
	_expect(king.global_position.x > 0.0, "Virtual joystick input moves the King horizontally.")
	_expect(absf(king.global_position.y) < 0.01, "Horizontal movement does not drift vertically.")

	var x_after_horizontal := king.global_position.x
	king.set_virtual_direction(Vector2.DOWN)
	for _frame in 4:
		await physics_frame
	_expect(king.global_position.y > 0.0, "Virtual joystick input moves the King vertically.")
	_expect(is_equal_approx(king.global_position.x, x_after_horizontal), "Vertical movement does not drift horizontally.")

	king.global_position = Vector2(99.0, 0.0)
	king.set_virtual_direction(Vector2.RIGHT)
	await physics_frame
	_expect(king.global_position.x <= 70.01, "King collision radius remains inside the arena boundary.")
	king.set_virtual_direction(Vector2.ZERO)
	king.queue_free()
	await process_frame


func _test_pause_manager() -> void:
	var manager := PauseManager.new()
	manager.request_pause(PauseManager.PLAYER)
	manager.request_pause(PauseManager.PLATFORM)
	_expect(manager.is_paused(), "Multiple pause reasons pause the session.")
	manager.clear_pause(PauseManager.PLAYER)
	_expect(manager.is_paused(), "Session remains paused while one reason remains.")
	manager.clear_pause(PauseManager.PLATFORM)
	_expect(not manager.is_paused(), "Session resumes only after every reason clears.")


func _test_default_profile() -> void:
	var profile_service_script := load("res://scripts/progression/player_profile_service.gd")
	_expect(profile_service_script != null, "Player profile service script loads.")
	if profile_service_script == null:
		return
	var profile_service: Node = profile_service_script.new()
	var profile: Dictionary = profile_service.create_default_profile()
	var resources: Dictionary = profile.get("resources", {})
	_expect(resources.has("account_gold"), "Persistent profile uses account_gold.")
	_expect(not resources.has("run_gold"), "Persistent profile does not contain run_gold.")
	profile_service.free()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("Missing JSON fixture: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Unable to open JSON fixture: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_failures.append("Invalid JSON object: %s" % path)
		return {}
	return parsed


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_failures.append("Missing text fixture: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Unable to open text fixture: %s" % path)
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
