extends Node

const FACTION_ROSTER_PATH := "res://data/factions/faction_roster.json"
const KING_CATALOG_PATH := "res://data/kings/kings.json"

var factions: Dictionary = {}
var kings: Dictionary = {}
var content_version := ""
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	factions.clear()
	kings.clear()

	var faction_source := _load_json(FACTION_ROSTER_PATH)
	if faction_source.is_empty() or not faction_source.get("factions", null) is Array:
		push_error("Faction roster is missing or invalid.")
		return false
	var king_source := _load_json(KING_CATALOG_PATH)
	if king_source.is_empty() or not king_source.get("kings", null) is Array:
		push_error("King catalog is missing or invalid.")
		return false

	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9]+(?:_[a-z0-9]+)*$")

	if not _index_factions(faction_source["factions"], id_pattern):
		return false
	if not _index_kings(king_source["kings"], id_pattern):
		return false

	content_version = str(king_source.get("content_version", ""))
	if content_version.is_empty():
		push_error("King catalog content_version is missing.")
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


func _index_kings(records: Array, id_pattern: RegEx) -> bool:
	for king_value in records:
		if not king_value is Dictionary:
			push_error("King catalog contains a non-object entry.")
			return false
		var king: Dictionary = king_value
		var king_id := str(king.get("id", ""))
		var faction_id := str(king.get("faction_id", ""))
		var movement_value: Variant = king.get("movement", null)
		if id_pattern.search(king_id) == null:
			push_error("Invalid King ID: %s" % king_id)
			return false
		if kings.has(king_id):
			push_error("Duplicate King ID: %s" % king_id)
			return false
		if not factions.has(faction_id):
			push_error("King references an unknown faction: %s" % faction_id)
			return false
		if not movement_value is Dictionary:
			push_error("King movement data is missing: %s" % king_id)
			return false
		var movement: Dictionary = movement_value
		if float(movement.get("speed", 0.0)) <= 0.0 or float(movement.get("collision_radius", 0.0)) <= 0.0:
			push_error("King movement values must be positive: %s" % king_id)
			return false
		kings[king_id] = king.duplicate(true)
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
	return kings.get(str(king_id), {}).duplicate(true)


func get_king_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for king_id in kings.keys():
		ids.append(str(king_id))
	ids.sort()
	return ids


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
