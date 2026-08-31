extends Node2D

const GOBLIN_SCENE := preload("res://scenes/gameplay/goblin.tscn")
const RUN_GOLD_PICKUP_SCENE := preload("res://scenes/gameplay/run_gold_pickup.tscn")
const HEALING_ORB_PICKUP_SCENE := preload("res://scenes/gameplay/healing_orb_pickup.tscn")
const KING_SPAWN := Vector2.ZERO
const SNAPSHOT_INTERVAL_SEC := 0.15
const EFFECTIVE_CAMERA_LIMIT := 2147480000
const DEFEATED_ENEMY_CLEANUP_SEC := 0.7
const DENSITY_REBALANCE_INTERVAL_SEC := 1.0
const MAX_ENEMY_DISTANCE_FROM_KING := 1700.0
const SPEARMAN_ID := &"dai_viet_spearman"
const HOLD_MOVE_STOP_RADIUS := 52.0
const HOLD_MOVE_FULL_SPEED_RADIUS := 190.0

@onready var backdrop: MovementArenaBackdrop = %Backdrop
@onready var enemy_spawn_director: EnemySpawnDirector = %EnemySpawnDirector
@onready var combat_drop_director: CombatDropDirector = %CombatDropDirector
@onready var projectile_pool: EnemyProjectilePool = %EnemyProjectilePool
@onready var army_controller: ArmyController = %ArmyController
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
@onready var run_gold_label: Label = %RunGoldLabel
@onready var army_capacity_label: Label = %ArmyCapacityLabel
@onready var summon_button: Button = %SummonButton
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
var _enemy_configs: Dictionary = {}
var _unit_configs: Dictionary = {}
var _training_enemies: Dictionary = {}
var _gold_pickups: Dictionary = {}
var _healing_pickups: Dictionary = {}
var _next_pickup_serial := 1
var _snapshot_accumulator := 0.0
var _density_rebalance_accumulator := 0.0
var _skip_exit_snapshot := false
var _hold_mouse_active := false
var _hold_touch_index := -1
var _hold_pointer_position := Vector2.ZERO


func _ready() -> void:
	if not GameServices.initialize():
		push_error("Combat arena could not initialize game services.")
		return
	if not GameSessionService.has_active_session():
		GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", int(Time.get_ticks_usec() & 0x7fffffff))

	_king_config = ContentDatabase.get_king(&"tran_hung_dao")
	_load_enemy_configs()
	_load_unit_configs()
	king.configure(_king_config)
	king.clear_movement_bounds()
	king.global_position = GameSessionService.get_king_position(KING_SPAWN)
	king.restore_health(GameSessionService.get_king_health(king.health.max_health))
	var army_capacity_data: Dictionary = _king_config.get("army_capacity", {})
	army_controller.configure(
		king,
		int(army_capacity_data.get("max", 20)),
		_unit_configs,
		GameSessionService.get_army_state()
	)
	_configure_infinite_world()
	enemy_spawn_director.spawn_requested.connect(_on_spawn_requested)
	_restore_or_create_training_encounter()

	joystick.direction_changed.connect(king.set_virtual_direction)
	back_button.pressed.connect(_return_to_menu)
	summon_button.pressed.connect(_summon_spearman)
	retry_button.pressed.connect(_restart_combat_drill)
	defeat_back_button.pressed.connect(_return_to_menu)
	king.defeated.connect(_on_king_defeated)
	king.health.health_changed.connect(_on_king_health_changed)
	king.auto_attack.target_changed.connect(_on_target_changed)
	RewardGrantService.run_gold_granted.connect(_on_run_gold_granted)
	RewardGrantService.run_gold_spent.connect(_on_run_gold_spent)
	army_controller.capacity_changed.connect(_on_army_capacity_changed)
	army_controller.unit_summoned.connect(_on_unit_summoned)
	army_controller.unit_died.connect(_on_unit_died)
	LocalizationService.locale_changed.connect(_on_locale_changed)
	get_window().focus_exited.connect(_clear_hold_movement)
	_refresh_static_text()
	_refresh_live_text()
	death_overlay.visible = not king.is_combat_alive()
	enemy_spawn_director.set_active(king.is_combat_alive())


func _physics_process(delta: float) -> void:
	_update_hold_move_direction()
	if king.is_combat_alive():
		GameSessionService.advance(delta)
		enemy_spawn_director.ensure_population(_living_enemy_count(), _get_elapsed_time())
		_density_rebalance_accumulator += delta
		if _density_rebalance_accumulator >= DENSITY_REBALANCE_INTERVAL_SEC:
			_density_rebalance_accumulator = 0.0
			_recycle_distant_enemies()
	_snapshot_accumulator += delta
	if _snapshot_accumulator < SNAPSHOT_INTERVAL_SEC:
		return
	_snapshot_accumulator = 0.0
	_store_combat_state()
	_refresh_live_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _hold_touch_index == -1 and king.is_combat_alive():
			_hold_mouse_active = true
			_hold_pointer_position = event.position
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.pressed:
		if _hold_touch_index == -1 and king.is_combat_alive():
			_hold_touch_index = event.index
			_hold_pointer_position = event.position
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("summon_spearman"):
		get_viewport().set_input_as_handled()
		_summon_spearman()
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _hold_mouse_active:
			_clear_hold_movement()
		return
	if event is InputEventMouseMotion and _hold_mouse_active:
		_hold_pointer_position = event.position
		return
	if event is InputEventScreenDrag and event.index == _hold_touch_index:
		_hold_pointer_position = event.position
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == _hold_touch_index:
		_clear_hold_movement()


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


func _load_enemy_configs() -> void:
	_enemy_configs.clear()
	var spawn_roster: Array[Dictionary] = []
	for enemy_id in ContentDatabase.get_enemy_ids():
		var enemy_config := ContentDatabase.get_enemy(StringName(enemy_id))
		if enemy_config.is_empty():
			continue
		_enemy_configs[enemy_id] = enemy_config
		var spawn_data: Dictionary = enemy_config.get("spawn", {})
		spawn_roster.append({"enemy_id": enemy_id, "weight": float(spawn_data.get("weight", 1.0))})
	enemy_spawn_director.set_spawn_roster(spawn_roster)


func _load_unit_configs() -> void:
	_unit_configs.clear()
	for unit_id in ContentDatabase.get_unit_ids_for_faction(GameSessionService.active_session.faction_id):
		var unit_config := ContentDatabase.get_unit(StringName(unit_id))
		if not unit_config.is_empty():
			_unit_configs[unit_id] = unit_config


func _restore_or_create_training_encounter() -> void:
	var state := GameSessionService.get_enemy_combat_state()
	var spawn_runtime_state: Dictionary = state.get("spawn_runtime_state", {})
	enemy_spawn_director.configure(GameSessionService.active_session.seed, king, spawn_runtime_state)
	combat_drop_director.configure(
		GameSessionService.active_session.seed,
		state.get("drop_runtime_state", {})
	)
	_next_pickup_serial = maxi(int(state.get("next_pickup_serial", 1)), 1)
	var encounter_id := str(state.get("encounter_id", ""))
	if encounter_id in ["phase2_combat_drill", "phase2_endless_combat", "phase3_endless_goblins", "phase4_survival_projectiles"]:
		var living_value: Variant = state.get("living_enemies", [])
		if living_value is Array:
			for snapshot_value in living_value:
				if snapshot_value is Dictionary:
					_restore_goblin(snapshot_value)
		var pickup_value: Variant = state.get("gold_pickups", [])
		if pickup_value is Array:
			for pickup_snapshot in pickup_value:
				if pickup_snapshot is Dictionary:
					_restore_gold_pickup(pickup_snapshot)
		var healing_value: Variant = state.get("healing_pickups", [])
		if healing_value is Array:
			for pickup_snapshot in healing_value:
				if pickup_snapshot is Dictionary:
					_restore_healing_pickup(pickup_snapshot)
		enemy_spawn_director.ensure_population(_living_enemy_count(), _get_elapsed_time())
		return

	enemy_spawn_director.ensure_population(0, _get_elapsed_time(), true)


func _restore_goblin(snapshot: Dictionary) -> void:
	var instance_key := str(snapshot.get("instance_id", ""))
	if instance_key.is_empty():
		return
	var position_data: Dictionary = snapshot.get("position", {})
	var restored_position := Vector2(
		float(position_data.get("x", king.global_position.x)),
		float(position_data.get("y", king.global_position.y))
	)
	var enemy_id := StringName(str(snapshot.get("enemy_id", "goblin")))
	_create_goblin(
		instance_key,
		enemy_id,
		restored_position,
		float(snapshot.get("health", -1.0)),
		bool(snapshot.get("engaged", false))
	)


func _restore_gold_pickup(snapshot: Dictionary) -> void:
	var pickup_id := str(snapshot.get("pickup_id", ""))
	if pickup_id.is_empty():
		return
	var position_data: Dictionary = snapshot.get("position", {})
	var restored_position := Vector2(
		float(position_data.get("x", king.global_position.x)),
		float(position_data.get("y", king.global_position.y))
	)
	_create_gold_pickup(pickup_id, restored_position, int(snapshot.get("amount", 1)))


func _restore_healing_pickup(snapshot: Dictionary) -> void:
	var pickup_id := str(snapshot.get("pickup_id", ""))
	if pickup_id.is_empty():
		return
	var position_data: Dictionary = snapshot.get("position", {})
	var restored_position := Vector2(
		float(position_data.get("x", king.global_position.x)),
		float(position_data.get("y", king.global_position.y))
	)
	_create_healing_pickup(
		pickup_id,
		restored_position,
		float(snapshot.get("max_health_fraction", 0.14))
	)


func _create_goblin(
	instance_key: String,
	enemy_id: StringName,
	world_position: Vector2,
	restored_health: float,
	restored_engaged: bool = false
) -> void:
	if _training_enemies.has(instance_key) and is_instance_valid(_training_enemies[instance_key]):
		return
	var goblin := GOBLIN_SCENE.instantiate() as GoblinController
	if goblin == null:
		push_error("Goblin scene could not be instantiated.")
		return
	var enemy_config: Dictionary = _enemy_configs.get(str(enemy_id), _enemy_configs.get("goblin", {}))
	if enemy_config.is_empty():
		push_error("Enemy config could not be resolved: %s" % enemy_id)
		goblin.queue_free()
		return
	goblin.global_position = world_position
	add_child(goblin)
	goblin.configure(enemy_config, instance_key, restored_health, restored_engaged)
	goblin.set_target(king)
	goblin.defeated.connect(_on_enemy_defeated)
	goblin.projectile_requested.connect(projectile_pool.request_projectile)
	_training_enemies[instance_key] = goblin


func _create_gold_pickup(pickup_id: String, world_position: Vector2, amount: int) -> void:
	if _gold_pickups.has(pickup_id) and is_instance_valid(_gold_pickups[pickup_id]):
		return
	var pickup := RUN_GOLD_PICKUP_SCENE.instantiate() as RunGoldPickup
	if pickup == null:
		push_error("Run Gold pickup scene could not be instantiated.")
		return
	pickup.configure(pickup_id, amount)
	pickup.global_position = world_position
	add_child(pickup)
	pickup.collected.connect(_on_gold_collected)
	_gold_pickups[pickup_id] = pickup


func _create_healing_pickup(
	pickup_id: String,
	world_position: Vector2,
	max_health_fraction: float
) -> void:
	if _healing_pickups.has(pickup_id) and is_instance_valid(_healing_pickups[pickup_id]):
		return
	var pickup := HEALING_ORB_PICKUP_SCENE.instantiate() as HealingOrbPickup
	if pickup == null:
		push_error("Healing Orb pickup scene could not be instantiated.")
		return
	pickup.configure(pickup_id, max_health_fraction)
	pickup.global_position = world_position
	add_child(pickup)
	pickup.collected.connect(_on_healing_orb_collected)
	_healing_pickups[pickup_id] = pickup


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
	var gold_pickup_snapshots: Array[Dictionary] = []
	for pickup_value in _gold_pickups.values():
		var pickup := pickup_value as RunGoldPickup
		if is_instance_valid(pickup):
			gold_pickup_snapshots.append(pickup.get_combat_snapshot())
	var healing_pickup_snapshots: Array[Dictionary] = []
	for pickup_value in _healing_pickups.values():
		var pickup := pickup_value as HealingOrbPickup
		if is_instance_valid(pickup):
			healing_pickup_snapshots.append(pickup.get_combat_snapshot())
	GameSessionService.set_enemy_combat_state(
		living_enemies,
		enemy_spawn_director.get_runtime_snapshot(),
		gold_pickup_snapshots,
		_next_pickup_serial,
		healing_pickup_snapshots,
		combat_drop_director.get_runtime_snapshot()
	)
	GameSessionService.set_army_state(army_controller.get_army_snapshot())


func _living_enemy_count() -> int:
	return _training_enemies.size()


func _get_elapsed_time() -> float:
	return GameSessionService.active_session.elapsed_time if GameSessionService.active_session != null else 0.0


func _recycle_distant_enemies() -> void:
	var maximum_distance_squared := MAX_ENEMY_DISTANCE_FROM_KING * MAX_ENEMY_DISTANCE_FROM_KING
	var recycled_any := false
	for instance_key in _training_enemies.keys():
		var enemy := _training_enemies[instance_key] as GoblinController
		if not is_instance_valid(enemy):
			_training_enemies.erase(instance_key)
			continue
		if king.global_position.distance_squared_to(enemy.global_position) <= maximum_distance_squared:
			continue
		_training_enemies.erase(instance_key)
		enemy.retire_without_reward()
		enemy.queue_free()
		enemy_spawn_director.schedule_replacement(0.35)
		recycled_any = true
	if recycled_any:
		_store_combat_state()


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
	var elapsed_time := _get_elapsed_time()
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
	enemy_count_label.text = LocalizationService.translate_key(
		"phase2.enemy_count",
		{"count": living_count, "target": enemy_spawn_director.get_target_population(elapsed_time)}
	)
	run_gold_label.text = LocalizationService.translate_key(
		"phase2.run_gold",
		{"amount": RewardGrantService.get_run_gold()}
	)
	army_capacity_label.text = LocalizationService.translate_key(
		"phase4.army_capacity",
		{"used": army_controller.get_used_capacity(), "max": army_controller.maximum_capacity}
	)
	var spearman_config: Dictionary = _unit_configs.get(str(SPEARMAN_ID), {})
	var summon_data: Dictionary = spearman_config.get("summon", {})
	summon_button.text = LocalizationService.translate_key(
		"phase4.summon_spearman",
		{
			"cost": int(summon_data.get("run_gold_cost", 0)),
			"capacity": int(summon_data.get("capacity_cost", 0)),
		}
	)
	summon_button.disabled = not army_controller.can_summon(SPEARMAN_ID)
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
		target_label.text = LocalizationService.translate_key("phase2.reinforcements")
	else:
		target_label.text = LocalizationService.translate_key("phase2.no_target")


func _on_enemy_defeated(enemy: GoblinController, _context: Dictionary) -> void:
	var defeated_position := enemy.global_position
	_training_enemies.erase(enemy.instance_id)
	var pickup_id := "run_gold_%08d" % _next_pickup_serial
	_next_pickup_serial += 1
	var enemy_config: Dictionary = _enemy_configs.get(str(enemy.enemy_id), {})
	var reward_data: Dictionary = enemy_config.get("rewards", {})
	_create_gold_pickup(pickup_id, defeated_position, maxi(int(reward_data.get("run_gold", 1)), 1))
	var healing_drop := combat_drop_director.roll_healing_pickup(reward_data)
	if not healing_drop.is_empty():
		_create_healing_pickup(
			str(healing_drop.get("pickup_id", "")),
			defeated_position + Vector2(42.0, 0.0),
			float(healing_drop.get("max_health_fraction", 0.14))
		)
	enemy_spawn_director.schedule_replacement()
	get_tree().create_timer(DEFEATED_ENEMY_CLEANUP_SEC).timeout.connect(enemy.queue_free)
	_store_combat_state()
	_refresh_live_text()


func _on_spawn_requested(instance_key: String, enemy_id: StringName, world_position: Vector2) -> void:
	_create_goblin(instance_key, enemy_id, world_position, -1.0)
	_store_combat_state()
	_refresh_live_text()


func _on_gold_collected(pickup: RunGoldPickup, _amount: int) -> void:
	_gold_pickups.erase(pickup.pickup_id)
	_store_combat_state()
	_refresh_live_text()


func _on_healing_orb_collected(pickup: HealingOrbPickup, _applied_healing: float) -> void:
	_healing_pickups.erase(pickup.pickup_id)
	_store_combat_state()
	_refresh_live_text()


func _on_run_gold_granted(_amount: int, _total: int, _context: Dictionary) -> void:
	_refresh_live_text()


func _on_run_gold_spent(_amount: int, _total: int, _context: Dictionary) -> void:
	_refresh_live_text()


func _summon_spearman() -> void:
	var result := army_controller.try_summon(SPEARMAN_ID)
	if bool(result.get("accepted", false)):
		_store_combat_state()
	_refresh_live_text()


func _on_army_capacity_changed(_used: int, _maximum: int) -> void:
	_refresh_live_text()


func _on_unit_summoned(_unit: SummonedUnitController) -> void:
	_store_combat_state()
	_refresh_live_text()


func _on_unit_died(_unit_id: StringName, _context: Dictionary) -> void:
	_store_combat_state()
	_refresh_live_text()


func _on_king_defeated(_context: Dictionary) -> void:
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	_clear_hold_movement()
	enemy_spawn_director.set_active(false)
	projectile_pool.set_combat_enabled(false)
	army_controller.set_combat_enabled(false)
	for enemy_value in _training_enemies.values():
		var enemy := enemy_value as GoblinController
		if is_instance_valid(enemy):
			enemy.set_target(king)
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
	_clear_hold_movement()
	enemy_spawn_director.set_active(false)
	projectile_pool.set_combat_enabled(false)
	army_controller.set_combat_enabled(false)
	_store_combat_state()
	SceneService.change_scene_to_file("res://scenes/menus/main_menu.tscn")


func _update_hold_move_direction() -> void:
	if not (_hold_mouse_active or _hold_touch_index != -1) or not is_instance_valid(king) or not king.is_combat_alive():
		if is_instance_valid(king):
			king.set_pointer_direction(Vector2.ZERO)
		return
	var king_screen_position := get_viewport().get_canvas_transform() * king.global_position
	king.set_pointer_direction(HoldMoveInput.direction_from_screen_points(
		_hold_pointer_position,
		king_screen_position,
		HOLD_MOVE_STOP_RADIUS,
		HOLD_MOVE_FULL_SPEED_RADIUS
	))


func _clear_hold_movement() -> void:
	_hold_mouse_active = false
	_hold_touch_index = -1
	if is_instance_valid(king):
		king.set_pointer_direction(Vector2.ZERO)
