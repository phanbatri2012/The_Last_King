class_name MovementArenaBackdrop
extends Node2D

@export_range(80, 320, 16) var tile_size := 160
@export_range(2, 8, 1) var padding_tiles := 4

var follow_target: Node2D
var _center_cell := Vector2i.ZERO
var _half_columns := 8
var _half_rows := 6


func _ready() -> void:
	_update_visible_region(true)


func _process(_delta: float) -> void:
	_update_visible_region(false)


static func world_cell_for_position(world_position: Vector2, cell_size: int) -> Vector2i:
	var safe_size := maxi(cell_size, 1)
	return Vector2i(floori(world_position.x / safe_size), floori(world_position.y / safe_size))


func _update_visible_region(force: bool) -> void:
	var target_position := Vector2.ZERO
	if is_instance_valid(follow_target):
		target_position = follow_target.global_position
	var next_cell := world_cell_for_position(target_position, tile_size)
	var viewport_size := get_viewport_rect().size
	var next_half_columns := ceili(viewport_size.x / float(tile_size) * 0.5) + padding_tiles
	var next_half_rows := ceili(viewport_size.y / float(tile_size) * 0.5) + padding_tiles
	if not force and next_cell == _center_cell and next_half_columns == _half_columns and next_half_rows == _half_rows:
		return
	_center_cell = next_cell
	_half_columns = next_half_columns
	_half_rows = next_half_rows
	global_position = Vector2(_center_cell * tile_size)
	queue_redraw()


func _draw() -> void:
	for row_offset in range(-_half_rows, _half_rows + 1):
		for column_offset in range(-_half_columns, _half_columns + 1):
			var world_cell := _center_cell + Vector2i(column_offset, row_offset)
			var local_position := Vector2(column_offset * tile_size, row_offset * tile_size)
			_draw_world_tile(world_cell, local_position)
	_draw_origin_landmark_if_visible()


func _draw_world_tile(world_cell: Vector2i, local_position: Vector2) -> void:
	var base_color := Color(0.052, 0.135, 0.12, 1.0)
	if posmod(world_cell.x + world_cell.y, 2) == 0:
		base_color = Color(0.058, 0.15, 0.132, 1.0)
	var detail_hash := _cell_hash(world_cell)
	if detail_hash % 11 == 0:
		base_color = base_color.lightened(0.035)
	var tile_rect := Rect2(local_position, Vector2.ONE * tile_size)
	draw_rect(tile_rect, base_color, true)
	var grid_alpha := 0.13
	if posmod(world_cell.x, 8) == 0 or posmod(world_cell.y, 8) == 0:
		grid_alpha = 0.24
	draw_rect(tile_rect, Color(0.2, 0.34, 0.26, grid_alpha), false, 2.0)

	if detail_hash % 7 == 0:
		var detail_position := local_position + Vector2(35.0 + float(detail_hash % 73), 42.0 + float((detail_hash >> 3) % 61))
		draw_circle(detail_position, 7.0, Color(0.16, 0.25, 0.18, 0.34))
		draw_line(detail_position, detail_position + Vector2(5.0, -11.0), Color(0.28, 0.42, 0.24, 0.32), 3.0, true)
	if detail_hash % 29 == 0:
		var stone_center := local_position + Vector2(tile_size * 0.72, tile_size * 0.63)
		draw_circle(stone_center, 13.0, Color(0.18, 0.23, 0.21, 0.5))
		draw_arc(stone_center, 13.0, 0.0, TAU, 16, Color(0.33, 0.38, 0.34, 0.35), 2.0, true)


func _draw_origin_landmark_if_visible() -> void:
	if absi(_center_cell.x) > _half_columns + 2 or absi(_center_cell.y) > _half_rows + 2:
		return
	var origin := -Vector2(_center_cell * tile_size)
	draw_circle(origin, 220.0, Color(0.04, 0.09, 0.085, 0.3))
	draw_arc(origin, 220.0, 0.0, TAU, 72, Color(0.76, 0.58, 0.22, 0.34), 6.0, true)
	draw_arc(origin, 120.0, 0.0, TAU, 48, Color(0.76, 0.58, 0.22, 0.25), 4.0, true)
	for spoke in 8:
		var direction := Vector2.RIGHT.rotated(TAU * spoke / 8.0)
		draw_line(origin + direction * 120.0, origin + direction * 220.0, Color(0.76, 0.58, 0.22, 0.22), 4.0, true)


func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663))
