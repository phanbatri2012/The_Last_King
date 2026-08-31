extends Node

var music_volume := 0.8
var sfx_volume := 1.0
var host_audio_enabled := true
var _initialized := false


func initialize() -> bool:
	_initialized = true
	return true


func set_host_audio_enabled(enabled: bool) -> void:
	host_audio_enabled = enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)
