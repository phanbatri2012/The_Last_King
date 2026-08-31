extends SceneTree

var _failures: Array[String] = []
var _assertion_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[TEST] The Last King Phase 3 combat population")
	_test_project_configuration()
	_test_scenes_load()
	_test_faction_roster()
	_test_weapon_archetypes()
	_test_king_catalog()
	_test_enemy_catalog()
	_test_localization_catalogs()
	_test_platform_adapter()
	_test_battle_session_serialization()
	_test_enemy_spawn_director_state()
	_test_reward_grants()
	_test_movement_input()
	_test_movement_arena_layout()
	_test_infinite_world()
	_test_health_and_damage()
	_test_target_selection()
	await _test_king_scene_movement()
	await _test_auto_attack_combat()
	await _test_goblin_attack_combat()
	await _test_goblin_ranged_magic_combat()
	await _test_endless_respawn_and_gold_pickup()
	await _test_desktop_menu_exit_runtime()
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
	_expect(ProjectSettings.get_setting("application/config/version") == "0.3.0", "Game version is independent and explicit.")
	var project_file := _read_text("res://project.godot")
	_expect(project_file.contains("run/main_scene=\"res://scenes/bootstrap/bootstrap.tscn\""), "Bootstrap is configured as the main scene.")
	_expect(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer is enabled.")
	_expect(FileAccess.file_exists("res://export_presets.cfg"), "Export presets exist.")
	_expect(FileAccess.file_exists("res://.github/workflows/build-web.yml"), "GitHub Actions Web artifact workflow exists.")
	_expect(FileAccess.file_exists("res://AGENTS.md"), "Project rules exist.")
	_expect(ProjectSettings.has_setting("autoload/RewardGrantService"), "Central reward grant service is registered.")
	var export_presets := _read_text("res://export_presets.cfg")
	_expect(export_presets.contains("name=\"Web Preview\""), "A stock-template Web preview export preset exists.")
	var web_workflow := _read_text("res://.github/workflows/build-web.yml")
	_expect(web_workflow.contains("actions/deploy-pages@v4"), "The Web workflow deploys the preview to GitHub Pages.")
	for action_name in ["move_left", "move_right", "move_up", "move_down"]:
		_expect(InputMap.has_action(action_name), "Movement input action exists: %s" % action_name)
		_expect(not InputMap.action_get_events(action_name).is_empty(), "Movement input action has bindings: %s" % action_name)


func _test_scenes_load() -> void:
	var bootstrap := load("res://scenes/bootstrap/bootstrap.tscn")
	var main_menu := load("res://scenes/menus/main_menu.tscn")
	var king := load("res://scenes/gameplay/king.tscn")
	var goblin := load("res://scenes/gameplay/goblin.tscn")
	var run_gold_pickup := load("res://scenes/gameplay/run_gold_pickup.tscn")
	var movement_arena := load("res://scenes/gameplay/movement_arena.tscn")
	_expect(bootstrap is PackedScene, "Bootstrap scene loads.")
	_expect(main_menu is PackedScene, "Main menu scene loads.")
	_expect(king is PackedScene, "King scene loads.")
	_expect(goblin is PackedScene, "Goblin scene loads.")
	_expect(run_gold_pickup is PackedScene, "Run Gold pickup scene loads.")
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
	var weapon_catalog := _load_json("res://data/combat/weapon_archetypes.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "King catalog schema is versioned.")
	_expect(not str(catalog.get("content_version", "")).is_empty(), "King catalog has an independent content version.")
	var kings: Array = catalog.get("kings", [])
	_expect(kings.size() == 1, "Phase 2 keeps one MVP King.")
	if kings.is_empty() or not kings[0] is Dictionary:
		return
	var king: Dictionary = kings[0]
	_expect(king.get("id") == "tran_hung_dao", "Trần Hưng Đạo is the Phase 2 King.")
	_expect(king.get("faction_id") == "dai_viet", "The Phase 2 King belongs to Dai Viet.")
	var weapon_archetype_id := str(king.get("weapon_archetype_id", ""))
	var weapon_archetypes: Dictionary = {}
	for archetype_value in weapon_catalog.get("archetypes", []):
		if archetype_value is Dictionary:
			weapon_archetypes[str(archetype_value.get("id", ""))] = archetype_value
	_expect(weapon_archetypes.has(weapon_archetype_id), "The Phase 2 King references a known weapon archetype.")
	_expect(english.has(str(king.get("name_key", ""))), "King name is localized in English.")
	_expect(vietnamese.has(str(king.get("name_key", ""))), "King name is localized in Vietnamese.")
	_expect(english.has(str(king.get("title_key", ""))), "King title is localized in English.")
	_expect(vietnamese.has(str(king.get("title_key", ""))), "King title is localized in Vietnamese.")
	var movement: Dictionary = king.get("movement", {})
	_expect(float(movement.get("speed", 0.0)) > 0.0, "King movement speed is positive.")
	_expect(float(movement.get("collision_radius", 0.0)) > 0.0, "King collision radius is positive.")
	var health: Dictionary = king.get("health", {})
	var defense: Dictionary = king.get("defense", {})
	var attack: Dictionary = king.get("attack", {})
	_expect(float(health.get("max", 0.0)) > 0.0, "King maximum health is positive.")
	_expect(float(defense.get("armor", -1.0)) >= 0.0, "King armor is non-negative.")
	_expect(float(defense.get("magic_resistance", -1.0)) >= 0.0, "King magic resistance is non-negative.")
	for combat_key in ["damage", "range", "cooldown", "target_refresh"]:
		_expect(float(attack.get(combat_key, 0.0)) > 0.0, "King attack value is positive: %s" % combat_key)
	if weapon_archetypes.has(weapon_archetype_id):
		var archetype: Dictionary = weapon_archetypes[weapon_archetype_id]
		var damage_bounds: Dictionary = archetype.get("damage_bounds", {})
		var range_bounds: Dictionary = archetype.get("range_bounds", {})
		_expect(
			float(attack.get("damage", 0.0)) >= float(damage_bounds.get("min", INF))
			and float(attack.get("damage", 0.0)) <= float(damage_bounds.get("max", -INF)),
			"King damage stays inside its weapon archetype bounds."
		)
		_expect(
			float(attack.get("range", 0.0)) >= float(range_bounds.get("min", INF))
			and float(attack.get("range", 0.0)) <= float(range_bounds.get("max", -INF)),
			"King range stays inside its weapon archetype bounds."
		)


func _test_weapon_archetypes() -> void:
	var catalog := _load_json("res://data/combat/weapon_archetypes.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "Weapon archetype catalog is versioned.")
	var archetypes: Array = catalog.get("archetypes", [])
	_expect(archetypes.size() >= 4, "Sword, blade, bow, and crossbow archetypes are available.")
	var seen_ids: Dictionary = {}
	var lowest_melee_damage := INF
	var highest_ranged_damage := 0.0
	var highest_melee_range := 0.0
	var lowest_ranged_range := INF
	for archetype_value in archetypes:
		_expect(archetype_value is Dictionary, "Each weapon archetype is an object.")
		if not archetype_value is Dictionary:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		var attack_style := str(archetype.get("attack_style", ""))
		var damage_type := str(archetype.get("damage_type", ""))
		var name_key := str(archetype.get("name_key", ""))
		var damage_bounds: Dictionary = archetype.get("damage_bounds", {})
		var range_bounds: Dictionary = archetype.get("range_bounds", {})
		_expect(not seen_ids.has(archetype_id), "Weapon archetype ID is unique: %s" % archetype_id)
		_expect(english.has(name_key) and vietnamese.has(name_key), "Weapon archetype is localized: %s" % archetype_id)
		_expect(damage_type in ["physical", "magic"], "Weapon damage type is supported: %s" % archetype_id)
		_expect(float(damage_bounds.get("min", 0.0)) <= float(damage_bounds.get("max", -1.0)), "Weapon damage bounds are ordered: %s" % archetype_id)
		_expect(float(range_bounds.get("min", 0.0)) <= float(range_bounds.get("max", -1.0)), "Weapon range bounds are ordered: %s" % archetype_id)
		if attack_style == "melee":
			lowest_melee_damage = minf(lowest_melee_damage, float(damage_bounds.get("min", 0.0)))
			highest_melee_range = maxf(highest_melee_range, float(range_bounds.get("max", 0.0)))
		elif attack_style == "ranged":
			highest_ranged_damage = maxf(highest_ranged_damage, float(damage_bounds.get("max", 0.0)))
			lowest_ranged_range = minf(lowest_ranged_range, float(range_bounds.get("min", 0.0)))
		else:
			_expect(false, "Weapon attack style is supported: %s" % archetype_id)
		seen_ids[archetype_id] = true
	for expected_id in ["sword", "blade", "bow", "crossbow"]:
		_expect(seen_ids.has(expected_id), "Required weapon archetype exists: %s" % expected_id)
	_expect(lowest_melee_damage > highest_ranged_damage, "Every sword/blade damage band stays above every bow/crossbow damage band.")
	_expect(lowest_ranged_range > highest_melee_range, "Every bow/crossbow range band stays beyond every sword/blade range band.")


func _test_enemy_catalog() -> void:
	var catalog := _load_json("res://data/enemies/enemies.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 2, "Enemy catalog schema is versioned for multi-archetype combat.")
	_expect(str(catalog.get("content_version", "")).begins_with("phase3"), "Enemy catalog identifies Phase 3 content.")
	var enemies: Array = catalog.get("enemies", [])
	_expect(enemies.size() >= 4, "At least four Goblin combat archetypes are available.")
	var seen_ids: Dictionary = {}
	var seen_roles: Dictionary = {}
	var seen_aggro_ranges: Dictionary = {}
	var seen_attack_styles: Dictionary = {}
	var seen_damage_types: Dictionary = {}
	for enemy_value in enemies:
		_expect(enemy_value is Dictionary, "Each enemy entry is an object.")
		if not enemy_value is Dictionary:
			continue
		var enemy: Dictionary = enemy_value
		var enemy_id := str(enemy.get("id", ""))
		var combat_role := str(enemy.get("combat_role", ""))
		var health: Dictionary = enemy.get("health", {})
		var defense: Dictionary = enemy.get("defense", {})
		var movement: Dictionary = enemy.get("movement", {})
		var attack: Dictionary = enemy.get("attack", {})
		var spawn: Dictionary = enemy.get("spawn", {})
		var rewards: Dictionary = enemy.get("rewards", {})
		_expect(not enemy_id.is_empty() and not seen_ids.has(enemy_id), "Enemy ID is stable and unique: %s" % enemy_id)
		_expect(not combat_role.is_empty(), "Goblin has a data-driven combat role: %s" % enemy_id)
		_expect(english.has(str(enemy.get("name_key", ""))), "Enemy name is localized in English: %s" % enemy_id)
		_expect(vietnamese.has(str(enemy.get("name_key", ""))), "Enemy name is localized in Vietnamese: %s" % enemy_id)
		_expect(float(health.get("max", 0.0)) > 0.0, "Enemy maximum health is positive: %s" % enemy_id)
		_expect(float(defense.get("armor", -1.0)) >= 0.0, "Enemy armor is non-negative: %s" % enemy_id)
		_expect(float(defense.get("magic_resistance", -1.0)) >= 0.0, "Enemy magic resistance is non-negative: %s" % enemy_id)
		for movement_key in ["speed", "collision_radius", "aggro_range"]:
			_expect(float(movement.get(movement_key, 0.0)) > 0.0, "Enemy movement value is positive: %s/%s" % [enemy_id, movement_key])
		for attack_key in ["damage", "range", "attacks_per_second"]:
			_expect(float(attack.get(attack_key, 0.0)) > 0.0, "Enemy attack value is positive: %s/%s" % [enemy_id, attack_key])
		var attack_style := str(attack.get("attack_style", ""))
		var damage_type := str(attack.get("damage_type", ""))
		_expect(attack_style in ["melee", "ranged"], "Enemy attack style is supported: %s" % enemy_id)
		_expect(damage_type in ["physical", "magic"], "Enemy damage type is supported: %s" % enemy_id)
		_expect(float(spawn.get("weight", 0.0)) > 0.0, "Enemy has a positive seeded spawn weight: %s" % enemy_id)
		_expect(int(rewards.get("run_gold", 0)) > 0, "Enemy grants a positive run Gold reward: %s" % enemy_id)
		seen_ids[enemy_id] = true
		seen_roles[combat_role] = true
		seen_aggro_ranges[float(movement.get("aggro_range", 0.0))] = true
		seen_attack_styles[attack_style] = true
		seen_damage_types[damage_type] = true
	_expect(seen_ids.has("goblin"), "The original Goblin stable ID is retained.")
	for expected_id in ["goblin_brute", "goblin_archer", "goblin_hexer"]:
		_expect(seen_ids.has(expected_id), "Required Goblin archetype exists: %s" % expected_id)
	_expect(seen_roles.size() >= 4, "Goblin archetypes expose distinct combat roles.")
	_expect(seen_aggro_ranges.size() >= 4, "Each Goblin archetype has a distinct hatred range.")
	_expect(seen_attack_styles.has("melee") and seen_attack_styles.has("ranged"), "Goblin roster includes melee and ranged attackers.")
	_expect(seen_damage_types.has("physical") and seen_damage_types.has("magic"), "Goblin roster includes physical and magic damage.")


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
	_expect(adapter.supports(PlatformAdapter.Capability.QUIT_APPLICATION), "Desktop adapter exposes application quit support.")
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
			_expect(
				not mobile_adapter.supports(PlatformAdapter.Capability.QUIT_APPLICATION),
				"Mobile adapter does not expose desktop application quit: %s" % adapter_path
			)


func _test_battle_session_serialization() -> void:
	var session := BattleSession.new()
	session.create(&"tran_hung_dao", &"dai_viet", 12345)
	var snapshot := session.to_dict()
	_expect(snapshot.get("schema_version") == 2, "Battle session snapshot is versioned.")
	_expect(snapshot.get("king_id") == "tran_hung_dao", "Battle session keeps the King ID.")
	_expect(snapshot.get("faction_id") == "dai_viet", "Battle session keeps the faction ID.")
	_expect(snapshot.get("run_gold") == 0, "Battle session uses temporary run_gold.")
	_expect(snapshot.get("king_state") is Dictionary, "Battle session snapshots the King movement state.")
	var king_state: Dictionary = snapshot.get("king_state", {})
	_expect(king_state.get("health") is Dictionary, "Battle session snapshots the King health state.")
	_expect(snapshot.get("enemy_wave_state") is Dictionary, "Battle session reserves enemy combat state.")


func _test_enemy_spawn_director_state() -> void:
	var target := Node2D.new()
	var director := EnemySpawnDirector.new()
	director.set_spawn_roster([
		{"enemy_id": "goblin", "weight": 3.0},
		{"enemy_id": "goblin_hexer", "weight": 1.0},
	])
	director.configure(12345, target)
	director.ensure_population(3)
	_expect(director.get_pending_count() == 6, "Spawn director schedules enough Goblins to restore the bounded population.")
	_expect(director.get_target_population(0.0) == 9, "Endless encounter starts at a moderate nine-Goblin density.")
	_expect(director.get_target_population(45.0) == 10, "Active Goblin density grows gradually over survival time.")
	_expect(director.get_target_population(99999.0) == 15, "Simultaneous Goblins remain capped for Web and mobile performance.")
	var snapshot := director.get_runtime_snapshot()
	_expect(int(snapshot.get("next_spawn_serial", 0)) == 1, "Spawn director snapshots its next stable instance serial.")
	_expect(snapshot.get("pending_spawn_delays", []) is Array, "Spawn director snapshots pending replacements.")
	var restored := EnemySpawnDirector.new()
	restored.configure(99999, target, snapshot)
	_expect(restored.get_pending_count() == 6, "Spawn director restores pending replacements for Continue.")
	director.free()
	restored.free()
	target.free()


func _test_reward_grants() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 777)
	_expect(reward_grant_service.grant_run_gold(3, {"source_id": "test"}) == 3, "Reward service grants positive run Gold.")
	_expect(reward_grant_service.get_run_gold() == 3, "Granted run Gold is stored in the active battle only.")
	_expect(reward_grant_service.grant_run_gold(0) == 0, "Reward service rejects non-positive run Gold.")
	_expect(reward_grant_service.get_run_gold() == 3, "Rejected rewards do not alter run Gold.")
	game_session_service.end_session({"reason": "test_complete"})
	_expect(reward_grant_service.grant_run_gold(3) == 0, "Reward service rejects grants without an active battle.")


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
	var health_bar := arena.get_node("HudLayer/Hud/TopMargin/TopPanel/TopRow/Telemetry/KingHealthBar") as ProgressBar
	_expect(health_bar != null, "Combat HUD contains the King health bar.")
	_expect(
		not KingPlaceholderVisual.HEALTH_BAR_FILL_COLOR.is_equal_approx(GoblinPlaceholderVisual.HEALTH_BAR_FILL_COLOR),
		"King overhead health uses a distinct color from enemy health."
	)
	_expect(KingPlaceholderVisual.HEALTH_BAR_OFFSET_Y < -44.0, "King overhead health bar sits above the crown.")
	var run_gold_label := arena.get_node("HudLayer/Hud/TopMargin/TopPanel/TopRow/Telemetry/RunGoldLabel") as Label
	_expect(run_gold_label != null, "Combat HUD contains the yellow run Gold counter.")
	if run_gold_label != null:
		_expect(run_gold_label.get_theme_color("font_color").r > 0.9, "Run Gold counter uses a bright Gold color.")
	var spawn_director := arena.get_node("EnemySpawnDirector") as EnemySpawnDirector
	_expect(spawn_director != null and spawn_director.base_population == 9, "Combat arena starts with a moderate nine-Goblin population.")
	_expect(spawn_director != null and spawn_director.maximum_population == 15, "Combat arena caps simultaneous Goblins at fifteen.")
	var death_overlay := arena.get_node("HudLayer/DeathOverlay") as Control
	_expect(death_overlay != null, "Combat HUD contains the defeat overlay.")
	var retry_button := arena.get_node("HudLayer/DeathOverlay/Center/Panel/Content/RetryButton") as Button
	_expect(retry_button != null and retry_button.custom_minimum_size.y >= 48.0, "Retry button meets the touch target baseline.")
	var defeat_back_button := arena.get_node("HudLayer/DeathOverlay/Center/Panel/Content/DefeatBackButton") as Button
	_expect(defeat_back_button != null and defeat_back_button.custom_minimum_size.y >= 48.0, "Defeat overlay offers a touch-accessible return to court.")
	arena.free()
	var packed_menu := load("res://scenes/menus/main_menu.tscn") as PackedScene
	var menu := packed_menu.instantiate()
	var exit_button := menu.get_node("Center/Panel/Content/ExitButton") as Button
	_expect(exit_button != null and exit_button.custom_minimum_size.y >= 48.0, "Main menu offers a touch-accessible Exit Game button.")
	menu.free()


func _test_infinite_world() -> void:
	_expect(
		MovementArenaBackdrop.world_cell_for_position(Vector2(1000000.0, -1000000.0), 160) == Vector2i(6250, -6250),
		"Infinite backdrop resolves cells at large world coordinates."
	)
	_expect(
		MovementArenaBackdrop.world_cell_for_position(Vector2(-0.1, -160.1), 160) == Vector2i(-1, -2),
		"Infinite backdrop uses floor-based cells across negative coordinates."
	)
	var arena_script := _read_text("res://scenes/gameplay/movement_arena.gd")
	var backdrop_script := _read_text("res://scripts/gameplay/movement_arena_backdrop.gd")
	_expect(arena_script.contains("king.clear_movement_bounds()"), "Combat arena explicitly enables unbounded King movement.")
	_expect(not arena_script.contains("ARENA_RECT"), "Combat arena no longer defines a finite arena rectangle.")
	_expect(not backdrop_script.contains("arena_rect"), "Backdrop no longer draws a finite boundary.")
	_expect(arena_script.contains("EFFECTIVE_CAMERA_LIMIT := 2147480000"), "Camera limits are effectively unbounded for gameplay travel.")


func _test_health_and_damage() -> void:
	var health := HealthComponent.new()
	health.configure(100.0)
	var first_hit := DamageResolver.apply_damage(health, 28.0, {"source_id": "test_attacker"})
	_expect(bool(first_hit.get("accepted", false)), "Damage resolver accepts positive damage against a living target.")
	_expect(is_equal_approx(float(first_hit.get("applied", 0.0)), 28.0), "Damage resolver reports applied damage.")
	_expect(is_equal_approx(health.current_health, 72.0), "Health component receives resolved damage.")
	var rejected_hit := DamageResolver.apply_damage(health, -5.0)
	_expect(not bool(rejected_hit.get("accepted", true)), "Damage resolver rejects non-positive damage.")
	_expect(is_equal_approx(health.current_health, 72.0), "Rejected damage does not change health.")
	var lethal_hit := DamageResolver.apply_damage(health, 999.0, {"damage_type": "test"})
	_expect(bool(lethal_hit.get("killed", false)), "Damage resolver reports lethal damage.")
	_expect(is_zero_approx(health.current_health), "Lethal damage clamps health to zero.")
	_expect(not health.is_alive(), "Health component exposes its death state.")
	health.free()

	var defense := DefenseComponent.new()
	defense.configure({"armor": 10.0, "magic_resistance": 4.0})
	var defended_health := HealthComponent.new()
	defended_health.configure(100.0)
	var physical_hit := DamageResolver.apply_damage(
		defended_health,
		30.0,
		{"damage_type": "physical"},
		defense
	)
	_expect(is_equal_approx(float(physical_hit.get("applied", 0.0)), 20.0), "Armor mitigates physical damage through the shared resolver.")
	_expect(is_equal_approx(float(physical_hit.get("mitigated", 0.0)), 10.0), "Damage result reports physical mitigation.")
	var magic_hit := DamageResolver.apply_damage(
		defended_health,
		30.0,
		{"damage_type": "magic"},
		defense
	)
	_expect(is_equal_approx(float(magic_hit.get("applied", 0.0)), 26.0), "Magic resistance mitigates magic damage independently from armor.")
	defense.free()
	defended_health.free()


func _test_target_selection() -> void:
	var near_target := Node2D.new()
	var far_target := Node2D.new()
	near_target.position = Vector2(80.0, 0.0)
	far_target.position = Vector2(180.0, 0.0)
	var selected := CombatTargetSelector.nearest(Vector2.ZERO, [far_target, near_target], 200.0)
	_expect(selected == near_target, "Auto-target selector chooses the nearest candidate.")
	_expect(CombatTargetSelector.nearest(Vector2.ZERO, [far_target], 100.0) == null, "Auto-target selector respects attack range.")
	near_target.free()
	far_target.free()


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
	king.clear_movement_bounds()
	king.global_position = Vector2(100000.0, -100000.0)
	king.set_virtual_direction(Vector2.RIGHT)
	await physics_frame
	_expect(king.global_position.x > 100000.0, "King movement remains unbounded at large world coordinates.")
	_expect(not king.has_movement_bounds(), "Infinite-map mode leaves movement bounds disabled.")
	king.set_virtual_direction(Vector2.ZERO)
	king.queue_free()
	await process_frame


func _test_auto_attack_combat() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	if packed_king == null or packed_goblin == null:
		_expect(false, "Combat integration fixtures load.")
		return
	var king := packed_king.instantiate() as KingController
	var goblin := packed_goblin.instantiate() as GoblinController
	king.global_position = Vector2.ZERO
	goblin.global_position = Vector2(110.0, 0.0)
	root.add_child(king)
	root.add_child(goblin)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.clear_movement_bounds()
	var king_catalog := _load_json("res://data/kings/kings.json")
	var enemy_catalog := _load_json("res://data/enemies/enemies.json")
	var king_records: Array = king_catalog.get("kings", [])
	var enemy_records: Array = enemy_catalog.get("enemies", [])
	if king_records.is_empty() or enemy_records.is_empty():
		_expect(false, "Combat integration data fixtures contain records.")
		king.queue_free()
		goblin.queue_free()
		await process_frame
		return
	var king_data: Dictionary = king_records[0]
	var enemy_data: Dictionary = enemy_records[0]
	king.configure(king_data)
	_expect(king.weapon_archetype_id == &"sword", "Trần Hưng Đạo equips the configured sword archetype.")
	_expect(king.auto_attack.attack_style == "melee", "Sword configures the King for melee attacks.")
	var rapid_attack: Dictionary = king_data.get("attack", {}).duplicate(true)
	rapid_attack["damage"] = 35.0
	rapid_attack["cooldown"] = 0.02
	king.auto_attack.configure(rapid_attack)
	goblin.configure(enemy_data, "integration_goblin")
	goblin.set_combat_enabled(false)

	var starting_health := goblin.health.current_health
	for _frame in 6:
		await physics_frame
	_expect(king.auto_attack.get_current_target() == goblin, "King automatically acquires the nearby Goblin.")
	_expect(goblin.health.current_health < starting_health, "King automatically attacks the acquired Goblin.")
	for _frame in 18:
		await physics_frame
	_expect(not goblin.is_combat_alive(), "Repeated auto-attacks kill the Goblin through the shared resolver.")
	king.queue_free()
	goblin.queue_free()
	await process_frame

	var ranged_king := packed_king.instantiate() as KingController
	root.add_child(ranged_king)
	await process_frame
	ranged_king.follow_camera.enabled = false
	var ranged_data: Dictionary = king_data.duplicate(true)
	var weapon_catalog := _load_json("res://data/combat/weapon_archetypes.json")
	for archetype_value in weapon_catalog.get("archetypes", []):
		if archetype_value is Dictionary and archetype_value.get("id") == "bow":
			ranged_data["weapon_archetype_id"] = "bow"
			ranged_data["weapon_archetype"] = archetype_value.duplicate(true)
			break
	var ranged_attack: Dictionary = ranged_data.get("attack", {}).duplicate(true)
	ranged_attack["damage"] = 34.0
	ranged_attack["range"] = 640.0
	ranged_data["attack"] = ranged_attack
	ranged_king.configure(ranged_data)
	_expect(ranged_king.auto_attack.attack_style == "ranged", "Bow configures the King for ranged attacks.")
	_expect(ranged_king.auto_attack.attack_damage < king_data.get("attack", {}).get("damage", 0.0), "Bow King attack is lower than the sword King's attack.")
	_expect(is_equal_approx(ranged_king.auto_attack.attack_range, 640.0), "A ranged King's individual attack range is preserved.")
	var ranged_detection := ranged_king.get_node("AutoAttack/DetectionArea/DetectionShape") as CollisionShape2D
	var ranged_circle := ranged_detection.shape as CircleShape2D
	_expect(is_equal_approx(ranged_circle.radius, 640.0), "Ranged attack detection expands to the configured King-specific range.")
	var distant_goblin := packed_goblin.instantiate() as GoblinController
	distant_goblin.global_position = ranged_king.global_position + Vector2(500.0, 0.0)
	root.add_child(distant_goblin)
	await process_frame
	distant_goblin.configure(enemy_data, "ranged_integration_goblin")
	distant_goblin.set_combat_enabled(false)
	var distant_starting_health := distant_goblin.health.current_health
	for _frame in 5:
		await physics_frame
	_expect(ranged_king.auto_attack.get_current_target() == distant_goblin, "Bow King acquires an enemy beyond every melee weapon range.")
	_expect(distant_goblin.health.current_health < distant_starting_health, "Bow King damages an enemy at the configured long range.")
	ranged_king.queue_free()
	distant_goblin.queue_free()
	await process_frame


func _test_goblin_attack_combat() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	if packed_king == null or packed_goblin == null:
		_expect(false, "Goblin attack integration fixtures load.")
		return
	var king := packed_king.instantiate() as KingController
	var goblin := packed_goblin.instantiate() as GoblinController
	king.global_position = Vector2.ZERO
	goblin.global_position = Vector2(600.0, 0.0)
	root.add_child(king)
	root.add_child(goblin)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.auto_attack.set_combat_enabled(false)
	var king_catalog := _load_json("res://data/kings/kings.json")
	var enemy_catalog := _load_json("res://data/enemies/enemies.json")
	var king_records: Array = king_catalog.get("kings", [])
	var enemy_records: Array = enemy_catalog.get("enemies", [])
	if king_records.is_empty() or enemy_records.is_empty():
		_expect(false, "Goblin attack integration data fixtures contain records.")
		king.queue_free()
		goblin.queue_free()
		await process_frame
		return
	var king_data: Dictionary = king_records[0]
	var enemy_data: Dictionary = enemy_records[0].duplicate(true)
	var rapid_attack: Dictionary = enemy_data.get("attack", {}).duplicate(true)
	rapid_attack["attacks_per_second"] = 50.0
	enemy_data["attack"] = rapid_attack
	king.configure(king_data)
	king.auto_attack.set_combat_enabled(false)
	goblin.configure(enemy_data, "attacking_goblin")
	goblin.set_target(king)
	var starting_health := king.health.current_health
	for _frame in 5:
		await physics_frame
	_expect(not goblin.is_engaged(), "Goblin remains idle while the King is outside its hatred range.")
	_expect(is_equal_approx(king.health.current_health, starting_health), "Idle Goblin does not damage a distant King.")
	var idle_position := goblin.global_position
	DamageResolver.apply_damage(
		goblin.health,
		5.0,
		{"source_kind": "king", "source_id": "integration_king", "damage_type": "physical"},
		goblin.defense
	)
	await physics_frame
	_expect(goblin.is_engaged(), "A Goblin immediately retaliates after the King attacks it outside hatred range.")
	_expect(goblin.global_position.distance_to(king.global_position) < idle_position.distance_to(king.global_position), "An alerted Goblin starts pursuing the King.")
	goblin.global_position = Vector2(65.0, 0.0)
	for _frame in 5:
		await physics_frame
	_expect(king.health.current_health < starting_health, "Goblin melee attacks damage the King through the shared resolver.")
	_expect(king.visual.get_health_ratio() < 1.0, "King overhead health bar reacts to received damage.")
	_expect(is_equal_approx(king.visual.get_health_ratio(), king.health.get_ratio()), "King overhead health ratio matches the health component.")
	king.queue_free()
	goblin.queue_free()
	await process_frame


func _test_goblin_ranged_magic_combat() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	if packed_king == null or packed_goblin == null:
		_expect(false, "Ranged magic combat fixtures load.")
		return
	var king := packed_king.instantiate() as KingController
	var hexer := packed_goblin.instantiate() as GoblinController
	king.global_position = Vector2.ZERO
	hexer.global_position = Vector2(300.0, 0.0)
	root.add_child(king)
	root.add_child(hexer)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	var king_records: Array = _load_json("res://data/kings/kings.json").get("kings", [])
	var enemy_records: Array = _load_json("res://data/enemies/enemies.json").get("enemies", [])
	var hexer_data: Dictionary = {}
	for enemy_value in enemy_records:
		if enemy_value is Dictionary and enemy_value.get("id") == "goblin_hexer":
			hexer_data = enemy_value.duplicate(true)
			break
	if king_records.is_empty() or hexer_data.is_empty():
		_expect(false, "Ranged magic combat data fixtures contain a Goblin Hexer.")
		king.queue_free()
		hexer.queue_free()
		await process_frame
		return
	king.configure(king_records[0])
	king.auto_attack.set_combat_enabled(false)
	var rapid_attack: Dictionary = hexer_data.get("attack", {}).duplicate(true)
	rapid_attack["attacks_per_second"] = 50.0
	hexer_data["attack"] = rapid_attack
	hexer.configure(hexer_data, "magic_integration_goblin")
	hexer.set_target(king)
	var starting_health := king.health.current_health
	for _frame in 5:
		await physics_frame
	_expect(hexer.is_engaged(), "Goblin Hexer engages when the King enters its individual hatred range.")
	_expect(hexer.attack_style == "ranged", "Goblin Hexer uses a ranged attack style.")
	_expect(hexer.damage_type == "magic", "Goblin Hexer deals magic damage.")
	_expect(hexer.attack_visual.attack_style == "ranged" and hexer.attack_visual.damage_type == "magic", "Goblin Hexer uses the ranged magic attack visual.")
	_expect(king.health.current_health < starting_health, "Ranged magic Goblin damages the King without entering melee range.")
	king.queue_free()
	hexer.queue_free()
	await process_frame


func _test_endless_respawn_and_gold_pickup() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 24680)
	var packed_arena := load("res://scenes/gameplay/movement_arena.tscn") as PackedScene
	var arena := packed_arena.instantiate()
	root.add_child(arena)
	await process_frame
	var arena_king := arena.get_node("King") as KingController
	arena_king.follow_camera.enabled = false
	arena_king.set_keyboard_enabled(false)
	arena_king.auto_attack.set_combat_enabled(false)
	for _frame in 90:
		await physics_frame
		for child in arena.get_children():
			if child is GoblinController:
				(child as GoblinController).set_combat_enabled(false)
	var initial_goblins: Array[GoblinController] = []
	var initial_archetypes: Dictionary = {}
	for child in arena.get_children():
		if child is GoblinController:
			var goblin := child as GoblinController
			goblin.set_combat_enabled(false)
			initial_goblins.append(goblin)
			initial_archetypes[str(goblin.enemy_id)] = true
	_expect(initial_goblins.size() == 9, "Endless encounter starts with nine simultaneously active Goblins.")
	_expect(initial_archetypes.size() >= 2, "Seeded endless spawning mixes multiple Goblin archetypes.")
	if initial_goblins.is_empty():
		arena.queue_free()
		await process_frame
		game_session_service.end_session({"reason": "test_failed"})
		return
	var defeated_enemy_id := str(initial_goblins[0].enemy_id)
	var expected_gold := 0
	for enemy_value in _load_json("res://data/enemies/enemies.json").get("enemies", []):
		if enemy_value is Dictionary and enemy_value.get("id") == defeated_enemy_id:
			expected_gold = int(enemy_value.get("rewards", {}).get("run_gold", 0))
			break
	DamageResolver.apply_damage(
		initial_goblins[0].health,
		999.0,
		{"source_kind": "king", "source_id": "integration_test", "damage_type": "physical"},
		initial_goblins[0].defense
	)
	await process_frame
	var dropped_gold: RunGoldPickup
	for child in arena.get_children():
		if child is RunGoldPickup:
			dropped_gold = child as RunGoldPickup
			break
	_expect(dropped_gold != null, "Defeated Goblin drops a visible run Gold pickup node.")
	if dropped_gold != null:
		_expect(dropped_gold.amount == expected_gold, "Gold pickup uses the defeated Goblin archetype's data-driven reward amount.")
		dropped_gold.global_position = arena_king.global_position
		for _frame in 3:
			await physics_frame
		_expect(reward_grant_service.get_run_gold() == expected_gold, "King collects the dropped run Gold through Area2D overlap.")
	for _frame in 110:
		await physics_frame
		for child in arena.get_children():
			if child is GoblinController:
				(child as GoblinController).set_combat_enabled(false)
	var living_goblins := 0
	for child in arena.get_children():
		if child is GoblinController and child.is_combat_alive():
			living_goblins += 1
	_expect(living_goblins == 9, "A replacement Goblin restores the bounded endless encounter population.")
	arena.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


func _test_desktop_menu_exit_runtime() -> void:
	var game_services := root.get_node("GameServices")
	var localization_service := root.get_node("LocalizationService")
	_expect(game_services.initialize(), "Game services initialize for menu runtime verification.")
	var packed_menu := load("res://scenes/menus/main_menu.tscn") as PackedScene
	var menu := packed_menu.instantiate()
	root.add_child(menu)
	await process_frame
	var exit_button := menu.get_node("Center/Panel/Content/ExitButton") as Button
	_expect(exit_button.visible, "Exit Game button is visible in the Windows desktop runtime.")
	_expect(exit_button.text == localization_service.translate_key("menu.exit_game"), "Exit Game button uses localized text.")
	menu.queue_free()
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
