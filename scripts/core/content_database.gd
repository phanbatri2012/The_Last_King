extends Node

const FACTION_ROSTER_PATH := "res://data/factions/faction_roster.json"

var factions: Dictionary = {}
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	var source := _load_json(FACTION_ROSTER_PATH)
	if source.is_empty() or not source.has("factions") or not source["factions"] is Array:
		push_error("Faction roster is missing or invalid.")
		return false

	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9]+(?:_[a-z0-9]+)*$")

	for faction_value in source["factions"]:
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

	_initialized = true
	return true


func get_faction(faction_id: StringName) -> Dictionary:
	return factions.get(str(faction_id), {}).duplicate(true)


func get_faction_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for faction_id in factions.keys():
		ids.append(str(faction_id))
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
