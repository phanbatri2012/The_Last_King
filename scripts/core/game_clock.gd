class_name GameClock
extends RefCounted

var elapsed_time := 0.0
var paused := false


func advance(delta: float) -> void:
	if not paused:
		elapsed_time += maxf(delta, 0.0)


func reset() -> void:
	elapsed_time = 0.0
	paused = false
