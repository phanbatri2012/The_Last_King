extends Node2D

const GOBLIN_SCENE := preload("res://scenes/gameplay/goblin.tscn")
const KING_SPAWN := Vector2.ZERO
const SNAPSHOT_INTERVAL_SEC := 0.15
const EFFECTIVE_CAMERA_LIMIT := 2147480000
const TRAINING_GOBLIN_OFFSETS := [
	Vector2(430.0, -140.0),
	Vector2(610.0, 190.0),
	Vector2(-510.0, 230.0),
	Vector2(-650.0, -260.0),
	Vector2(120.0, 560.0),
]

@onready var backdrop: MovementArenaBackdrop = %Backdrop
@onready var king: KingController = %King
@onready var joystick: MovementJoystick = %VirtualJoystick
@onready var arena_title_label: Label = %ArenaTitleLabel
@onready var king_name_label: Label = %KingNameLabel
@onready var king_title_label: Label = %KingTitleLabel
@onready var position_label: Label = %PositionLabel
@onready var time_label: Label = %TimeLabel
@onready var king_health_label: Label = %KingHealthLabel
@onready var king_health_bar: ProgressBar = %KingHealthBar
@onready var enemy_count_label: Label = %EnemyCountLabel
@onready var control_hint_label: Label = %ControlHintLabel
@onready var scope_hint_label: Label = %ScopeHintLabel
@onready var target_label: Label = %TargetLabel
@onready var back_button: Button = %BackButton
@onready var death_overlay: Control = %DeathOverlay
@onready var defeat_title_label: Label = %DefeatTitleLabel
@onready var defeat_detail_label: Label = %DefeatDetailLabel
@onready var retry_button: Button = %RetryButton
@onready var defeat_back_button: Button = %DefeatBackButton

var _king_config: Dictionary = {}
var _goblin_config: Dictionary = {}
var _training_enemies: Dictionary = {}
var _defeated_enemy_instances: Dictionary = {}
var _snapshot_accumulator := 0.0
var _skip_exit_snapshot := false


func _ready() -> void:
	if not GameServices.initialize():
		push_error("Combat arena could not initialize game services.")
		return
	if not GameSessionService.has_active_session():
		GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", int(Time.get_ticks_usec() & 0x7fffffff))

	_king_config = ContentDatabase.get_king(&"tran_hung_dao")
	_goblin_config = ContentDatabase.get_enemy(&"goblin")
	king.configure(_king_config)
	king.clear_movement_bounds()
	king.global_position = GameSessionService.get_king_position(KING_SPAWN)
	king.restore_health(GameSessionService.get_king_health(king.health.max_health))
	_configure_infinite_world()
	_restore_or_create_training_encounter()

	joystick.direction_changed.connect(king.set_virtual_direction)
	back_button.pressed.connect(_return_to_menu)
	retry_button.pressed.connect(_restart_combat_drill)
	defeat_back_button.pressed.connect(_return_to_menu)
	king.defeated.connect(_on_king_defeated)
	king.health.health_changed.connect(_on_king_health_changed)
	king.auto_attack.target_changed.connect(_on_target_changed)
	LocalizationService.locale_changed.connect(_on_locale_changed)
	_refresh_static_text()
	_refresh_live_text()
	death_overlay.visible = not king.is_combat_alive()


func _physics_process(delta: float) -> void:
	if king.is_combat_alive():
		GameSessionService.advance(delta)
	_snapshot_accumulator += delta
	if _snapshot_accumulator < SNAPSHOT_INTERVAL_SEC:
		return
	_snapshot_accumulator = 0.0
	_store_combat_state()
	_refresh_live_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _exit_tree() -> void:
	if not _skip_exit_snapshot:
		_store_combat_state()


func _configure_infinite_world() -> void:
	var camera := king.follow_camera
	camera.limit_left = -EFFECTIVE_CAMERA_LIMIT
	camera.limit_top = -EFFECTIVE_CAMERA_LIMIT
	camera.limit_right = EFFECTIVE_CAMERA_LIMIT
	camera.limit_bottom = EFFECTIVE_CAMERA_LIMIT
	camera.reset_smoothing()
	backdrop.follow_target = king
	backdrop.queue_redraw()


func _restore_or_create_training_encounter() -> void:
	var state := GameSessionService.get_enemy_combat_state()
	if str(state.get("encounter_id", "")) == "phase2_combat_drill":
		var defeated_value: Variant = state.get("defeated_instance_ids", [])
		if defeated_value is Array:
			for defeated_id in defeated_value:
				_defeated_enemy_instances[str(defeated_id)] = true
		var living_value: Variant = state.get("living_enemies", [])
		if living_value is Array:
			for snapshot_value in living_value:
				if snapshot_value is Dictionary:
					_restore_goblin(snapshot_value)
		return

	for index in TRAINING_GOBLIN_OFFSETS.size():
		_create_goblin(
			"training_goblin_%d" % (index + 1),
			king.global_position + TRAINING_GOBLIN_OFFSETS[index],
			-1.0
		)


func _restore_goblin(snapshot: Dictionary) -> void:
	var instance_key := str(snapshot.get("instance_id", ""))
	if instance_key.is_empty() or _defeated_enemy_instances.has(instance_key):
		return
	var position_data: Dictionary = snapshot.get("position", {})
	var restored_position := Vector2(
		float(position_data.get("x", king.global_position.x)),
		float(position_data.get("y", king.global_position.y))
	)
	_create_goblin(instance_key, restored_position, float(snapshot.get("health", -1.0)))


func _create_goblin(instance_key: String, world_position: Vector2, restored_health: float) -> void:
	var goblin := GOBLIN_SCENE.instantiate() as GoblinController
	if goblin == null:
		push_error("Goblin scene could not be instantiated.")
		return
	goblin.global_position = world_position
	add_child(goblin)
	goblin.configure(_goblin_config, instance_key, restored_health)
	goblin.set_target(king)
	goblin.defeated.connect(_on_enemy_defeated)
	_training_enemies[instance_key] = goblin


func _store_combat_state() -> void:
	if not is_instance_valid(king) or not GameSessionService.has_active_session():
		return
	GameSessionService.set_king_movement_state(king.global_position, king.velocity)
	GameSessionService.set_king_health_state(king.health.current_health, king.health.max_health)
	var living_enemies: Array[Dictionary] = []
	for instance_key in _training_enemies.keys():
		var enemy := _training_enemies[instance_key] as GoblinController
		if is_instance_valid(enemy) and enemy.is_combat_alive():
			living_enemies.append(enemy.get_combat_snapshot())
	var defeated_ids := PackedStringArray()
	for instance_key in _defeated_enemy_instances.keys():
		defeated_ids.append(str(instance_key))
	defeated_ids.sort()
	GameSessionService.set_enemy_combat_state(living_enemies, defeated_ids)


func _living_enemy_count() -> int:
	var count := 0
	for enemy_value in _training_enemies.values():
		var enemy := enemy_value as GoblinController
		if is_instance_valid(enemy) and enemy.is_combat_alive():
			count += 1
	return count


func _refresh_static_text() -> void:
	arena_title_label.text = LocalizationService.translate_key("phase2.arena_title")
	king_name_label.text = LocalizationService.translate_key(str(_king_config.get("name_key", "king.tran_hung_dao.name")))
	king_title_label.text = LocalizationService.translate_key(str(_king_config.get("title_key", "king.tran_hung_dao.title")))
	control_hint_label.text = LocalizationService.translate_key("phase2.control_hint")
	scope_hint_label.text = LocalizationService.translate_key("phase2.scope_hint")
	back_button.text = LocalizationService.translate_key("phase2.back_to_menu")
	defeat_title_label.text = LocalizationService.translate_key("phase2.defeat_title")
	defeat_detail_label.text = LocalizationService.translate_key("phase2.defeat_detail")
	retry_button.text = LocalizationService.translate_key("phase2.retry")
	defeat_back_button.text = LocalizationService.translate_key("phase2.back_to_menu")


func _refresh_live_text() -> void:
	if not is_instance_valid(king):
		return
	position_label.text = LocalizationService.translate_key(
		"phase2.position",
		{"x": roundi(king.global_position.x), "y": roundi(king.global_position.y)}
	)
	var elapsed_time := 0.0
	if GameSessionService.active_session != null:
		elapsed_time = GameSessionService.active_session.elapsed_time
	time_label.text = LocalizationService.translate_key(
		"phase2.session_time",
		{"time": snappedf(elapsed_time, 0.1)}
	)
	king_health_label.text = LocalizationService.translate_key(
		"phase2.king_health",
		{"current": ceili(king.health.current_health), "max": ceili(king.health.max_health)}
	)
	king_health_bar.value = king.health.get_ratio() * 100.0
	var living_count := _living_enemy_count()
	enemy_count_label.text = LocalizationService.translate_key("phase2.enemy_count", {"count": living_count})
	var current_target := king.auto_attack.get_current_target()
	if is_instance_valid(current_target) and current_target.is_combat_alive():
		target_label.text = LocalizationService.translate_key(
			"phase2.target",
			{
				"name": LocalizationService.translate_key(current_target.name_key),
				"current": ceili(current_target.health.current_health),
				"max": ceili(current_target.health.max_health),
			}
		)
	elif living_count == 0:
		target_label.text = LocalizationService.translate_key("phase2.drill_complete")
	else:
		target_label.text = LocalizationService.translate_key("phase2.no_target")


func _on_enemy_defeated(enemy: GoblinController, _context: Dictionary) -> void:
	_defeated_enemy_instances[enemy.instance_id] = true
	_store_combat_state()
	_refresh_live_text()


func _on_king_defeated(_context: Dictionary) -> void:
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	death_overlay.visible = true
	_store_combat_state()
	_refresh_live_text()


func _on_king_health_changed(_current: float, _maximum: float, _delta: float, _context: Dictionary) -> void:
	_refresh_live_text()


func _on_target_changed(_target: GoblinController) -> void:
	_refresh_live_text()


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_text()
	_refresh_live_text()


func _restart_combat_drill() -> void:
	_skip_exit_snapshot = true
	var session_seed := int(Time.get_ticks_usec() & 0x7fffffff)
	GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", session_seed)
	SceneService.change_scene_to_file("res://scenes/gameplay/movement_arena.tscn")


func _return_to_menu() -> void:
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	_store_combat_state()
	SceneService.change_scene_to_file("res://scenes/menus/main_menu.tscn")
