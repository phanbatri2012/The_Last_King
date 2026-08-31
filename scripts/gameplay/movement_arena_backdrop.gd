class_name MovementArenaBackdrop
extends Node2D

@export var arena_rect := Rect2(-1600.0, -900.0, 3200.0, 1800.0)
@export_range(80, 320, 16) var tile_size := 160


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(arena_rect, Color(0.045, 0.115, 0.105, 1.0), true)
	_draw_tiles()
	_draw_center_mark()
	_draw_standards()
	draw_rect(arena_rect, Color(0.72, 0.52, 0.16, 1.0), false, 18.0)
	draw_rect(arena_rect.grow(-28.0), Color(0.18, 0.28, 0.22, 1.0), false, 4.0)


func _draw_tiles() -> void:
	var columns := ceili(arena_rect.size.x / float(tile_size))
	var rows := ceili(arena_rect.size.y / float(tile_size))
	for row in rows:
		for column in columns:
			var tile_position := arena_rect.position + Vector2(column * tile_size, row * tile_size)
			var color := Color(0.052, 0.135, 0.12, 1.0)
			if (row + column) % 2 == 0:
				color = Color(0.058, 0.15, 0.132, 1.0)
			draw_rect(Rect2(tile_position, Vector2.ONE * tile_size), color, true)
	for x in range(int(arena_rect.position.x), int(arena_rect.end.x) + 1, tile_size):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), Color(0.2, 0.32, 0.25, 0.16), 2.0)
	for y in range(int(arena_rect.position.y), int(arena_rect.end.y) + 1, tile_size):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), Color(0.2, 0.32, 0.25, 0.16), 2.0)


func _draw_center_mark() -> void:
	var center := arena_rect.get_center()
	draw_circle(center, 220.0, Color(0.04, 0.09, 0.085, 0.32))
	draw_arc(center, 220.0, 0.0, TAU, 96, Color(0.76, 0.58, 0.22, 0.36), 6.0, true)
	draw_arc(center, 120.0, 0.0, TAU, 72, Color(0.76, 0.58, 0.22, 0.28), 4.0, true)
	for spoke in 8:
		var direction := Vector2.RIGHT.rotated(TAU * spoke / 8.0)
		draw_line(center + direction * 120.0, center + direction * 220.0, Color(0.76, 0.58, 0.22, 0.24), 4.0, true)


func _draw_standards() -> void:
	var inset := 90.0
	var points := [
		arena_rect.position + Vector2(inset, inset),
		Vector2(arena_rect.end.x - inset, arena_rect.position.y + inset),
		Vector2(arena_rect.position.x + inset, arena_rect.end.y - inset),
		arena_rect.end - Vector2(inset, inset),
	]
	for point in points:
		draw_line(point + Vector2(0.0, -45.0), point + Vector2(0.0, 55.0), Color(0.74, 0.57, 0.25, 1.0), 7.0, true)
		var banner := PackedVector2Array([
			point + Vector2(3.0, -42.0),
			point + Vector2(54.0, -26.0),
			point + Vector2(3.0, 2.0),
		])
		draw_colored_polygon(banner, Color(0.46, 0.06, 0.075, 1.0))
		draw_polyline(banner, Color(0.9, 0.67, 0.2, 1.0), 3.0, true)
