extends Node

const FACTION_ROSTER_PATH := "res://data/factions/faction_roster.json"
const KING_CATALOG_PATH := "res://data/kings/kings.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/enemies.json"
const WEAPON_ARCHETYPE_PATH := "res://data/combat/weapon_archetypes.json"
const UNIT_CATALOG_PATH := "res://data/units/units.json"

var factions: Dictionary = {}
var kings: Dictionary = {}
var enemies: Dictionary = {}
var units: Dictionary = {}
var weapon_archetypes: Dictionary = {}
var content_version := ""
var enemy_content_version := ""
var weapon_content_version := ""
var unit_content_version := ""
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	factions.clear()
	kings.clear()
	enemies.clear()
	units.clear()
	weapon_archetypes.clear()

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
	var weapon_source := _load_json(WEAPON_ARCHETYPE_PATH)
	if weapon_source.is_empty() or not weapon_source.get("archetypes", null) is Array:
		push_error("Weapon archetype catalog is missing or invalid.")
		return false
	var unit_source := _load_json(UNIT_CATALOG_PATH)
	if unit_source.is_empty() or not unit_source.get("units", null) is Array:
		push_error("Unit catalog is missing or invalid.")
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
	if not _index_units(unit_source["units"], id_pattern):
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
		if str(enemy.get("combat_role", "")).is_empty():
			push_error("Enemy combat role is missing: %s" % enemy_id)
			return false
		if str(presentation.get("visual_kind", "")) not in ["raider", "brute", "archer", "hexer"]:
			push_error("Enemy visual kind is invalid: %s" % enemy_id)
			return false
		if float(spawn.get("weight", 0.0)) <= 0.0:
			push_error("Enemy spawn weight must be positive: %s" % enemy_id)
			return false
		if int(rewards.get("run_gold", 0)) <= 0:
			push_error("Enemy run Gold reward must be positive: %s" % enemy_id)
			return false
		enemies[enemy_id] = enemy.duplicate(true)
	return true


func _index_units(records: Array, id_pattern: RegEx) -> bool:
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
		if int(summon.get("run_gold_cost", 0)) <= 0 or int(summon.get("capacity_cost", 0)) <= 0:
			push_error("Unit summon costs must be positive: %s" % unit_id)
			return false
		if float(formation.get("base_radius", 0.0)) <= 0.0 or int(formation.get("slots_per_ring", 0)) <= 0 or float(formation.get("ring_spacing", -1.0)) < 0.0:
			push_error("Unit formation values are invalid: %s" % unit_id)
			return false
		if str(unit.get("name_key", "")).is_empty() or str(unit.get("role_key", "")).is_empty() or str(unit.get("combat_role", "")).is_empty():
			push_error("Unit identity data is missing: %s" % unit_id)
			return false
		if str(presentation.get("visual_kind", "")) not in ["spearman"]:
			push_error("Unit visual kind is invalid: %s" % unit_id)
			return false
		units[unit_id] = unit.duplicate(true)
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
