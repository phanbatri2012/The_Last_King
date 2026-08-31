extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en-US"
const SUPPORTED_LOCALES := ["en-US", "vi-VN"]
const LOCALE_PATH_TEMPLATE := "res://localization/%s/common.json"

var current_locale := DEFAULT_LOCALE
var _default_strings: Dictionary = {}
var _current_strings: Dictionary = {}
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	_default_strings = _load_locale(DEFAULT_LOCALE)
	if _default_strings.is_empty():
		push_error("Canonical en-US localization could not be loaded.")
		return false

	var preferred_locale := _normalize_locale(PlatformService.get_locale())
	if not set_locale(preferred_locale):
		return false

	_initialized = true
	return true


func set_locale(locale: String) -> bool:
	var normalized := _normalize_locale(locale)
	var loaded := _load_locale(normalized)
	if loaded.is_empty() and normalized != DEFAULT_LOCALE:
		normalized = DEFAULT_LOCALE
		loaded = _default_strings.duplicate(true)
	if loaded.is_empty():
		return false

	current_locale = normalized
	_current_strings = loaded
	locale_changed.emit(current_locale)
	return true


func translate_key(key: String, parameters: Dictionary = {}) -> String:
	var text := str(_current_strings.get(key, _default_strings.get(key, key)))
	for parameter_name in parameters:
		text = text.replace("{%s}" % str(parameter_name), str(parameters[parameter_name]))
	return text


func has_key(key: String) -> bool:
	return _current_strings.has(key) or _default_strings.has(key)


func _normalize_locale(locale: String) -> String:
	var normalized := locale.replace("_", "-")
	if normalized.to_lower().begins_with("vi"):
		return "vi-VN"
	return DEFAULT_LOCALE


func _load_locale(locale: String) -> Dictionary:
	if locale not in SUPPORTED_LOCALES:
		return {}
	var path := LOCALE_PATH_TEMPLATE % locale
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
