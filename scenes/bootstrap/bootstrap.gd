extends Control

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_boot()


func _boot() -> void:
	status_label.text = "bootstrap.loading"
	if not GameServices.initialize():
		status_label.text = LocalizationService.translate_key("bootstrap.failed")
		return

	status_label.text = LocalizationService.translate_key("bootstrap.ready")
	await get_tree().process_frame
	SceneService.change_scene_to_file("res://scenes/menus/main_menu.tscn")
