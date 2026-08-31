extends Node

signal initialized(platform_name: String)
signal host_pause_requested
signal host_resume_requested

const DesktopAdapter := preload("res://scripts/platform/adapters/desktop_platform_adapter.gd")
const WebAdapter := preload("res://scripts/platform/adapters/web_platform_adapter.gd")
const YouTubeAdapter := preload("res://scripts/platform/adapters/youtube_platform_adapter.gd")
const AndroidAdapter := preload("res://scripts/platform/adapters/android_platform_adapter.gd")
const IOSAdapter := preload("res://scripts/platform/adapters/ios_platform_adapter.gd")

var adapter: PlatformAdapter
var _initialized := false


func initialize() -> bool:
	if _initialized:
		return true

	adapter = _create_adapter()
	if not adapter.initialize():
		push_error("Platform adapter failed to initialize.")
		return false

	adapter.pause_requested.connect(_on_adapter_pause_requested)
	adapter.resume_requested.connect(_on_adapter_resume_requested)
	_initialized = true
	initialized.emit(adapter.get_platform_name())
	return true


func get_platform_name() -> String:
	return adapter.get_platform_name() if adapter != null else "uninitialized"


func get_locale() -> String:
	return adapter.get_locale() if adapter != null else "en-US"


func supports(capability: PlatformAdapter.Capability) -> bool:
	return adapter != null and adapter.supports(capability)


func supports_iap() -> bool:
	return supports(PlatformAdapter.Capability.IAP)


func supports_rewarded_ads() -> bool:
	return supports(PlatformAdapter.Capability.REWARDED_ADS)


func supports_cloud_save() -> bool:
	return supports(PlatformAdapter.Capability.CLOUD_SAVE)


func supports_native_leaderboard() -> bool:
	return supports(PlatformAdapter.Capability.NATIVE_LEADERBOARD)


func supports_application_quit() -> bool:
	return supports(PlatformAdapter.Capability.QUIT_APPLICATION)


func request_application_quit() -> bool:
	return adapter != null and adapter.request_application_quit()


func _create_adapter() -> PlatformAdapter:
	var forced_adapter := str(ProjectSettings.get_setting("the_last_king/platform/force_adapter", ""))
	match forced_adapter:
		"youtube_playables":
			return YouTubeAdapter.new()
		"web":
			return WebAdapter.new()
		"android":
			return AndroidAdapter.new()
		"ios":
			return IOSAdapter.new()
		"desktop":
			return DesktopAdapter.new()

	if OS.has_feature("web"):
		return WebAdapter.new()
	if OS.has_feature("android"):
		return AndroidAdapter.new()
	if OS.has_feature("ios"):
		return IOSAdapter.new()
	return DesktopAdapter.new()


func _on_adapter_pause_requested() -> void:
	host_pause_requested.emit()


func _on_adapter_resume_requested() -> void:
	host_resume_requested.emit()
