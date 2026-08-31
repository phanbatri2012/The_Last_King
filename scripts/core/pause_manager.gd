class_name PauseManager
extends RefCounted

signal pause_state_changed(paused: bool)

const PLAYER := &"player"
const PLATFORM := &"platform"
const BACKGROUND := &"background"
const AD := &"ad"
const SYSTEM := &"system"

var _reasons: Dictionary = {}


func request_pause(reason: StringName) -> void:
	var was_paused := is_paused()
	_reasons[str(reason)] = true
	if not was_paused:
		pause_state_changed.emit(true)


func clear_pause(reason: StringName) -> void:
	var was_paused := is_paused()
	_reasons.erase(str(reason))
	if was_paused and not is_paused():
		pause_state_changed.emit(false)


func is_paused() -> bool:
	return not _reasons.is_empty()


func get_reasons() -> PackedStringArray:
	var reasons := PackedStringArray()
	for reason in _reasons.keys():
		reasons.append(str(reason))
	reasons.sort()
	return reasons
