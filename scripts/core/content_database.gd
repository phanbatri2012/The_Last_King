extends Node

const FACTION_ROSTER_PATH := "res://data/factions/faction_roster.json"
const KING_CATALOG_PATH := "res://data/kings/kings.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/enemies.json"
const GOBLIN_THREAT_PATH := "res://data/enemies/goblin_threat_progression.json"
const WEAPON_ARCHETYPE_PATH := "res://data/combat/weapon_archetypes.json"
const UNIT_CATALOG_PATH := "res://data/units/units.json"
const KING_SKILL_CATALOG_PATH := "res://data/skills/king_skills.json"

var factions: Dictionary = {}
var kings: Dictionary = {}
var enemies: Dictionary = {}
var units: Dictionary = {}
var weapon_archetypes: Dictionary = {}
var king_skills: Dictionary = {}
var king_progression: Dictionary = {}
var goblin_threat_progression: Dictionary = {}
var content_version := ""
var enemy_content_version := ""
var weapon_content_version := ""
var unit_content_version := ""
var skill_content_version := ""
var threat_content_version := ""
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	factions.clear()
	kings.clear()
	enemies.clear()
	units.clear()
	weapon_archetypes.clear()
	king_skills.clear()
	king_progression.clear()
	goblin_threat_progression.clear()

	var faction_source := _load_json(FACTION_ROSTER_PATH)
	if faction_source.is_empty() or not faction_source.get("factions", null) is Array:
		push_error("Faction roster is missing or invalid.")
		return false
	var king_source := _load_json(KING_CATALOG_PATH)
	if king_source.is_empty() or not king_source.get("kings", null) is Array:
		push_error("King catalog is missing or invalid.")
		return false
	var enemy_source := _load_json(ENEMY_CATALOG_PATH)
	if enemy_source.is_empty() or not enemy_source.get("enemies", null) is Array:
		push_error("Enemy catalog is missing or invalid.")
		return false
	var threat_source := _load_json(GOBLIN_THREAT_PATH)
	if threat_source.is_empty() or not threat_source.get("phases", null) is Array or not threat_source.get("bosses", null) is Array:
		push_error("Goblin threat progression is missing or invalid.")
		return false
	var weapon_source := _load_json(WEAPON_ARCHETYPE_PATH)
	if weapon_source.is_empty() or not weapon_source.get("archetypes", null) is Array:
		push_error("Weapon archetype catalog is missing or invalid.")
		return false
	var unit_source := _load_json(UNIT_CATALOG_PATH)
	if unit_source.is_empty() or not unit_source.get("units", null) is Array:
		push_error("Unit catalog is missing or invalid.")
		return false
	var skill_source := _load_json(KING_SKILL_CATALOG_PATH)
	if skill_source.is_empty() or not skill_source.get("skills", null) is Array or not skill_source.get("progression", null) is Dictionary:
		push_error("King skill catalog is missing or invalid.")
		return false

	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9]+(?:_[a-z0-9]+)*$")

	if not _index_factions(faction_source["factions"], id_pattern):
		return false
	if not _index_weapon_archetypes(weapon_source["archetypes"], id_pattern):
		return false
	if not _index_kings(king_source["kings"], id_pattern):
		return false
	if not _index_enemies(enemy_source["enemies"], id_pattern):
		return false
	if not _index_goblin_threat(threat_source, id_pattern):
		return false
	if not _index_units(unit_source["units"], id_pattern):
		return false
	if not _index_king_skills(skill_source["skills"], skill_source["progression"], id_pattern):
		return false

	content_version = str(king_source.get("content_version", ""))
	if content_version.is_empty():
		push_error("King catalog content_version is missing.")
		return false
	enemy_content_version = str(enemy_source.get("content_version", ""))
	if enemy_content_version.is_empty():
		push_error("Enemy catalog content_version is missing.")
		return false
	weapon_content_version = str(weapon_source.get("content_version", ""))
	if weapon_content_version.is_empty():
		push_error("Weapon archetype content_version is missing.")
		return false
	unit_content_version = str(unit_source.get("content_version", ""))
	if unit_content_version.is_empty():
		push_error("Unit catalog content_version is missing.")
		return false
	skill_content_version = str(skill_source.get("content_version", ""))
	if skill_content_version.is_empty():
		push_error("King skill catalog content_version is missing.")
		return false
	threat_content_version = str(threat_source.get("content_version", ""))
	if threat_content_version.is_empty():
		push_error("Goblin threat progression content_version is missing.")
		return false

	_initialized = true
	return true


func _index_factions(records: Array, id_pattern: RegEx) -> bool:
	for faction_value in records:
		if not faction_value is Dictionary:
			push_error("Faction roster contains a non-object entry.")
			return false
		var faction: Dictionary = faction_value
		var faction_id := str(faction.get("id", ""))
		if id_pattern.search(faction_id) == null:
			push_error("Invalid faction ID: %s" % faction_id)
			return false
		if factions.has(faction_id):
			push_error("Duplicate faction ID: %s" % faction_id)
			return false
		factions[faction_id] = faction.duplicate(true)
	return true


func _index_weapon_archetypes(records: Array, id_pattern: RegEx) -> bool:
	var has_melee := false
	var has_ranged := false
	var lowest_melee_damage := INF
	var highest_ranged_damage := 0.0
	var highest_melee_range := 0.0
	var lowest_ranged_range := INF
	for archetype_value in records:
		if not archetype_value is Dictionary:
			push_error("Weapon archetype catalog contains a non-object entry.")
			return false
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		var attack_style := str(archetype.get("attack_style", ""))
		var damage_bounds: Dictionary = archetype.get("damage_bounds", {})
		var range_bounds: Dictionary = archetype.get("range_bounds", {})
		if id_pattern.search(archetype_id) == null:
			push_error("Invalid weapon archetype ID: %s" % archetype_id)
			return false
		if weapon_archetypes.has(archetype_id):
			push_error("Duplicate weapon archetype ID: %s" % archetype_id)
			return false
		if attack_style not in ["melee", "ranged"]:
			push_error("Invalid weapon attack style: %s" % archetype_id)
			return false
		if str(archetype.get("damage_type", "")) not in ["physical", "magic"]:
			push_error("Invalid weapon damage type: %s" % archetype_id)
			return false
		if not _valid_positive_bounds(damage_bounds) or not _valid_positive_bounds(range_bounds):
			push_error("Invalid weapon balance bounds: %s" % archetype_id)
			return false
		if str(archetype.get("name_key", "")).is_empty() or str(archetype.get("visual_kind", "")).is_empty():
			push_error("Weapon presentation data is missing: %s" % archetype_id)
			return false
		if attack_style == "melee":
			has_melee = true
			lowest_melee_damage = minf(lowest_melee_damage, float(damage_bounds.get("min", 0.0)))
			highest_melee_range = maxf(highest_melee_range, float(range_bounds.get("max", 0.0)))
		else:
			has_ranged = true
			highest_ranged_damage = maxf(highest_ranged_damage, float(damage_bounds.get("max", 0.0)))
			lowest_ranged_range = minf(lowest_ranged_range, float(range_bounds.get("min", 0.0)))
		weapon_archetypes[archetype_id] = archetype.duplicate(true)
	if not has_melee or not has_ranged:
		push_error("Weapon catalog must contain both melee and ranged archetypes.")
		return false
	if lowest_melee_damage <= highest_ranged_damage:
		push_error("Melee weapon damage must remain above ranged weapon damage.")
		return false
	if lowest_ranged_range <= highest_melee_range:
		push_error("Ranged weapon reach must remain above melee weapon reach.")
		return false
	return true


func _index_kings(records: Array, id_pattern: RegEx) -> bool:
	for king_value in records:
		if not king_value is Dictionary:
			push_error("King catalog contains a non-object entry.")
			return false
		var king: Dictionary = king_value
		var king_id := str(king.get("id", ""))
		var faction_id := str(king.get("faction_id", ""))
		var weapon_archetype_id := str(king.get("weapon_archetype_id", ""))
		var movement_value: Variant = king.get("movement", null)
		var health_value: Variant = king.get("health", null)
		var defense_value: Variant = king.get("defense", null)
		var attack_value: Variant = king.get("attack", null)
		var army_capacity_value: Variant = king.get("army_capacity", null)
		if id_pattern.search(king_id) == null:
			push_error("Invalid King ID: %s" % king_id)
			return false
		if kings.has(king_id):
			push_error("Duplicate King ID: %s" % king_id)
			return false
		if not factions.has(faction_id):
			push_error("King references an unknown faction: %s" % faction_id)
			return false
		if not weapon_archetypes.has(weapon_archetype_id):
			push_error("King references an unknown weapon archetype: %s" % weapon_archetype_id)
			return false
		if not movement_value is Dictionary:
			push_error("King movement data is missing: %s" % king_id)
			return false
		if not health_value is Dictionary or not defense_value is Dictionary or not attack_value is Dictionary or not army_capacity_value is Dictionary:
			push_error("King combat data is missing: %s" % king_id)
			return false
		var movement: Dictionary = movement_value
		if float(movement.get("speed", 0.0)) <= 0.0 or float(movement.get("collision_radius", 0.0)) <= 0.0:
			push_error("King movement values must be positive: %s" % king_id)
			return false
		var health: Dictionary = health_value
		var defense: Dictionary = defense_value
		var attack: Dictionary = attack_value
		var army_capacity: Dictionary = army_capacity_value
		if float(health.get("max", 0.0)) <= 0.0:
			push_error("King health must be positive: %s" % king_id)
			return false
		if float(defense.get("armor", -1.0)) < 0.0 or float(defense.get("magic_resistance", -1.0)) < 0.0:
			push_error("King defense values must be non-negative: %s" % king_id)
			return false
		if int(army_capacity.get("max", 0)) <= 0:
			push_error("King army capacity must be positive: %s" % king_id)
			return false
		if not army_capacity.get("unlimited", null) is bool:
			push_error("King unlimited summon policy is missing: %s" % king_id)
			return false
		for attack_key in ["damage", "range", "cooldown", "target_refresh"]:
			if float(attack.get(attack_key, 0.0)) <= 0.0:
				push_error("King attack value must be positive: %s.%s" % [king_id, attack_key])
				return false
		var weapon_archetype: Dictionary = weapon_archetypes[weapon_archetype_id]
		if not _value_inside_bounds(float(attack.get("damage", 0.0)), weapon_archetype.get("damage_bounds", {})):
			push_error("King damage is outside its weapon archetype bounds: %s" % king_id)
			return false
		if not _value_inside_bounds(float(attack.get("range", 0.0)), weapon_archetype.get("range_bounds", {})):
			push_error("King attack range is outside its weapon archetype bounds: %s" % king_id)
			return false
		kings[king_id] = king.duplicate(true)
	return true


func _index_enemies(records: Array, id_pattern: RegEx) -> bool:
	for enemy_value in records:
		if not enemy_value is Dictionary:
			push_error("Enemy catalog contains a non-object entry.")
			return false
		var enemy: Dictionary = enemy_value
		var enemy_id := str(enemy.get("id", ""))
		if id_pattern.search(enemy_id) == null:
			push_error("Invalid enemy ID: %s" % enemy_id)
			return false
		if enemies.has(enemy_id):
			push_error("Duplicate enemy ID: %s" % enemy_id)
			return false
		var health: Dictionary = enemy.get("health", {})
		var defense: Dictionary = enemy.get("defense", {})
		var movement: Dictionary = enemy.get("movement", {})
		var attack: Dictionary = enemy.get("attack", {})
		var presentation: Dictionary = enemy.get("presentation", {})
		var spawn: Dictionary = enemy.get("spawn", {})
		var rewards: Dictionary = enemy.get("rewards", {})
		if float(health.get("max", 0.0)) <= 0.0:
			push_error("Enemy health must be positive: %s" % enemy_id)
			return false
		if float(defense.get("armor", -1.0)) < 0.0 or float(defense.get("magic_resistance", -1.0)) < 0.0:
			push_error("Enemy defense values must be non-negative: %s" % enemy_id)
			return false
		for movement_key in ["speed", "collision_radius", "aggro_range"]:
			if float(movement.get(movement_key, 0.0)) <= 0.0:
				push_error("Enemy movement value must be positive: %s.%s" % [enemy_id, movement_key])
				return false
		for attack_key in ["damage", "range", "attacks_per_second"]:
			if float(attack.get(attack_key, 0.0)) <= 0.0:
				push_error("Enemy attack value must be positive: %s.%s" % [enemy_id, attack_key])
				return false
		var attack_style := str(attack.get("attack_style", ""))
		var damage_type := str(attack.get("damage_type", ""))
		if attack_style not in ["melee", "ranged"] or damage_type not in ["physical", "magic"]:
			push_error("Enemy attack classification is invalid: %s" % enemy_id)
			return false
		if attack_style == "melee" and float(attack.get("range", 0.0)) > 120.0:
			push_error("Melee enemy range is too long: %s" % enemy_id)
			return false
		if attack_style == "ranged" and float(attack.get("range", 0.0)) < 250.0:
			push_error("Ranged enemy range is too short: %s" % enemy_id)
			return false
		if attack_style == "ranged":
			var projectile: Dictionary = attack.get("projectile", {})
			if float(attack.get("windup", 0.0)) <= 0.0:
				push_error("Ranged enemy windup must be positive: %s" % enemy_id)
				return false
			for projectile_key in ["speed", "radius", "lifetime"]:
				if float(projectile.get(projectile_key, 0.0)) <= 0.0:
					push_error("Ranged enemy projectile value must be positive: %s.%s" % [enemy_id, projectile_key])
					return false
			if str(projectile.get("visual_kind", "")) not in ["arrow", "magic_orb"]:
				push_error("Ranged enemy projectile visual is invalid: %s" % enemy_id)
				return false
		if str(enemy.get("combat_role", "")).is_empty():
			push_error("Enemy combat role is missing: %s" % enemy_id)
			return false
		if str(presentation.get("visual_kind", "")) not in [
			"raider", "runner", "shield", "archer", "bomber", "shaman", "brute",
			"berserker", "champion", "hexer", "wolf_rider", "warlock",
			"royal_guard", "demonized",
		]:
			push_error("Enemy visual kind is invalid: %s" % enemy_id)
			return false
		if float(spawn.get("weight", 0.0)) <= 0.0:
			push_error("Enemy spawn weight must be positive: %s" % enemy_id)
			return false
		if int(spawn.get("cost", 0)) <= 0 or float(spawn.get("unlock_minute", -1.0)) < 0.0 or not spawn.get("tags", null) is Array:
			push_error("Enemy threat spawn data is invalid: %s" % enemy_id)
			return false
		var ability: Dictionary = enemy.get("ability", {})
		if str(ability.get("kind", "")).is_empty():
			push_error("Enemy ability classification is missing: %s" % enemy_id)
			return false
		if int(rewards.get("run_gold", 0)) <= 0:
			push_error("Enemy run Gold reward must be positive: %s" % enemy_id)
			return false
		if int(rewards.get("run_xp", 0)) <= 0:
			push_error("Enemy run XP reward must be positive: %s" % enemy_id)
			return false
		var healing_orb: Dictionary = rewards.get("healing_orb", {})
		var healing_chance := float(healing_orb.get("chance", -1.0))
		var healing_fraction := float(healing_orb.get("max_health_fraction", 0.0))
		if healing_chance < 0.0 or healing_chance > 1.0 or healing_fraction <= 0.0 or healing_fraction > 1.0:
			push_error("Enemy healing Orb reward is invalid: %s" % enemy_id)
			return false
		enemies[enemy_id] = enemy.duplicate(true)
	return true


func _index_goblin_threat(source: Dictionary, id_pattern: RegEx) -> bool:
	var budget: Dictionary = source.get("budget", {})
	var scaling: Dictionary = source.get("scaling", {})
	var caps: Dictionary = source.get("platform_caps", {})
	var difficulty: Dictionary = source.get("difficulty", {})
	var phases_value: Variant = source.get("phases", null)
	var bosses_value: Variant = source.get("bosses", null)
	if float(budget.get("interval_seconds", 0.0)) <= 0.0 or float(budget.get("base", 0.0)) <= 0.0:
		push_error("Goblin threat budget is invalid.")
		return false
	for scaling_key in ["hp_linear", "hp_quadratic", "damage_linear", "damage_quadratic", "speed_linear"]:
		if float(scaling.get(scaling_key, -1.0)) < 0.0:
			push_error("Goblin scaling value is invalid: %s" % scaling_key)
			return false
	if float(scaling.get("speed_cap", 0.0)) < 1.0:
		push_error("Goblin speed scaling cap is invalid.")
		return false
	for platform_id in ["web", "youtube_playables", "android", "ios", "desktop"]:
		var platform_cap: Dictionary = caps.get(platform_id, {})
		var soft_cap := int(platform_cap.get("soft", 0))
		var hard_cap := int(platform_cap.get("hard", 0))
		if soft_cap <= 0 or hard_cap < soft_cap:
			push_error("Goblin platform cap is invalid: %s" % platform_id)
			return false
	for difficulty_id in ["normal", "hard", "nightmare", "hell"]:
		var difficulty_data: Dictionary = difficulty.get(difficulty_id, {})
		for modifier_key in ["enemy_hp", "enemy_damage", "threat_budget", "telegraph_multiplier", "enhanced_hp_threshold"]:
			if float(difficulty_data.get(modifier_key, 0.0)) <= 0.0:
				push_error("Goblin difficulty modifier is invalid: %s.%s" % [difficulty_id, modifier_key])
				return false
	if not phases_value is Array or phases_value.is_empty():
		push_error("Goblin threat phases are missing.")
		return false
	var last_phase_start := -1.0
	for phase_value in phases_value:
		if not phase_value is Dictionary:
			return false
		var phase: Dictionary = phase_value
		var phase_id := str(phase.get("id", ""))
		var phase_start := float(phase.get("start_time", -1.0))
		var phase_end := float(phase.get("end_time", -1.0))
		if id_pattern.search(phase_id) == null or phase_start < last_phase_start or phase_end <= phase_start:
			push_error("Goblin threat phase is invalid: %s" % phase_id)
			return false
		if int(phase.get("target_active_min", 0)) <= 0 or int(phase.get("target_active_max", 0)) < int(phase.get("target_active_min", 0)):
			push_error("Goblin threat phase population is invalid: %s" % phase_id)
			return false
		var allowed_value: Variant = phase.get("allowed_enemy_ids", null)
		if not allowed_value is Array or allowed_value.is_empty():
			push_error("Goblin threat phase roster is missing: %s" % phase_id)
			return false
		for enemy_id_value in allowed_value:
			if not enemies.has(str(enemy_id_value)):
				push_error("Goblin threat phase references an unknown enemy: %s" % enemy_id_value)
				return false
		last_phase_start = phase_start
	if not bosses_value is Array or bosses_value.size() != 12:
		push_error("Goblin boss ladder must contain exactly twelve bosses.")
		return false
	var boss_ids: Dictionary = {}
	var signature_ids: Dictionary = {}
	var last_tier := 0
	var last_appearance := -1.0
	for boss_value in bosses_value:
		if not boss_value is Dictionary:
			return false
		var boss: Dictionary = boss_value
		var boss_id := str(boss.get("id", ""))
		var signature_id := str(boss.get("signature_skill_id", ""))
		var tier := int(boss.get("tier", 0))
		var appearance := float(boss.get("appearance_time", -1.0))
		if id_pattern.search(boss_id) == null or boss_ids.has(boss_id) or id_pattern.search(signature_id) == null or signature_ids.has(signature_id):
			push_error("Goblin boss or signature ID is invalid/duplicated: %s" % boss_id)
			return false
		if tier != last_tier + 1 or appearance <= last_appearance or not enemies.has(str(boss.get("base_enemy_id", ""))):
			push_error("Goblin boss ladder order is invalid: %s" % boss_id)
			return false
		for stat_key in ["base_hp", "base_damage", "hp_multiplier", "damage_multiplier", "stagger_resistance"]:
			if float(boss.get(stat_key, 0.0)) <= 0.0:
				push_error("Goblin boss stat is invalid: %s.%s" % [boss_id, stat_key])
				return false
		var signature: Dictionary = boss.get("signature", {})
		for timing_key in ["telegraph_duration", "cooldown", "recovery_duration", "effect_duration"]:
			if float(signature.get(timing_key, 0.0)) <= 0.0:
				push_error("Goblin boss signature timing is invalid: %s.%s" % [boss_id, timing_key])
				return false
		if not signature.get("effect_parameters", null) is Dictionary or not signature.get("enhanced_parameters", null) is Dictionary:
			push_error("Goblin boss signature parameters are missing: %s" % boss_id)
			return false
		boss_ids[boss_id] = true
		signature_ids[signature_id] = true
		last_tier = tier
		last_appearance = appearance
	goblin_threat_progression = source.duplicate(true)
	return true


func _index_units(records: Array, id_pattern: RegEx) -> bool:
	var hotkey_slots: Dictionary = {}
	for unit_value in records:
		if not unit_value is Dictionary:
			push_error("Unit catalog contains a non-object entry.")
			return false
		var unit: Dictionary = unit_value
		var unit_id := str(unit.get("id", ""))
		var faction_id := str(unit.get("faction_id", ""))
		if id_pattern.search(unit_id) == null:
			push_error("Invalid unit ID: %s" % unit_id)
			return false
		if units.has(unit_id):
			push_error("Duplicate unit ID: %s" % unit_id)
			return false
		if not factions.has(faction_id):
			push_error("Unit references an unknown faction: %s" % unit_id)
			return false
		var health: Dictionary = unit.get("health", {})
		var defense: Dictionary = unit.get("defense", {})
		var movement: Dictionary = unit.get("movement", {})
		var attack: Dictionary = unit.get("attack", {})
		var summon: Dictionary = unit.get("summon", {})
		var upgrade: Dictionary = unit.get("upgrade", {})
		var formation: Dictionary = unit.get("formation", {})
		var presentation: Dictionary = unit.get("presentation", {})
		if float(health.get("max", 0.0)) <= 0.0:
			push_error("Unit health must be positive: %s" % unit_id)
			return false
		if float(defense.get("armor", -1.0)) < 0.0 or float(defense.get("magic_resistance", -1.0)) < 0.0:
			push_error("Unit defense values must be non-negative: %s" % unit_id)
			return false
		for movement_key in ["speed", "collision_radius"]:
			if float(movement.get(movement_key, 0.0)) <= 0.0:
				push_error("Unit movement value must be positive: %s.%s" % [unit_id, movement_key])
				return false
		for attack_key in ["damage", "range", "detection_range", "leash_range", "attacks_per_second", "target_refresh"]:
			if float(attack.get(attack_key, 0.0)) <= 0.0:
				push_error("Unit attack value must be positive: %s.%s" % [unit_id, attack_key])
				return false
		if str(attack.get("attack_style", "")) not in ["melee", "ranged"] or str(attack.get("damage_type", "")) not in ["physical", "magic"]:
			push_error("Unit attack classification is invalid: %s" % unit_id)
			return false
		if str(attack.get("attack_style", "")) == "ranged":
			var projectile: Dictionary = attack.get("projectile", {})
			for projectile_key in ["speed", "radius", "lifetime"]:
				if float(projectile.get(projectile_key, 0.0)) <= 0.0:
					push_error("Ranged unit projectile value must be positive: %s.%s" % [unit_id, projectile_key])
					return false
			if str(projectile.get("visual_kind", "")) not in ["arrow", "bolt"]:
				push_error("Ranged unit projectile visual is invalid: %s" % unit_id)
				return false
		if int(summon.get("run_gold_cost", 0)) <= 0 or int(summon.get("capacity_cost", 0)) <= 0:
			push_error("Unit summon costs must be positive: %s" % unit_id)
			return false
		var hotkey_slot := int(summon.get("hotkey_slot", 0))
		if hotkey_slot <= 0 or hotkey_slot > 9 or hotkey_slots.has(hotkey_slot):
			push_error("Unit summon hotkey slot is invalid or duplicated: %s" % unit_id)
			return false
		hotkey_slots[hotkey_slot] = unit_id
		if int(upgrade.get("base_gold_cost", 0)) <= 0 or float(upgrade.get("cost_growth", 0.0)) < 1.0 or int(upgrade.get("max_level", 0)) <= 0:
			push_error("Unit upgrade curve is invalid: %s" % unit_id)
			return false
		for upgrade_key in ["health_per_level", "damage_per_level", "defense_per_level", "attack_speed_per_level"]:
			if float(upgrade.get(upgrade_key, -1.0)) < 0.0:
				push_error("Unit upgrade stat must be non-negative: %s.%s" % [unit_id, upgrade_key])
				return false
		if float(formation.get("base_radius", 0.0)) <= 0.0 or int(formation.get("slots_per_ring", 0)) <= 0 or float(formation.get("ring_spacing", -1.0)) < 0.0:
			push_error("Unit formation values are invalid: %s" % unit_id)
			return false
		if str(unit.get("name_key", "")).is_empty() or str(unit.get("role_key", "")).is_empty() or str(unit.get("combat_role", "")).is_empty():
			push_error("Unit identity data is missing: %s" % unit_id)
			return false
		if str(presentation.get("visual_kind", "")) not in ["spearman", "crossbowman", "royal_guard", "ambush_archer", "raider", "elephant_guard", "royal_war_elephant"]:
			push_error("Unit visual kind is invalid: %s" % unit_id)
			return false
		if float(presentation.get("scale", 0.0)) < 0.5 or float(presentation.get("scale", 0.0)) > 2.0:
			push_error("Unit presentation scale is invalid: %s" % unit_id)
			return false
		units[unit_id] = unit.duplicate(true)
	return true


func _index_king_skills(records: Array, progression: Dictionary, id_pattern: RegEx) -> bool:
	var supported_effects := [
		"royal_might",
		"swift_command",
		"sovereign_reach",
		"iron_will",
		"piercing_wave",
		"dragon_aura",
	]
	if int(progression.get("base_xp_to_level", 0)) <= 0 or int(progression.get("xp_growth_per_level", -1)) < 0:
		push_error("King progression XP curve is invalid.")
		return false
	var choice_count := int(progression.get("choice_count", 0))
	if choice_count <= 0 or choice_count > records.size():
		push_error("King progression choice count is invalid.")
		return false
	for skill_value in records:
		if not skill_value is Dictionary:
			push_error("King skill catalog contains a non-object entry.")
			return false
		var skill: Dictionary = skill_value
		var skill_id := str(skill.get("id", ""))
		var effect_type := str(skill.get("effect_type", ""))
		var levels_value: Variant = skill.get("levels", null)
		if id_pattern.search(skill_id) == null or king_skills.has(skill_id):
			push_error("King skill ID is invalid or duplicated: %s" % skill_id)
			return false
		if effect_type not in supported_effects:
			push_error("King skill effect type is invalid: %s" % skill_id)
			return false
		if str(skill.get("name_key", "")).is_empty() or str(skill.get("description_key", "")).is_empty():
			push_error("King skill localization keys are missing: %s" % skill_id)
			return false
		if not levels_value is Array or levels_value.is_empty():
			push_error("King skill levels are missing: %s" % skill_id)
			return false
		for level_value in levels_value:
			if not level_value is Dictionary or level_value.is_empty():
				push_error("King skill level is invalid: %s" % skill_id)
				return false
			for stat_value in level_value.values():
				if not stat_value is float and not stat_value is int:
					push_error("King skill level stat is not numeric: %s" % skill_id)
					return false
		king_skills[skill_id] = skill.duplicate(true)
	king_progression = progression.duplicate(true)
	return true


func get_faction(faction_id: StringName) -> Dictionary:
	return factions.get(str(faction_id), {}).duplicate(true)


func get_faction_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for faction_id in factions.keys():
		ids.append(str(faction_id))
	ids.sort()
	return ids


func get_king(king_id: StringName) -> Dictionary:
	var king: Dictionary = kings.get(str(king_id), {}).duplicate(true)
	if king.is_empty():
		return king
	king["weapon_archetype"] = get_weapon_archetype(StringName(str(king.get("weapon_archetype_id", ""))))
	return king


func get_king_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for king_id in kings.keys():
		ids.append(str(king_id))
	ids.sort()
	return ids


func get_enemy(enemy_id: StringName) -> Dictionary:
	return enemies.get(str(enemy_id), {}).duplicate(true)


func get_enemy_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for enemy_id in enemies.keys():
		ids.append(str(enemy_id))
	ids.sort()
	return ids


func get_unit(unit_id: StringName) -> Dictionary:
	return units.get(str(unit_id), {}).duplicate(true)


func get_unit_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for unit_id in units.keys():
		ids.append(str(unit_id))
	ids.sort()
	return ids


func get_unit_ids_for_faction(faction_id: StringName) -> PackedStringArray:
	var ids := PackedStringArray()
	for unit_id in units.keys():
		var unit: Dictionary = units[unit_id]
		if str(unit.get("faction_id", "")) == str(faction_id):
			ids.append(str(unit_id))
	ids.sort()
	return ids


func get_weapon_archetype(archetype_id: StringName) -> Dictionary:
	return weapon_archetypes.get(str(archetype_id), {}).duplicate(true)


func get_weapon_archetype_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for archetype_id in weapon_archetypes.keys():
		ids.append(str(archetype_id))
	ids.sort()
	return ids


func get_king_skill(skill_id: StringName) -> Dictionary:
	return king_skills.get(str(skill_id), {}).duplicate(true)


func get_king_skill_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for skill_id in king_skills.keys():
		ids.append(str(skill_id))
	ids.sort()
	return ids


func get_king_progression_config() -> Dictionary:
	return king_progression.duplicate(true)


func get_goblin_threat_progression() -> Dictionary:
	return goblin_threat_progression.duplicate(true)


func get_goblin_bosses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bosses_value: Variant = goblin_threat_progression.get("bosses", [])
	if bosses_value is Array:
		for boss_value in bosses_value:
			if boss_value is Dictionary:
				result.append(boss_value.duplicate(true))
	return result


func _valid_positive_bounds(bounds: Dictionary) -> bool:
	var minimum := float(bounds.get("min", 0.0))
	var maximum := float(bounds.get("max", 0.0))
	return minimum > 0.0 and maximum >= minimum


func _value_inside_bounds(value: float, bounds: Dictionary) -> bool:
	return value >= float(bounds.get("min", INF)) and value <= float(bounds.get("max", -INF))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing content file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open content file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Content file is not a JSON object: %s" % path)
		return {}
	return parsed
