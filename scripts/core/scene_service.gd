extends Node

var _initialized := false


func initialize() -> bool:
	_initialized = true
	return true


func change_scene_to_file(scene_path: String) -> Error:
	return get_tree().change_scene_to_file(scene_path)


func change_scene_to_packed(scene: PackedScene) -> Error:
	return get_tree().change_scene_to_packed(scene)
