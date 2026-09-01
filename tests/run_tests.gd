extends SceneTree

var _failures: Array[String] = []
var _assertion_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[TEST] The Last King Phase 5 royal progression")
	_test_project_configuration()
	_test_scenes_load()
	_test_faction_roster()
	_test_weapon_archetypes()
	_test_king_catalog()
	_test_enemy_catalog()
	_test_unit_catalog()
	_test_king_skill_catalog()
	_test_localization_catalogs()
	_test_platform_adapter()
	_test_battle_session_serialization()
	_test_enemy_spawn_director_state()
	_test_combat_drop_director()
	_test_formation_slots()
	_test_reward_grants()
	_test_movement_input()
	_test_movement_arena_layout()
	_test_infinite_world()
	_test_health_and_damage()
	await _test_healing_orb_pickup()
	_test_target_selection()
	await _test_king_scene_movement()
	await _test_auto_attack_combat()
	await _test_king_piercing_attacks()
	await _test_goblin_attack_combat()
	await _test_goblin_ranged_magic_combat()
	await _test_spearman_combat()
	await _test_ally_ranged_combat()
	await _test_army_summoning_and_restore()
	await _test_dai_viet_roster_summoning()
	await _test_unlimited_army_upgrade()
	await _test_king_level_and_skills()
	await _test_healing_orb_continue()
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
	_expect(ProjectSettings.get_setting("application/config/version") == "0.5.0", "Game version is independent and explicit.")
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
	_expect(InputMap.has_action("summon_spearman"), "Desktop summon input action exists.")
	_expect(not InputMap.action_get_events("summon_spearman").is_empty(), "Desktop summon action has a keyboard binding.")
	for hotkey_slot in range(1, 8):
		var action_name := "summon_unit_%d" % hotkey_slot
		_expect(InputMap.has_action(action_name), "Roster summon input action exists: %s" % action_name)
		_expect(not InputMap.action_get_events(action_name).is_empty(), "Roster summon action has a keyboard binding: %s" % action_name)


func _test_scenes_load() -> void:
	var bootstrap := load("res://scenes/bootstrap/bootstrap.tscn")
	var main_menu := load("res://scenes/menus/main_menu.tscn")
	var king := load("res://scenes/gameplay/king.tscn")
	var goblin := load("res://scenes/gameplay/goblin.tscn")
	var summoned_unit := load("res://scenes/gameplay/summoned_unit.tscn")
	var run_gold_pickup := load("res://scenes/gameplay/run_gold_pickup.tscn")
	var healing_orb_pickup := load("res://scenes/gameplay/healing_orb_pickup.tscn")
	var enemy_projectile := load("res://scenes/gameplay/enemy_projectile.tscn")
	var ally_projectile := load("res://scenes/gameplay/ally_projectile.tscn")
	var movement_arena := load("res://scenes/gameplay/movement_arena.tscn")
	_expect(bootstrap is PackedScene, "Bootstrap scene loads.")
	_expect(main_menu is PackedScene, "Main menu scene loads.")
	_expect(king is PackedScene, "King scene loads.")
	_expect(goblin is PackedScene, "Goblin scene loads.")
	_expect(summoned_unit is PackedScene, "Summoned unit scene loads.")
	_expect(run_gold_pickup is PackedScene, "Run Gold pickup scene loads.")
	_expect(healing_orb_pickup is PackedScene, "Healing Orb pickup scene loads.")
	_expect(enemy_projectile is PackedScene, "Pooled enemy projectile scene loads.")
	_expect(ally_projectile is PackedScene, "Pooled allied projectile scene loads.")
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
	var army_capacity: Dictionary = king.get("army_capacity", {})
	_expect(float(health.get("max", 0.0)) > 0.0, "King maximum health is positive.")
	_expect(float(defense.get("armor", -1.0)) >= 0.0, "King armor is non-negative.")
	_expect(float(defense.get("magic_resistance", -1.0)) >= 0.0, "King magic resistance is non-negative.")
	_expect(int(army_capacity.get("max", 0)) == 20, "Trần Hưng Đạo starts with twenty Army Capacity.")
	_expect(bool(army_capacity.get("unlimited", false)), "Trần Hưng Đạo can summon an unlimited number of living soldiers.")
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
	_expect(str(catalog.get("content_version", "")).begins_with("phase5"), "Enemy catalog identifies Phase 5 survival content.")
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
		_expect(int(rewards.get("run_xp", 0)) > 0, "Enemy grants positive King XP: %s" % enemy_id)
		var healing_orb: Dictionary = rewards.get("healing_orb", {})
		_expect(float(healing_orb.get("chance", -1.0)) >= 0.0 and float(healing_orb.get("chance", 2.0)) <= 1.0, "Enemy Healing Orb chance is bounded: %s" % enemy_id)
		_expect(float(healing_orb.get("max_health_fraction", 0.0)) > 0.0, "Enemy Healing Orb restores a positive health fraction: %s" % enemy_id)
		if attack_style == "ranged":
			var projectile: Dictionary = attack.get("projectile", {})
			_expect(float(attack.get("windup", 0.0)) > 0.0, "Ranged Goblin telegraphs before firing: %s" % enemy_id)
			for projectile_key in ["speed", "radius", "lifetime"]:
				_expect(float(projectile.get(projectile_key, 0.0)) > 0.0, "Ranged Goblin projectile value is positive: %s/%s" % [enemy_id, projectile_key])
			_expect(str(projectile.get("visual_kind", "")) in ["arrow", "magic_orb"], "Ranged Goblin uses a supported real projectile: %s" % enemy_id)
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


func _test_unit_catalog() -> void:
	var catalog := _load_json("res://data/units/units.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "Unit catalog schema is versioned.")
	_expect(str(catalog.get("content_version", "")).begins_with("phase5"), "Unit catalog identifies Phase 5 content.")
	var units: Array = catalog.get("units", [])
	_expect(units.size() == 7, "Phase 4C exposes all seven summonable Dai Viet unit types.")
	var expected_ids := [
		"dai_viet_spearman",
		"dai_viet_crossbowman",
		"dai_viet_royal_guard",
		"dai_viet_ambush_archer",
		"dai_viet_raider",
		"dai_viet_elephant_guard",
		"dai_viet_royal_war_elephant",
	]
	var seen_ids: Dictionary = {}
	var seen_hotkeys: Dictionary = {}
	var seen_formation_roles: Dictionary = {}
	var ranged_count := 0
	for unit_value in units:
		_expect(unit_value is Dictionary, "Each Dai Viet unit entry is an object.")
		if not unit_value is Dictionary:
			continue
		var unit: Dictionary = unit_value
		var unit_id := str(unit.get("id", ""))
		var health: Dictionary = unit.get("health", {})
		var defense: Dictionary = unit.get("defense", {})
		var movement: Dictionary = unit.get("movement", {})
		var attack: Dictionary = unit.get("attack", {})
		var summon: Dictionary = unit.get("summon", {})
		var upgrade: Dictionary = unit.get("upgrade", {})
		var formation: Dictionary = unit.get("formation", {})
		var presentation: Dictionary = unit.get("presentation", {})
		var hotkey_slot := int(summon.get("hotkey_slot", 0))
		_expect(unit.get("faction_id") == "dai_viet", "Unit belongs to Dai Viet: %s" % unit_id)
		_expect(not seen_ids.has(unit_id), "Unit ID is unique: %s" % unit_id)
		_expect(english.has(str(unit.get("name_key", ""))) and vietnamese.has(str(unit.get("name_key", ""))), "Unit name is localized: %s" % unit_id)
		_expect(english.has(str(unit.get("role_key", ""))) and vietnamese.has(str(unit.get("role_key", ""))), "Unit role is localized: %s" % unit_id)
		_expect(float(health.get("max", 0.0)) > 0.0, "Unit health is positive: %s" % unit_id)
		_expect(float(defense.get("armor", -1.0)) >= 0.0 and float(defense.get("magic_resistance", -1.0)) >= 0.0, "Unit defenses are non-negative: %s" % unit_id)
		_expect(float(movement.get("speed", 0.0)) > 0.0 and float(movement.get("collision_radius", 0.0)) > 0.0, "Unit movement values are positive: %s" % unit_id)
		for attack_key in ["damage", "range", "detection_range", "leash_range", "attacks_per_second", "target_refresh"]:
			_expect(float(attack.get(attack_key, 0.0)) > 0.0, "Unit attack value is positive: %s/%s" % [unit_id, attack_key])
		_expect(int(summon.get("run_gold_cost", 0)) > 0 and int(summon.get("capacity_cost", 0)) > 0, "Unit has positive summon costs: %s" % unit_id)
		_expect(int(upgrade.get("base_gold_cost", 0)) > 0 and int(upgrade.get("max_level", 0)) > 0, "Unit has a positive run-Gold upgrade curve: %s" % unit_id)
		for upgrade_key in ["health_per_level", "damage_per_level", "defense_per_level", "attack_speed_per_level"]:
			_expect(float(upgrade.get(upgrade_key, -1.0)) >= 0.0, "Unit upgrade stat is non-negative: %s/%s" % [unit_id, upgrade_key])
		_expect(hotkey_slot >= 1 and hotkey_slot <= 7 and not seen_hotkeys.has(hotkey_slot), "Unit has a unique roster hotkey: %s" % unit_id)
		_expect(int(formation.get("slots_per_ring", 0)) > 0 and float(formation.get("base_radius", 0.0)) > 0.0, "Unit formation is data-driven: %s" % unit_id)
		_expect(not str(presentation.get("visual_kind", "")).is_empty(), "Unit has a distinct visual archetype: %s" % unit_id)
		if attack.get("attack_style") == "ranged":
			ranged_count += 1
			var projectile: Dictionary = attack.get("projectile", {})
			for projectile_key in ["speed", "radius", "lifetime"]:
				_expect(float(projectile.get(projectile_key, 0.0)) > 0.0, "Ranged unit projectile is configured: %s/%s" % [unit_id, projectile_key])
		seen_ids[unit_id] = true
		seen_hotkeys[hotkey_slot] = true
		seen_formation_roles[str(formation.get("role", ""))] = true
	for expected_id in expected_ids:
		_expect(seen_ids.has(expected_id), "Required Dai Viet unit exists: %s" % expected_id)
	_expect(ranged_count == 2, "Dai Viet roster includes two real ranged unit types.")
	_expect(seen_formation_roles.size() >= 6, "Dai Viet units use role-specific formation groups.")
	var content_database := root.get_node("ContentDatabase")
	_expect(content_database.initialize(), "Content database validates the unit catalog at startup.")
	_expect(content_database.get_unit(&"dai_viet_spearman").get("id") == "dai_viet_spearman", "Content database indexes the Spearman.")
	_expect(content_database.get_unit_ids_for_faction(&"dai_viet").size() == 7, "Content database queries the full Dai Viet roster by faction.")


func _test_king_skill_catalog() -> void:
	var catalog := _load_json("res://data/skills/king_skills.json")
	var english := _load_json("res://localization/en-US/common.json")
	var vietnamese := _load_json("res://localization/vi-VN/common.json")
	_expect(int(catalog.get("schema_version", 0)) == 1, "King skill catalog is versioned.")
	_expect(str(catalog.get("content_version", "")).begins_with("phase5"), "King skill catalog identifies Phase 5 content.")
	var progression: Dictionary = catalog.get("progression", {})
	_expect(int(progression.get("base_xp_to_level", 0)) > 0, "King leveling has a positive XP requirement.")
	_expect(int(progression.get("choice_count", 0)) == 3, "Each King level offers three seeded skill choices.")
	var skills: Array = catalog.get("skills", [])
	_expect(skills.size() >= 6, "King has passive, projectile, and area skill choices.")
	var effect_types: Dictionary = {}
	for skill_value in skills:
		if not skill_value is Dictionary:
			_expect(false, "Each King skill entry is an object.")
			continue
		var skill: Dictionary = skill_value
		var skill_id := str(skill.get("id", ""))
		_expect(english.has(str(skill.get("name_key", ""))) and vietnamese.has(str(skill.get("name_key", ""))), "King skill name is localized: %s" % skill_id)
		_expect(english.has(str(skill.get("description_key", ""))) and vietnamese.has(str(skill.get("description_key", ""))), "King skill description is localized: %s" % skill_id)
		_expect(skill.get("levels", []) is Array and skill.get("levels", []).size() == 3, "King skill has three upgrade ranks: %s" % skill_id)
		effect_types[str(skill.get("effect_type", ""))] = true
	_expect(effect_types.has("piercing_wave") and effect_types.has("dragon_aura"), "King roster includes piercing and area active skills.")
	var content_database := root.get_node("ContentDatabase")
	_expect(content_database.get_king_skill_ids().size() == skills.size(), "Content database indexes every King skill.")


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
	_expect(snapshot.get("army") is Array, "Battle session snapshots summoned allied units.")
	_expect(snapshot.get("skills") is Dictionary and snapshot.get("upgrades") is Dictionary, "Battle session reserves skill and army-upgrade progression.")
	_expect(snapshot.get("run_level") == 1 and snapshot.get("run_xp") == 0, "Battle session starts King progression at level one.")


func _test_enemy_spawn_director_state() -> void:
	var target := Node2D.new()
	var director := EnemySpawnDirector.new()
	director.set_spawn_roster([
		{"enemy_id": "goblin", "weight": 3.0},
		{"enemy_id": "goblin_hexer", "weight": 1.0},
	])
	director.configure(12345, target)
	director.ensure_population(3)
	_expect(director.get_pending_count() == 11, "Spawn director schedules enough Goblins to restore the denser bounded population.")
	_expect(director.get_target_population(0.0) == 14, "Endless encounter starts with fourteen active Goblins.")
	_expect(director.get_target_population(35.0) == 15, "Active Goblin density grows gradually over survival time.")
	_expect(director.get_target_population(99999.0) == 24, "Simultaneous Goblins remain capped for Web and mobile performance.")
	var snapshot := director.get_runtime_snapshot()
	_expect(int(snapshot.get("next_spawn_serial", 0)) == 1, "Spawn director snapshots its next stable instance serial.")
	_expect(snapshot.get("pending_spawn_delays", []) is Array, "Spawn director snapshots pending replacements.")
	var restored := EnemySpawnDirector.new()
	restored.configure(99999, target, snapshot)
	_expect(restored.get_pending_count() == 11, "Spawn director restores pending replacements for Continue.")
	director.free()
	restored.free()
	target.free()


func _test_combat_drop_director() -> void:
	var guaranteed_rewards := {
		"healing_orb": {"chance": 1.0, "max_health_fraction": 0.14},
	}
	var first := CombatDropDirector.new()
	first.configure(12345)
	var first_drop := first.roll_healing_pickup(guaranteed_rewards)
	_expect(first_drop.get("pickup_id") == "healing_orb_00000001", "Healing drops receive stable serial IDs.")
	_expect(is_equal_approx(float(first_drop.get("max_health_fraction", 0.0)), 0.14), "Healing drop preserves its data-driven recovery fraction.")
	var snapshot := first.get_runtime_snapshot()
	var restored := CombatDropDirector.new()
	restored.configure(99999, snapshot)
	var restored_drop := restored.roll_healing_pickup(guaranteed_rewards)
	_expect(restored_drop.get("pickup_id") == "healing_orb_00000002", "Healing drop serial continues after snapshot restore.")
	var replay := CombatDropDirector.new()
	replay.configure(12345)
	_expect(replay.roll_healing_pickup(guaranteed_rewards) == first_drop, "Healing drop rolls are reproducible from the battle seed.")
	_expect(first.roll_healing_pickup({"healing_orb": {"chance": 0.0, "max_health_fraction": 0.14}}).is_empty(), "Zero drop chance never creates a Healing Orb.")
	first.free()
	restored.free()
	replay.free()


func _test_formation_slots() -> void:
	var formation := {
		"base_radius": 150.0,
		"slots_per_ring": 4,
		"ring_spacing": 50.0,
		"angle_offset_degrees": -90.0,
	}
	var first := FormationSlotCalculator.ring_slot(0, formation)
	var second := FormationSlotCalculator.ring_slot(1, formation)
	var fifth := FormationSlotCalculator.ring_slot(4, formation)
	_expect(is_equal_approx(first.length(), 150.0), "First formation ring uses its data-driven radius.")
	_expect(first.distance_to(second) > 100.0, "Adjacent formation slots do not overlap.")
	_expect(is_equal_approx(fifth.length(), 200.0), "Overflow units move to the next formation ring.")
	_expect(FormationSlotCalculator.ring_slot(-5, formation).is_equal_approx(first), "Formation slot calculator safely clamps negative indices.")


func _test_reward_grants() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 777)
	_expect(reward_grant_service.grant_run_gold(3, {"source_id": "test"}) == 3, "Reward service grants positive run Gold.")
	_expect(reward_grant_service.get_run_gold() == 3, "Granted run Gold is stored in the active battle only.")
	_expect(reward_grant_service.grant_run_gold(0) == 0, "Reward service rejects non-positive run Gold.")
	_expect(reward_grant_service.get_run_gold() == 3, "Rejected rewards do not alter run Gold.")
	_expect(reward_grant_service.try_spend_run_gold(2, {"sink": "test"}), "Central run currency service accepts an affordable spend.")
	_expect(reward_grant_service.get_run_gold() == 1, "Run Gold spending updates only the active battle currency.")
	_expect(not reward_grant_service.try_spend_run_gold(2), "Central run currency service rejects an unaffordable spend.")
	_expect(reward_grant_service.get_run_gold() == 1, "Rejected spending does not alter run Gold.")
	_expect(reward_grant_service.grant_run_xp(7, {"source_id": "test"}) == 7, "Reward service centrally grants King XP.")
	_expect(reward_grant_service.get_run_xp() == 7, "Granted XP is stored in the active battle.")
	game_session_service.end_session({"reason": "test_complete"})
	_expect(reward_grant_service.grant_run_gold(3) == 0, "Reward service rejects grants without an active battle.")
	_expect(not reward_grant_service.try_spend_run_gold(1), "Reward service rejects spending without an active battle.")


func _test_movement_input() -> void:
	var diagonal := MovementInputResolver.resolve(Vector2.ONE, Vector2.ZERO)
	_expect(is_equal_approx(diagonal.length(), 1.0), "Keyboard diagonal input is normalized.")
	_expect(diagonal.is_equal_approx(Vector2.ONE.normalized()), "Keyboard direction is preserved after normalization.")
	var analog := Vector2(0.35, -0.2)
	_expect(MovementInputResolver.resolve(Vector2.LEFT, analog).is_equal_approx(analog), "Active joystick input takes priority over keyboard input.")
	var pointer := Vector2(0.25, 0.5)
	_expect(MovementInputResolver.resolve(Vector2.LEFT, Vector2.ZERO, pointer).is_equal_approx(pointer), "Active hold-to-move input takes priority over keyboard input.")
	_expect(MovementInputResolver.resolve(Vector2.LEFT, analog, pointer).is_equal_approx(analog), "Virtual joystick remains higher priority than hold-to-move input.")
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
	_expect(HoldMoveInput.direction_from_screen_points(Vector2(120.0, 100.0), Vector2(100.0, 100.0), 52.0, 190.0).is_zero_approx(), "Holding near the King stays inside the movement stop radius.")
	var hold_right := HoldMoveInput.direction_from_screen_points(Vector2(400.0, 100.0), Vector2(100.0, 100.0), 52.0, 190.0)
	_expect(hold_right.is_equal_approx(Vector2.RIGHT), "Holding far to the right produces full rightward movement.")
	var hold_partial := HoldMoveInput.direction_from_screen_points(Vector2(200.0, 100.0), Vector2(100.0, 100.0), 52.0, 190.0)
	_expect(hold_partial.x > 0.0 and hold_partial.x < 1.0, "Hold-to-move preserves analog strength near the King.")


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
	_expect(spawn_director != null and spawn_director.base_population == 14, "Combat arena starts with fourteen Goblins.")
	_expect(spawn_director != null and spawn_director.maximum_population == 24, "Combat arena caps simultaneous Goblins at twenty-four.")
	var army_controller := arena.get_node("ArmyController") as ArmyController
	_expect(army_controller != null, "Combat arena owns an ordinary ArmyController node.")
	var projectile_pool := arena.get_node("EnemyProjectilePool") as EnemyProjectilePool
	_expect(projectile_pool != null and projectile_pool.prewarm_count > 0, "Combat arena owns a prewarmed enemy projectile pool.")
	var ally_projectile_pool := arena.get_node("AllyProjectilePool") as AllyProjectilePool
	_expect(ally_projectile_pool != null and ally_projectile_pool.prewarm_count > 0, "Combat arena owns a prewarmed allied projectile pool.")
	var drop_director := arena.get_node("CombatDropDirector") as CombatDropDirector
	_expect(drop_director != null, "Combat arena owns a seeded combat drop director.")
	var summon_grid := arena.get_node("HudLayer/Hud/SummonMargin/SummonPanel/SummonContent/SummonGrid") as GridContainer
	var summon_template: Button
	if summon_grid != null:
		summon_template = summon_grid.get_node("SummonButtonTemplate") as Button
	_expect(summon_grid != null and summon_grid.columns == 2, "Combat HUD reserves a two-column Dai Viet summon roster.")
	_expect(summon_template != null and summon_template.custom_minimum_size.y >= 48.0, "Roster summon buttons meet the touch target baseline.")
	var army_capacity_label := arena.get_node("HudLayer/Hud/SummonMargin/SummonPanel/SummonContent/ArmyCapacityLabel") as Label
	_expect(army_capacity_label != null, "Combat HUD displays the unlimited living army count.")
	var upgrade_grid := arena.get_node("HudLayer/Hud/SummonMargin/SummonPanel/SummonContent/UpgradeGrid") as GridContainer
	_expect(upgrade_grid != null and upgrade_grid.columns == 2, "Combat HUD reserves data-driven unit upgrade controls.")
	var xp_bar := arena.get_node("HudLayer/Hud/TopMargin/TopPanel/TopRow/Telemetry/XpBar") as ProgressBar
	_expect(xp_bar != null, "Combat HUD displays King level and XP progress.")
	var level_overlay := arena.get_node("HudLayer/LevelUpOverlay") as Control
	_expect(level_overlay != null and level_overlay.process_mode == Node.PROCESS_MODE_ALWAYS, "Level-up choices remain interactive while battle simulation is paused.")
	_expect(
		not SummonedUnitPlaceholderVisual.HEALTH_BAR_FILL_COLOR.is_equal_approx(KingPlaceholderVisual.HEALTH_BAR_FILL_COLOR)
		and not SummonedUnitPlaceholderVisual.HEALTH_BAR_FILL_COLOR.is_equal_approx(GoblinPlaceholderVisual.HEALTH_BAR_FILL_COLOR),
		"Summoned units use a health bar color distinct from King and Goblins."
	)
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
	var enemy_attack_visual_script := _read_text("res://scripts/combat/enemy_attack_visual.gd")
	_expect(arena_script.contains("king.clear_movement_bounds()"), "Combat arena explicitly enables unbounded King movement.")
	_expect(not arena_script.contains("ARENA_RECT"), "Combat arena no longer defines a finite arena rectangle.")
	_expect(not backdrop_script.contains("arena_rect"), "Backdrop no longer draws a finite boundary.")
	_expect(arena_script.contains("EFFECTIVE_CAMERA_LIMIT := 2147480000"), "Camera limits are effectively unbounded for gameplay travel.")
	_expect(not enemy_attack_visual_script.contains("draw_dashed_line"), "Goblin ranged attacks no longer reveal a dashed aiming path.")


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
	var healing := HealingResolver.apply_healing(defended_health, 30.0, {"source_id": "test_heal"})
	_expect(bool(healing.get("accepted", false)), "Healing resolver accepts recovery for a living damaged target.")
	_expect(is_equal_approx(float(healing.get("applied", 0.0)), 30.0), "Healing resolver reports applied recovery.")
	_expect(is_equal_approx(defended_health.current_health, 84.0), "Resolved healing restores health without exceeding maximum health.")
	var capped_healing := HealingResolver.apply_healing(defended_health, 999.0)
	_expect(is_equal_approx(float(capped_healing.get("applied", 0.0)), 16.0), "Healing is clamped at maximum health.")
	_expect(not bool(HealingResolver.apply_healing(defended_health, 10.0).get("accepted", true)), "Healing resolver rejects recovery at full health.")
	defense.free()
	defended_health.free()


func _test_healing_orb_pickup() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_orb := load("res://scenes/gameplay/healing_orb_pickup.tscn") as PackedScene
	var packed_unit := load("res://scenes/gameplay/summoned_unit.tscn") as PackedScene
	if packed_king == null or packed_orb == null or packed_unit == null:
		_expect(false, "Healing Orb integration fixtures load.")
		return
	var king := packed_king.instantiate() as KingController
	var orb := packed_orb.instantiate() as HealingOrbPickup
	king.global_position = Vector2.ZERO
	orb.global_position = Vector2.ZERO
	root.add_child(king)
	root.add_child(orb)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	orb.configure("healing_orb_test", 0.14)
	for _frame in 3:
		await physics_frame
	_expect(is_instance_valid(orb) and not orb.is_queued_for_deletion(), "A full-health King does not consume a Healing Orb.")
	DamageResolver.apply_damage(king.health, 100.0, {"damage_type": "physical"})
	var damaged_health := king.health.current_health
	orb.global_position = Vector2(120.0, 0.0)
	for _frame in 2:
		await physics_frame
	orb.global_position = king.global_position
	for _frame in 3:
		await physics_frame
	_expect(king.health.current_health > damaged_health, "A damaged King collects a Healing Orb and recovers health.")
	_expect(is_equal_approx(king.health.current_health, damaged_health + king.health.max_health * 0.14), "Healing Orb restores its configured maximum-health fraction.")
	_expect(king.visual.is_heal_feedback_active(), "King displays green recovery feedback after collecting a Healing Orb.")
	_expect(not is_instance_valid(orb) or orb.is_queued_for_deletion(), "A successfully collected Healing Orb is consumed.")
	HealingResolver.apply_healing(king.health, 999.0)
	var allied_unit := packed_unit.instantiate() as SummonedUnitController
	var unit_orb := packed_orb.instantiate() as HealingOrbPickup
	allied_unit.global_position = Vector2(500.0, 0.0)
	unit_orb.global_position = allied_unit.global_position
	root.add_child(allied_unit)
	root.add_child(unit_orb)
	await process_frame
	var unit_config: Dictionary = root.get_node("ContentDatabase").get_unit(&"dai_viet_spearman")
	allied_unit.configure(unit_config, "healing_orb_ally", king)
	allied_unit.set_combat_enabled(false)
	unit_orb.configure("healing_orb_unit_test", 0.2)
	DamageResolver.apply_damage(allied_unit.health, 60.0, {"damage_type": "physical"})
	DamageResolver.apply_damage(king.health, 10.0, {"damage_type": "physical"})
	var wounded_unit_health := allied_unit.health.current_health
	unit_orb.call("_on_body_entered", allied_unit)
	_expect(is_equal_approx(allied_unit.health.current_health, wounded_unit_health), "A soldier cannot take a Healing Orb while the King still needs recovery.")
	_expect(is_instance_valid(unit_orb) and not unit_orb.is_queued_for_deletion(), "Healing Orb remains available while a wounded King has priority.")
	HealingResolver.apply_healing(king.health, 999.0)
	unit_orb.call("_on_body_entered", allied_unit)
	_expect(allied_unit.health.current_health > wounded_unit_health, "A wounded soldier collects a Healing Orb once the King is at full health.")
	_expect(allied_unit.visual.is_heal_feedback_active(), "Soldier displays green recovery feedback after collecting a Healing Orb.")
	_expect(not is_instance_valid(unit_orb) or unit_orb.is_queued_for_deletion(), "Soldier recovery consumes the Healing Orb.")
	allied_unit.queue_free()
	king.queue_free()
	await process_frame


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

	king.global_position = Vector2.ZERO
	king.set_virtual_direction(Vector2.ZERO)
	king.set_pointer_direction(Vector2.LEFT)
	for _frame in 4:
		await physics_frame
	_expect(king.global_position.x < 0.0, "Hold-to-move direction moves the King while keyboard input is disabled.")
	_expect(absf(king.global_position.y) < 0.01, "Pointer horizontal movement does not drift vertically.")
	king.set_pointer_direction(Vector2.ZERO)

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


func _test_king_piercing_attacks() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	if packed_king == null or packed_goblin == null:
		_expect(false, "King piercing combat fixtures load.")
		return
	var content_database := root.get_node("ContentDatabase")
	var king_data: Dictionary = content_database.get_king(&"tran_hung_dao")
	var enemy_data: Dictionary = content_database.get_enemy(&"goblin")

	var melee_king := packed_king.instantiate() as KingController
	var near_melee := packed_goblin.instantiate() as GoblinController
	var far_melee := packed_goblin.instantiate() as GoblinController
	melee_king.global_position = Vector2.ZERO
	near_melee.global_position = Vector2(90.0, 0.0)
	far_melee.global_position = Vector2(155.0, 8.0)
	root.add_child(melee_king)
	root.add_child(near_melee)
	root.add_child(far_melee)
	await process_frame
	melee_king.follow_camera.enabled = false
	melee_king.set_keyboard_enabled(false)
	melee_king.set_movement_enabled(false)
	melee_king.configure(king_data)
	var one_slash: Dictionary = king_data.get("attack", {}).duplicate(true)
	one_slash["damage"] = 20.0
	one_slash["cooldown"] = 10.0
	melee_king.auto_attack.configure(one_slash, king_data.get("weapon_archetype", {}))
	near_melee.configure(enemy_data, "piercing_melee_near")
	far_melee.configure(enemy_data, "piercing_melee_far")
	near_melee.set_combat_enabled(false)
	far_melee.set_combat_enabled(false)
	var near_melee_health := near_melee.health.current_health
	var far_melee_health := far_melee.health.current_health
	for _frame in 5:
		await physics_frame
	_expect(near_melee.health.current_health < near_melee_health, "One King slash damages the first Goblin in its arc.")
	_expect(far_melee.health.current_health < far_melee_health, "The same King slash passes through and damages a second Goblin.")
	melee_king.queue_free()
	near_melee.queue_free()
	far_melee.queue_free()
	await process_frame

	var ranged_king := packed_king.instantiate() as KingController
	var near_ranged := packed_goblin.instantiate() as GoblinController
	var far_ranged := packed_goblin.instantiate() as GoblinController
	var projectile_pool := AllyProjectilePool.new()
	projectile_pool.prewarm_count = 4
	ranged_king.global_position = Vector2.ZERO
	near_ranged.global_position = Vector2(170.0, 0.0)
	far_ranged.global_position = Vector2(310.0, 0.0)
	root.add_child(projectile_pool)
	root.add_child(ranged_king)
	root.add_child(near_ranged)
	root.add_child(far_ranged)
	await process_frame
	ranged_king.follow_camera.enabled = false
	ranged_king.set_keyboard_enabled(false)
	ranged_king.set_movement_enabled(false)
	var ranged_data: Dictionary = king_data.duplicate(true)
	ranged_data["weapon_archetype"] = {
		"id": "bow",
		"attack_style": "ranged",
		"damage_type": "physical",
		"visual_kind": "bow",
	}
	var ranged_attack: Dictionary = ranged_data.get("attack", {}).duplicate(true)
	ranged_attack["damage"] = 20.0
	ranged_attack["range"] = 640.0
	ranged_attack["cooldown"] = 10.0
	ranged_data["attack"] = ranged_attack
	ranged_king.configure(ranged_data)
	ranged_king.auto_attack.set_projectile_pool(projectile_pool)
	near_ranged.configure(enemy_data, "piercing_ranged_near")
	far_ranged.configure(enemy_data, "piercing_ranged_far")
	near_ranged.set_combat_enabled(false)
	far_ranged.set_combat_enabled(false)
	var near_ranged_health := near_ranged.health.current_health
	var far_ranged_health := far_ranged.health.current_health
	for _frame in 32:
		await physics_frame
	_expect(near_ranged.health.current_health < near_ranged_health, "One King arrow damages the first Goblin in its path.")
	_expect(far_ranged.health.current_health < far_ranged_health, "The same King arrow remains active and damages a second Goblin.")
	_expect(projectile_pool.get_active_count() == 1, "Unlimited-piercing King projectile remains active after hitting multiple targets.")
	projectile_pool.set_combat_enabled(false)
	ranged_king.queue_free()
	near_ranged.queue_free()
	far_ranged.queue_free()
	projectile_pool.queue_free()
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
	var projectile_pool := EnemyProjectilePool.new()
	projectile_pool.prewarm_count = 2
	projectile_pool.maximum_count = 4
	root.add_child(projectile_pool)
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
	var controlled_attack: Dictionary = hexer_data.get("attack", {}).duplicate(true)
	controlled_attack["attacks_per_second"] = 0.2
	hexer_data["attack"] = controlled_attack
	hexer.configure(hexer_data, "magic_integration_goblin")
	hexer.set_target(king)
	hexer.projectile_requested.connect(projectile_pool.request_projectile)
	var starting_health := king.health.current_health
	for _frame in 10:
		await physics_frame
	_expect(hexer.is_engaged(), "Goblin Hexer engages when the King enters its individual hatred range.")
	_expect(hexer.attack_style == "ranged", "Goblin Hexer uses a ranged attack style.")
	_expect(hexer.damage_type == "magic", "Goblin Hexer deals magic damage.")
	_expect(hexer.attack_visual.attack_style == "ranged" and hexer.attack_visual.damage_type == "magic", "Goblin Hexer uses the ranged magic attack visual.")
	_expect(is_equal_approx(king.health.current_health, starting_health), "Ranged Goblin telegraph does not apply instant damage.")
	_expect(projectile_pool.get_active_count() == 0, "Ranged Goblin has not released a projectile before its windup completes.")
	for _frame in 28:
		await physics_frame
	_expect(projectile_pool.get_active_count() == 1, "Goblin Hexer releases one pooled projectile after telegraphing.")
	_expect(is_equal_approx(king.health.current_health, starting_health), "Projectile travel time leaves a window for the King to dodge.")
	for _frame in 55:
		await physics_frame
	_expect(king.health.current_health < starting_health, "A real magic projectile damages the stationary King on collision.")
	_expect(projectile_pool.get_total_created() == 2, "Projectile pool reuses its prewarmed lightweight objects.")

	hexer.set_combat_enabled(false)
	HealingResolver.apply_healing(king.health, 999.0)
	var health_before_dodge := king.health.current_health
	king.global_position = Vector2.ZERO
	var missed_projectile := projectile_pool.request_projectile({
		"projectile_id": "dodge_test",
		"position": Vector2(-220.0, 0.0),
		"direction": Vector2.RIGHT,
		"speed": 500.0,
		"radius": 5.0,
		"lifetime": 0.8,
		"visual_kind": "arrow",
		"damage": 20.0,
		"damage_type": "physical",
		"context": {"source_kind": "enemy", "attack_style": "ranged", "damage_type": "physical"},
	})
	_expect(missed_projectile != null, "Projectile pool accepts a dodge test shot.")
	king.global_position = Vector2(0.0, 140.0)
	for _frame in 55:
		await physics_frame
	_expect(is_equal_approx(king.health.current_health, health_before_dodge), "King can sidestep a projectile whose direction was locked when fired.")
	_expect(projectile_pool.get_active_count() == 0, "A missed projectile expires and returns to the pool.")
	king.queue_free()
	hexer.queue_free()
	projectile_pool.queue_free()
	await process_frame


func _test_spearman_combat() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	var packed_unit := load("res://scenes/gameplay/summoned_unit.tscn") as PackedScene
	if packed_king == null or packed_goblin == null or packed_unit == null:
		_expect(false, "Spearman combat fixtures load.")
		return
	var king := packed_king.instantiate() as KingController
	var goblin := packed_goblin.instantiate() as GoblinController
	var spearman := packed_unit.instantiate() as SummonedUnitController
	king.global_position = Vector2.ZERO
	spearman.global_position = Vector2(600.0, 0.0)
	goblin.global_position = Vector2(660.0, 0.0)
	root.add_child(king)
	root.add_child(goblin)
	root.add_child(spearman)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	var king_data: Dictionary = _load_json("res://data/kings/kings.json").get("kings", [])[0]
	var enemy_data: Dictionary = _load_json("res://data/enemies/enemies.json").get("enemies", [])[0]
	var unit_data: Dictionary = _load_json("res://data/units/units.json").get("units", [])[0]
	king.configure(king_data)
	king.auto_attack.set_combat_enabled(false)
	goblin.configure(enemy_data, "spearman_target_goblin")
	goblin.set_target(king)
	spearman.configure(unit_data, "ally_combat_test", king)
	spearman.set_formation_offset(Vector2(600.0, 0.0))
	var goblin_starting_health := goblin.health.current_health
	var spearman_starting_health := spearman.health.current_health
	for _frame in 12:
		await physics_frame
	_expect(goblin.health.current_health < goblin_starting_health, "Summoned Spearman automatically attacks a nearby Goblin.")
	_expect(goblin.is_engaged(), "A Goblin becomes engaged when an allied unit attacks outside its hatred range.")
	_expect(spearman.health.current_health < spearman_starting_health, "An alerted Goblin can retaliate against the allied attacker.")
	_expect(is_equal_approx(spearman.visual.get_health_ratio(), spearman.health.get_ratio()), "Spearman overhead health follows its health component.")
	_expect(spearman.get_formation_world_position().is_equal_approx(Vector2(600.0, 0.0)), "Spearman owns a King-relative formation slot.")
	king.queue_free()
	goblin.queue_free()
	spearman.queue_free()
	await process_frame


func _test_ally_ranged_combat() -> void:
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	var packed_unit := load("res://scenes/gameplay/summoned_unit.tscn") as PackedScene
	if packed_king == null or packed_goblin == null or packed_unit == null:
		_expect(false, "Allied ranged combat fixtures load.")
		return
	var projectile_pool := AllyProjectilePool.new()
	projectile_pool.prewarm_count = 2
	projectile_pool.maximum_count = 4
	root.add_child(projectile_pool)
	var king := packed_king.instantiate() as KingController
	var goblin := packed_goblin.instantiate() as GoblinController
	var crossbowman := packed_unit.instantiate() as SummonedUnitController
	king.global_position = Vector2.ZERO
	crossbowman.global_position = Vector2(400.0, 0.0)
	goblin.global_position = Vector2(700.0, 0.0)
	root.add_child(king)
	root.add_child(goblin)
	root.add_child(crossbowman)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.auto_attack.set_combat_enabled(false)
	var content_database := root.get_node("ContentDatabase")
	king.configure(content_database.get_king(&"tran_hung_dao"))
	king.auto_attack.set_combat_enabled(false)
	var goblin_data: Dictionary = content_database.get_enemy(&"goblin")
	goblin.configure(goblin_data, "crossbow_target")
	goblin.set_combat_enabled(false)
	var crossbow_data: Dictionary = content_database.get_unit(&"dai_viet_crossbowman")
	crossbowman.configure(crossbow_data, "ally_crossbow_test", king, -1.0, projectile_pool)
	crossbowman.set_formation_offset(Vector2(400.0, 0.0))
	var starting_health := goblin.health.current_health
	for _frame in 8:
		await physics_frame
	_expect(projectile_pool.get_active_count() == 1, "Crossbowman releases one pooled physical bolt.")
	_expect(is_equal_approx(goblin.health.current_health, starting_health), "Allied ranged attacks have travel time instead of instant damage.")
	for _frame in 25:
		await physics_frame
	_expect(goblin.health.current_health < starting_health, "Crossbow bolt damages a Goblin through the shared resolver on collision.")
	_expect(projectile_pool.get_total_created() == 2, "Allied projectile pool reuses its prewarmed lightweight objects.")
	projectile_pool.set_combat_enabled(false)
	king.queue_free()
	goblin.queue_free()
	crossbowman.queue_free()
	projectile_pool.queue_free()
	await process_frame


func _test_army_summoning_and_restore() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	var content_database := root.get_node("ContentDatabase")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 13579)
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var king := packed_king.instantiate() as KingController
	root.add_child(king)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.auto_attack.set_combat_enabled(false)
	king.configure(content_database.get_king(&"tran_hung_dao"))
	king.auto_attack.set_combat_enabled(false)
	var unit_configs := {"dai_viet_spearman": content_database.get_unit(&"dai_viet_spearman")}
	var army := ArmyController.new()
	root.add_child(army)
	army.configure(king, 4, unit_configs)
	var spearman_cost := int(unit_configs["dai_viet_spearman"].get("summon", {}).get("run_gold_cost", 0))
	reward_grant_service.grant_run_gold(spearman_cost * 3, {"source_id": "army_test"})
	var first_result := army.try_summon(&"dai_viet_spearman")
	var second_result := army.try_summon(&"dai_viet_spearman")
	var blocked_result := army.try_summon(&"dai_viet_spearman")
	_expect(bool(first_result.get("accepted", false)) and bool(second_result.get("accepted", false)), "Army controller summons affordable Spearmen.")
	_expect(not bool(blocked_result.get("accepted", true)) and blocked_result.get("reason") == "capacity_full", "Army Capacity blocks summons beyond the configured maximum.")
	_expect(army.get_living_unit_count() == 2, "Army controller tracks living summoned units.")
	_expect(army.get_used_capacity() == 4, "Two Spearmen consume four Army Capacity.")
	_expect(reward_grant_service.get_run_gold() == spearman_cost, "Successful summons spend run Gold while a blocked summon does not.")
	var units := army.get_units()
	DamageResolver.apply_damage(units[0].health, 20.0, {"damage_type": "physical"}, units[0].defense)
	var restored_health := units[0].health.current_health
	var snapshot := army.get_army_snapshot()
	game_session_service.set_army_state(snapshot)
	_expect(snapshot.size() == 2 and game_session_service.get_army_state().size() == 2, "Army snapshots are stored in the active BattleSession.")
	army.queue_free()
	await process_frame
	var restored_army := ArmyController.new()
	root.add_child(restored_army)
	restored_army.configure(king, 4, unit_configs, game_session_service.get_army_state())
	_expect(restored_army.get_living_unit_count() == 2, "Continue restores every living summoned Spearman.")
	_expect(restored_army.get_used_capacity() == 4, "Continue restores used Army Capacity.")
	var restored_units := restored_army.get_units()
	_expect(is_equal_approx(restored_units[0].health.current_health, restored_health), "Continue restores allied unit health.")
	restored_army.queue_free()
	king.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


func _test_dai_viet_roster_summoning() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	var content_database := root.get_node("ContentDatabase")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 24680)
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var king := packed_king.instantiate() as KingController
	root.add_child(king)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.configure(content_database.get_king(&"tran_hung_dao"))
	king.auto_attack.set_combat_enabled(false)
	var unit_configs: Dictionary = {}
	var total_gold_cost := 0
	var total_capacity_cost := 0
	for unit_id in content_database.get_unit_ids_for_faction(&"dai_viet"):
		var config: Dictionary = content_database.get_unit(StringName(unit_id))
		unit_configs[unit_id] = config
		var summon_data: Dictionary = config.get("summon", {})
		total_gold_cost += int(summon_data.get("run_gold_cost", 0))
		total_capacity_cost += int(summon_data.get("capacity_cost", 0))
	var projectile_pool := AllyProjectilePool.new()
	projectile_pool.prewarm_count = 2
	root.add_child(projectile_pool)
	var army := ArmyController.new()
	root.add_child(army)
	army.configure(king, 100, unit_configs, [], projectile_pool)
	reward_grant_service.grant_run_gold(total_gold_cost, {"source_id": "dai_viet_roster_test"})
	var accepted_ids: Dictionary = {}
	for unit_id in unit_configs:
		var result := army.try_summon(StringName(unit_id))
		if bool(result.get("accepted", false)):
			accepted_ids[unit_id] = true
		_expect(bool(result.get("accepted", false)), "Army controller summons Dai Viet roster unit: %s" % unit_id)
	_expect(accepted_ids.size() == 7 and army.get_living_unit_count() == 7, "All seven Dai Viet unit types can coexist in the battle army.")
	_expect(army.get_used_capacity() == total_capacity_cost and total_capacity_cost == 24, "Full Dai Viet roster consumes its data-driven Army Capacity.")
	_expect(reward_grant_service.get_run_gold() == 0, "Summoning the full roster spends exactly the data-driven run Gold total.")
	var ranged_offsets: Array[Vector2] = []
	var seen_attack_styles: Dictionary = {}
	for unit in army.get_units():
		seen_attack_styles[unit.attack_style] = true
		if unit.unit_id in [&"dai_viet_crossbowman", &"dai_viet_ambush_archer"]:
			ranged_offsets.append(unit.get_formation_world_position() - king.global_position)
	_expect(seen_attack_styles.has("melee") and seen_attack_styles.has("ranged"), "Summoned roster includes working melee and ranged controllers.")
	_expect(ranged_offsets.size() == 2 and not ranged_offsets[0].is_equal_approx(ranged_offsets[1]), "Ranged units receive separate slots within their shared formation ring.")
	_expect(army.get_army_snapshot().size() == 7, "Continue snapshot serializes every living Dai Viet unit type.")
	army.set_combat_enabled(false)
	projectile_pool.set_combat_enabled(false)
	army.queue_free()
	projectile_pool.queue_free()
	king.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


func _test_unlimited_army_upgrade() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	var content_database := root.get_node("ContentDatabase")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 54321)
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var king := packed_king.instantiate() as KingController
	root.add_child(king)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.configure(content_database.get_king(&"tran_hung_dao"))
	king.auto_attack.set_combat_enabled(false)
	var spearman_config: Dictionary = content_database.get_unit(&"dai_viet_spearman")
	var unit_configs := {"dai_viet_spearman": spearman_config}
	var summon_cost := int(spearman_config.get("summon", {}).get("run_gold_cost", 0))
	var upgrade_cost := int(spearman_config.get("upgrade", {}).get("base_gold_cost", 0))
	reward_grant_service.grant_run_gold(summon_cost * 3 + upgrade_cost, {"source_id": "unlimited_upgrade_test"})
	var army := ArmyController.new()
	root.add_child(army)
	army.configure(king, 1, unit_configs, [], null, true)
	var first := army.try_summon(&"dai_viet_spearman")
	var second := army.try_summon(&"dai_viet_spearman")
	_expect(bool(first.get("accepted", false)) and bool(second.get("accepted", false)), "Unlimited summons ignore the old living Army Capacity ceiling.")
	_expect(army.get_used_capacity() > army.maximum_capacity, "Unlimited army may exceed the legacy capacity number.")
	var first_unit := army.get_units()[0]
	var base_health := first_unit.health.max_health
	var base_damage := first_unit.attack_damage
	var upgrade_result := army.try_upgrade(&"dai_viet_spearman")
	_expect(bool(upgrade_result.get("accepted", false)) and army.get_upgrade_level(&"dai_viet_spearman") == 1, "Run Gold upgrades a whole soldier type.")
	_expect(first_unit.health.max_health > base_health and first_unit.attack_damage > base_damage, "Unit upgrade immediately strengthens existing soldiers.")
	var third := army.try_summon(&"dai_viet_spearman")
	_expect(bool(third.get("accepted", false)) and army.get_living_unit_count() == 3, "Summoning stays available without a fixed soldier count.")
	var newest_unit := third.get("unit") as SummonedUnitController
	_expect(newest_unit != null and newest_unit.get_upgrade_level() == 1, "New summons inherit their unit type's purchased upgrade.")
	var snapshots := army.get_army_snapshot()
	_expect(snapshots.size() == 3 and int(snapshots[0].get("upgrade_level", 0)) == 1, "Continue snapshot records upgraded soldiers.")
	_expect(int(game_session_service.get_army_upgrade_state().get("dai_viet_spearman", 0)) == 1, "Battle session stores the unit upgrade level separately from living soldiers.")
	_expect(reward_grant_service.get_run_gold() == 0, "Summons and upgrades spend exactly their configured run Gold costs.")
	army.queue_free()
	king.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


func _test_king_level_and_skills() -> void:
	var game_session_service := root.get_node("GameSessionService")
	var reward_grant_service := root.get_node("RewardGrantService")
	var content_database := root.get_node("ContentDatabase")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 98765)
	var packed_king := load("res://scenes/gameplay/king.tscn") as PackedScene
	var packed_goblin := load("res://scenes/gameplay/goblin.tscn") as PackedScene
	var king := packed_king.instantiate() as KingController
	var projectile_pool := AllyProjectilePool.new()
	var skill_runtime := KingSkillRuntime.new()
	var progression := KingProgressionController.new()
	root.add_child(projectile_pool)
	root.add_child(king)
	root.add_child(skill_runtime)
	root.add_child(progression)
	await process_frame
	king.follow_camera.enabled = false
	king.set_keyboard_enabled(false)
	king.set_movement_enabled(false)
	king.configure(content_database.get_king(&"tran_hung_dao"))
	king.auto_attack.set_combat_enabled(false)
	var skill_configs: Dictionary = {}
	for skill_id in content_database.get_king_skill_ids():
		skill_configs[str(skill_id)] = content_database.get_king_skill(StringName(skill_id))
	skill_runtime.configure(king, projectile_pool, skill_configs)
	progression.configure(
		game_session_service.active_session.seed,
		content_database.get_king_progression_config(),
		skill_configs,
		skill_runtime
	)
	var xp_required := progression.get_xp_required()
	reward_grant_service.grant_run_xp(xp_required, {"source_id": "level_test"})
	_expect(progression.get_run_level() == 2 and progression.get_run_xp() == 0, "Enough enemy XP advances the King and consumes the level threshold.")
	_expect(progression.is_selection_pending() and progression.get_current_choices().size() == 3, "A new King level creates three seeded skill choices.")
	_expect(game_session_service.pause_manager.is_paused() and paused, "King level-up pauses the whole battle simulation.")
	var choices := progression.get_current_choices()
	if not choices.is_empty():
		var selected_id := StringName(str(choices[0].get("id", "")))
		_expect(progression.select_skill(selected_id), "Choosing a level-up card applies that King skill.")
		_expect(skill_runtime.get_skill_level(selected_id) == 1, "Selected King skill advances to rank one.")
		_expect(int(game_session_service.get_skill_state().get(str(selected_id), 0)) == 1, "Continue state stores the selected King skill rank.")
	_expect(not game_session_service.pause_manager.is_paused() and not paused, "Selecting a skill resumes battle simulation.")

	var near_goblin := packed_goblin.instantiate() as GoblinController
	var far_goblin := packed_goblin.instantiate() as GoblinController
	near_goblin.global_position = Vector2(170.0, 0.0)
	far_goblin.global_position = Vector2(300.0, 0.0)
	root.add_child(near_goblin)
	root.add_child(far_goblin)
	await process_frame
	var enemy_config: Dictionary = content_database.get_enemy(&"goblin")
	near_goblin.configure(enemy_config, "skill_piercing_near")
	far_goblin.configure(enemy_config, "skill_piercing_far")
	near_goblin.set_combat_enabled(false)
	far_goblin.set_combat_enabled(false)
	var near_health := near_goblin.health.current_health
	var far_health := far_goblin.health.current_health
	var wave_config: Dictionary = skill_configs.get("piercing_wave", {})
	var wave_levels: Array = wave_config.get("levels", [])
	if not wave_levels.is_empty():
		skill_runtime.call("_cast_piercing_wave", &"piercing_wave", wave_levels[0])
	for _frame in 34:
		await physics_frame
	_expect(near_goblin.health.current_health < near_health, "King piercing skill damages the first Goblin in its path.")
	_expect(far_goblin.health.current_health < far_health, "The same King skill projectile passes through and damages another Goblin.")
	game_session_service.pause_manager.clear_pause(PauseManager.LEVEL_UP)
	projectile_pool.set_combat_enabled(false)
	near_goblin.queue_free()
	far_goblin.queue_free()
	progression.queue_free()
	skill_runtime.queue_free()
	projectile_pool.queue_free()
	king.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


func _test_healing_orb_continue() -> void:
	var game_session_service := root.get_node("GameSessionService")
	game_session_service.start_session(&"tran_hung_dao", &"dai_viet", 13579)
	var packed_arena := load("res://scenes/gameplay/movement_arena.tscn") as PackedScene
	if packed_arena == null:
		_expect(false, "Healing Orb Continue arena fixture loads.")
		game_session_service.end_session({"reason": "test_failed"})
		return
	var arena := packed_arena.instantiate()
	root.add_child(arena)
	await process_frame
	var arena_king := arena.get_node("King") as KingController
	arena_king.follow_camera.enabled = false
	arena_king.set_keyboard_enabled(false)
	arena_king.auto_attack.set_combat_enabled(false)
	(arena.get_node("EnemySpawnDirector") as EnemySpawnDirector).set_active(false)
	for child in arena.get_children():
		if child is GoblinController:
			(child as GoblinController).set_combat_enabled(false)
	var saved_position := arena_king.global_position + Vector2(320.0, -90.0)
	arena.call("_create_healing_pickup", "healing_orb_continue", saved_position, 0.18)
	arena.call("_store_combat_state")
	var stored_state: Dictionary = game_session_service.get_enemy_combat_state()
	var stored_healing: Array = stored_state.get("healing_pickups", [])
	_expect(stored_healing.size() == 1, "Battle snapshot stores every uncollected Healing Orb.")
	_expect(stored_state.get("drop_runtime_state", {}) is Dictionary and not stored_state.get("drop_runtime_state", {}).is_empty(), "Battle snapshot stores deterministic healing-drop RNG state.")
	arena.queue_free()
	await process_frame

	var restored_arena := packed_arena.instantiate()
	root.add_child(restored_arena)
	await process_frame
	var restored_king := restored_arena.get_node("King") as KingController
	restored_king.follow_camera.enabled = false
	restored_king.set_keyboard_enabled(false)
	restored_king.auto_attack.set_combat_enabled(false)
	(restored_arena.get_node("EnemySpawnDirector") as EnemySpawnDirector).set_active(false)
	var restored_orb: HealingOrbPickup
	for child in restored_arena.get_children():
		if child is GoblinController:
			(child as GoblinController).set_combat_enabled(false)
		elif child is HealingOrbPickup and (child as HealingOrbPickup).pickup_id == "healing_orb_continue":
			restored_orb = child as HealingOrbPickup
	_expect(restored_orb != null, "Continue restores an uncollected Healing Orb.")
	if restored_orb != null:
		_expect(restored_orb.global_position.is_equal_approx(saved_position), "Continue restores the Healing Orb world position.")
		_expect(is_equal_approx(restored_orb.max_health_fraction, 0.18), "Continue restores the Healing Orb recovery fraction.")
	restored_arena.queue_free()
	await process_frame
	game_session_service.end_session({"reason": "test_complete"})


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
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 3
	touch_press.pressed = true
	touch_press.position = get_root().get_canvas_transform() * arena_king.global_position + Vector2(300.0, 0.0)
	var touch_start_position := arena_king.global_position
	arena.call("_unhandled_input", touch_press)
	for _frame in 4:
		await physics_frame
	_expect(arena_king.global_position.x > touch_start_position.x, "Holding an unconsumed screen touch moves the King toward that side of the screen.")
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 3
	touch_release.pressed = false
	touch_release.position = touch_press.position
	arena.call("_input", touch_release)
	var position_after_touch_release := arena_king.global_position
	for _frame in 3:
		await physics_frame
	_expect(arena_king.global_position.is_equal_approx(position_after_touch_release), "Releasing the movement touch stops pointer movement.")
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = get_root().get_canvas_transform() * arena_king.global_position + Vector2(0.0, 300.0)
	var mouse_start_position := arena_king.global_position
	arena.call("_unhandled_input", mouse_press)
	for _frame in 4:
		await physics_frame
	_expect(arena_king.global_position.y > mouse_start_position.y, "Holding the left mouse button moves the King toward the held screen position.")
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = mouse_press.position
	arena.call("_input", mouse_release)
	var position_after_mouse_release := arena_king.global_position
	for _frame in 3:
		await physics_frame
	_expect(arena_king.global_position.is_equal_approx(position_after_mouse_release), "Releasing the left mouse button stops pointer movement.")
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
	_expect(initial_goblins.size() == 14, "Endless encounter starts with fourteen simultaneously active Goblins.")
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
	var spearman_config: Dictionary = root.get_node("ContentDatabase").get_unit(&"dai_viet_spearman")
	var summon_cost := int(spearman_config.get("summon", {}).get("run_gold_cost", 0))
	var missing_gold := maxi(summon_cost - reward_grant_service.get_run_gold(), 0)
	if missing_gold > 0:
		reward_grant_service.grant_run_gold(missing_gold, {"source_id": "summon_ui_test"})
	var arena_army := arena.get_node("ArmyController") as ArmyController
	var summon_grid := arena.get_node("HudLayer/Hud/SummonMargin/SummonPanel/SummonContent/SummonGrid") as GridContainer
	var summon_button: Button
	for child in summon_grid.get_children():
		if child is Button and str(child.get_meta("unit_id", "")) == "dai_viet_spearman":
			summon_button = child as Button
			break
	_expect(summon_grid.get_child_count() == 8, "Combat HUD builds seven Dai Viet summon buttons from data.")
	_expect(summon_button != null and not summon_button.disabled, "Spearman summon button enables when enough run Gold is available.")
	if summon_button != null:
		summon_button.pressed.emit()
	arena_army.set_combat_enabled(false)
	_expect(arena_army.get_living_unit_count() == 1, "Combat HUD summons a Spearman into the battle-owned army.")
	_expect(reward_grant_service.get_run_gold() == 0, "HUD summoning spends the configured run Gold cost.")
	for _frame in 110:
		await physics_frame
		for child in arena.get_children():
			if child is GoblinController:
				(child as GoblinController).set_combat_enabled(false)
	var living_goblins := 0
	for child in arena.get_children():
		if child is GoblinController and child.is_combat_alive():
			living_goblins += 1
	_expect(living_goblins == 14, "A replacement Goblin restores the denser bounded endless encounter population.")
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
