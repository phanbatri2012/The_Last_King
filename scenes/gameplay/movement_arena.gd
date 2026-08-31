extends Node2D

const ARENA_RECT := Rect2(-1600.0, -900.0, 3200.0, 1800.0)
const KING_SPAWN := Vector2.ZERO
const SNAPSHOT_INTERVAL_SEC := 0.2

@onready var backdrop: MovementArenaBackdrop = %Backdrop
@onready var king: KingController = %King
@onready var joystick: MovementJoystick = %VirtualJoystick
@onready var arena_title_label: Label = %ArenaTitleLabel
@onready var king_name_label: Label = %KingNameLabel
@onready var king_title_label: Label = %KingTitleLabel
@onready var position_label: Label = %PositionLabel
@onready var time_label: Label = %TimeLabel
@onready var control_hint_label: Label = %ControlHintLabel
@onready var scope_hint_label: Label = %ScopeHintLabel
@onready var back_button: Button = %BackButton

var _king_config: Dictionary = {}
var _snapshot_accumulator := 0.0


func _ready() -> void:
	if not GameServices.initialize():
		push_error("Movement arena could not initialize game services.")
		return
	if not GameSessionService.has_active_session():
		GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", int(Time.get_ticks_usec() & 0x7fffffff))

	_king_config = ContentDatabase.get_king(&"tran_hung_dao")
	king.configure(_king_config)
	king.set_movement_bounds(ARENA_RECT)
	king.global_position = GameSessionService.get_king_position(KING_SPAWN)
	_configure_camera()

	joystick.direction_changed.connect(king.set_virtual_direction)
	back_button.pressed.connect(_return_to_menu)
	LocalizationService.locale_changed.connect(_on_locale_changed)
	_refresh_static_text()
	_refresh_live_text()


func _physics_process(delta: float) -> void:
	GameSessionService.advance(delta)
	_snapshot_accumulator += delta
	if _snapshot_accumulator < SNAPSHOT_INTERVAL_SEC:
		return
	_snapshot_accumulator = 0.0
	_store_movement_state()
	_refresh_live_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _exit_tree() -> void:
	_store_movement_state()


func _configure_camera() -> void:
	var camera := king.follow_camera
	camera.limit_left = floori(ARENA_RECT.position.x)
	camera.limit_top = floori(ARENA_RECT.position.y)
	camera.limit_right = ceili(ARENA_RECT.end.x)
	camera.limit_bottom = ceili(ARENA_RECT.end.y)
	camera.reset_smoothing()
	backdrop.arena_rect = ARENA_RECT
	backdrop.queue_redraw()


func _store_movement_state() -> void:
	if not is_instance_valid(king):
		return
	GameSessionService.set_king_movement_state(king.global_position, king.velocity)


func _refresh_static_text() -> void:
	arena_title_label.text = LocalizationService.translate_key("phase1.arena_title")
	king_name_label.text = LocalizationService.translate_key(str(_king_config.get("name_key", "king.tran_hung_dao.name")))
	king_title_label.text = LocalizationService.translate_key(str(_king_config.get("title_key", "king.tran_hung_dao.title")))
	control_hint_label.text = LocalizationService.translate_key("phase1.control_hint")
	scope_hint_label.text = LocalizationService.translate_key("phase1.scope_hint")
	back_button.text = LocalizationService.translate_key("phase1.back_to_menu")


func _refresh_live_text() -> void:
	position_label.text = LocalizationService.translate_key(
		"phase1.position",
		{"x": roundi(king.global_position.x), "y": roundi(king.global_position.y)}
	)
	var elapsed_time := 0.0
	if GameSessionService.active_session != null:
		elapsed_time = GameSessionService.active_session.elapsed_time
	time_label.text = LocalizationService.translate_key(
		"phase1.session_time",
		{"time": snappedf(elapsed_time, 0.1)}
	)


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_text()
	_refresh_live_text()


func _return_to_menu() -> void:
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	_store_movement_state()
	SceneService.change_scene_to_file("res://scenes/menus/main_menu.tscn")
