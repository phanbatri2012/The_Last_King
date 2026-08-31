class_name MovementJoystick
extends Control

signal direction_changed(direction: Vector2)

@export_range(40.0, 120.0, 1.0) var radius := 72.0
@export_range(12.0, 48.0, 1.0) var knob_radius := 28.0
@export_range(0.0, 0.5, 0.01) var deadzone := 0.12

var _direction := Vector2.ZERO
var _touch_index := -1
var _mouse_active := false


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * (radius * 2.0 + 24.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_window().focus_exited.connect(reset)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		accept_event()
		return
	if event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_from_local_position(event.position)
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_index != -1:
			return
		_mouse_active = event.pressed
		if _mouse_active:
			_update_from_local_position(event.position)
		else:
			reset()
		accept_event()
		return
	if event is InputEventMouseMotion and _mouse_active:
		_update_from_local_position(event.position)
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius + 8.0, Color(0.015, 0.02, 0.03, 0.38))
	draw_circle(center, radius, Color(0.08, 0.11, 0.15, 0.72))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.78, 0.59, 0.2, 0.8), 3.0, true)
	draw_circle(center, radius * deadzone, Color(0.75, 0.77, 0.82, 0.08))
	var knob_position := center + _direction * radius
	draw_circle(knob_position, knob_radius + 4.0, Color(0.02, 0.025, 0.035, 0.7))
	draw_circle(knob_position, knob_radius, Color(0.88, 0.7, 0.25, 0.92))
	draw_circle(knob_position, knob_radius * 0.45, Color(1.0, 0.87, 0.45, 0.72))


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _touch_index == -1:
		_touch_index = event.index
		_update_from_local_position(event.position)
	elif not event.pressed and event.index == _touch_index:
		_touch_index = -1
		reset()


func _update_from_local_position(local_position: Vector2) -> void:
	_set_direction(direction_from_offset(local_position - size * 0.5, radius, deadzone))


func _set_direction(value: Vector2) -> void:
	var next_direction := value.limit_length(1.0)
	if _direction.is_equal_approx(next_direction):
		return
	_direction = next_direction
	direction_changed.emit(_direction)
	queue_redraw()


func get_direction() -> Vector2:
	return _direction


func reset() -> void:
	_touch_index = -1
	_mouse_active = false
	_set_direction(Vector2.ZERO)


static func direction_from_offset(offset: Vector2, maximum_radius: float, input_deadzone: float) -> Vector2:
	if maximum_radius <= 0.0:
		return Vector2.ZERO
	var normalized_deadzone := clampf(input_deadzone, 0.0, 0.99)
	var raw_strength := minf(offset.length() / maximum_radius, 1.0)
	if raw_strength <= normalized_deadzone or offset.is_zero_approx():
		return Vector2.ZERO
	var remapped_strength := (raw_strength - normalized_deadzone) / (1.0 - normalized_deadzone)
	return offset.normalized() * remapped_strength
