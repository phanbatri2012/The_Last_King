extends Node

signal initialization_completed
signal initialization_failed(service_name: String)

var initialized := false


func initialize() -> bool:
	if initialized:
		return true

	var services: Array[Node] = [
		PlatformService,
		LocalizationService,
		ContentDatabase,
		SaveService,
		PlayerProfileService,
		LeaderboardService,
		AudioService,
		GameSessionService,
		SceneService,
	]

	for service in services:
		if not service.has_method("initialize"):
			continue
		if not bool(service.call("initialize")):
			var service_name := str(service.name)
			push_error("Service initialization failed: %s" % service_name)
			initialization_failed.emit(service_name)
			return false

	initialized = true
	initialization_completed.emit()
	return true
