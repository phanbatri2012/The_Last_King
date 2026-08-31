class_name DesktopPlatformAdapter
extends PlatformAdapter


func get_platform_name() -> String:
	return "desktop"


func supports(capability: Capability) -> bool:
	return capability == Capability.QUIT_APPLICATION


func request_application_quit() -> bool:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return false
	main_loop.quit()
	return true
