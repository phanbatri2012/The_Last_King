class_name YouTubePlatformAdapter
extends WebPlatformAdapter


func get_platform_name() -> String:
	return "youtube_playables"


# The SDK bridge is intentionally deferred until the YouTube integration phase.
# Gameplay code must only use PlatformService and never reference `ytgame`.
