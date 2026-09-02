extends Node2D

const GOBLIN_SCENE := preload("res://scenes/gameplay/goblin.tscn")
const BOSS_SCENE := preload("res://scenes/gameplay/boss.tscn")
const RUN_GOLD_PICKUP_SCENE := preload("res://scenes/gameplay/run_gold_pickup.tscn")
const HEALING_ORB_PICKUP_SCENE := preload("res://scenes/gameplay/healing_orb_pickup.tscn")
const KING_SPAWN := Vector2.ZERO
const SNAPSHOT_INTERVAL_SEC := 0.15
const EFFECTIVE_CAMERA_LIMIT := 2147480000
const DEFEATED_ENEMY_CLEANUP_SEC := 0.7
const DENSITY_REBALANCE_INTERVAL_SEC := 1.0
const MAX_ENEMY_DISTANCE_FROM_KING := 1700.0
const HOLD_MOVE_STOP_RADIUS := 52.0
const HOLD_MOVE_FULL_SPEED_RADIUS := 190.0

@onready var backdrop: MovementArenaBackdrop = %Backdrop
@onready var enemy_spawn_director: EnemySpawnDirector = %EnemySpawnDirector
@onready var boss_director: BossDirector = %BossDirector
@onready var combat_drop_director: CombatDropDirector = %CombatDropDirector
@onready var projectile_pool: EnemyProjectilePool = %EnemyProjectilePool
@onready var ally_projectile_pool: AllyProjectilePool = %AllyProjectilePool
@onready var army_controller: ArmyController = %ArmyController
@onready var king_skill_runtime: KingSkillRuntime = %KingSkillRuntime
@onready var king_active_skill_controller: KingActiveSkillController = %KingActiveSkillController
@onready var king_progression_controller: KingProgressionController = %KingProgressionController
@onready var king: KingController = %King
@onready var joystick: MovementJoystick = %VirtualJoystick
@onready var arena_title_label: Label = %ArenaTitleLabel
@onready var king_name_label: Label = %KingNameLabel
@onready var king_title_label: Label = %KingTitleLabel
@onready var position_label: Label = %PositionLabel
@onready var time_label: Label = %TimeLabel
@onready var enemy_count_label: Label = %EnemyCountLabel
@onready var run_gold_label: Label = %RunGoldLabel
@onready var army_capacity_label: Label = %ArmyCapacityLabel
@onready var summon_roster_label: Label = %SummonRosterLabel
@onready var summon_grid: GridContainer = %SummonGrid
@onready var summon_button_template: Button = %SummonButtonTemplate
@onready var upgrade_menu_button: Button = %UpgradeMenuButton
@onready var upgrade_overlay: Control = %UpgradeOverlay
@onready var upgrade_roster_label: Label = %UpgradeRosterLabel
@onready var upgrade_grid: GridContainer = %UpgradeGrid
@onready var upgrade_button_template: Button = %UpgradeButtonTemplate
@onready var upgrade_close_button: Button = %UpgradeCloseButton
@onready var active_skill_title_label: Label = %ActiveSkillTitleLabel
@onready var rage_label: Label = %RageLabel
@onready var rage_bar: ProgressBar = %RageBar
@onready var active_skill_button_1: Button = %ActiveSkillButton1
@onready var active_skill_button_2: Button = %ActiveSkillButton2
@onready var active_skill_button_3: Button = %ActiveSkillButton3
@onready var control_hint_label: Label = %ControlHintLabel
@onready var scope_hint_label: Label = %ScopeHintLabel
@onready var target_label: Label = %TargetLabel
@onready var back_button: Button = %BackButton
@onready var death_overlay: Control = %DeathOverlay
@onready var defeat_title_label: Label = %DefeatTitleLabel
@onready var defeat_detail_label: Label = %DefeatDetailLabel
@onready var retry_button: Button = %RetryButton
@onready var defeat_back_button: Button = %DefeatBackButton
@onready var level_up_overlay: Control = %LevelUpOverlay
@onready var level_up_title_label: Label = %LevelUpTitleLabel
@onready var level_up_hint_label: Label = %LevelUpHintLabel
@onready var skill_card_1: Button = %SkillCard1
@onready var skill_card_2: Button = %SkillCard2
@onready var skill_card_3: Button = %SkillCard3

var _king_config: Dictionary = {}
var _enemy_configs: Dictionary = {}
var _boss_configs: Dictionary = {}
var _threat_config: Dictionary = {}
var _unit_configs: Dictionary = {}
var _skill_configs: Dictionary = {}
var _training_enemies: Dictionary = {}
var _active_bosses: Dictionary = {}
var _gold_pickups: Dictionary = {}
var _healing_pickups: Dictionary = {}
var _next_pickup_serial := 1
var _next_boss_add_serial := 1
var _snapshot_accumulator := 0.0
var _density_rebalance_accumulator := 0.0
var _skip_exit_snapshot := false
var _hold_mouse_active := false
var _hold_touch_index := -1
var _hold_pointer_position := Vector2.ZERO
var _summon_buttons: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _unit_ids_by_hotkey: Dictionary = {}
var _current_skill_choices: Array[Dictionary] = []


func _ready() -> void:
	if not GameServices.initialize():
		push_error("Combat arena could not initialize game services.")
		return
	if not GameSessionService.has_active_session():
		GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", int(Time.get_ticks_usec() & 0x7fffffff))

	_king_config = AccountProgressionService.apply_to_king_config(
		ContentDatabase.get_king(&"tran_hung_dao"),
		GameSessionService.active_session.account_modifiers
	)
	_load_enemy_configs()
	_load_unit_configs()
	_load_skill_configs()
	king.configure(_king_config)
	king.auto_attack.set_projectile_pool(ally_projectile_pool)
	king.clear_movement_bounds()
	king.global_position = GameSessionService.get_king_position(KING_SPAWN)
	king_skill_runtime.configure(
		king,
		ally_projectile_pool,
		_skill_configs,
		GameSessionService.get_skill_state()
	)
	king.restore_health(GameSessionService.get_king_health(king.health.max_health))
	king_progression_controller.state_changed.connect(_on_progression_state_changed)
	king_progression_controller.level_up_started.connect(_on_level_up_started)
	king_progression_controller.level_up_completed.connect(_on_level_up_completed)
	king_progression_controller.configure(
		GameSessionService.active_session.seed,
		ContentDatabase.get_king_progression_config(),
		_skill_configs,
		king_skill_runtime,
		GameSessionService.active_session.run_level,
		GameSessionService.active_session.run_xp,
		GameSessionService.get_skill_state(),
		GameSessionService.get_progression_rng_state()
	)
	king_active_skill_controller.configure(
		king,
		ally_projectile_pool,
		ContentDatabase.get_active_skill_system(),
		ContentDatabase.get_active_skill_loadout(king.king_id),
		GameSessionService.get_active_skill_state()
	)
	var army_capacity_data: Dictionary = _king_config.get("army_capacity", {})
	army_controller.configure(
		king,
		int(army_capacity_data.get("max", 20)),
		_unit_configs,
		GameSessionService.get_army_state(),
		ally_projectile_pool,
		bool(army_capacity_data.get("unlimited", false)),
		GameSessionService.get_army_upgrade_state()
	)
	GameSessionService.set_run_stat_maximum(&"max_army_size", army_controller.get_living_unit_count())
	_build_summon_controls()
	_build_upgrade_controls()
	_configure_infinite_world()
	enemy_spawn_director.spawn_requested.connect(_on_spawn_requested)
	boss_director.boss_spawn_requested.connect(_on_boss_spawn_requested)
	_restore_or_create_training_encounter()

	joystick.direction_changed.connect(king.set_virtual_direction)
	back_button.pressed.connect(_return_to_menu)
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
	army_controller.upgrade_changed.connect(_on_army_upgrade_changed)
	upgrade_menu_button.pressed.connect(_open_upgrade_overlay)
	upgrade_close_button.pressed.connect(_close_upgrade_overlay)
	active_skill_button_1.pressed.connect(_cast_active_skill.bind(1))
	active_skill_button_2.pressed.connect(_cast_active_skill.bind(2))
	active_skill_button_3.pressed.connect(_cast_active_skill.bind(3))
	king_active_skill_controller.resource_changed.connect(_on_active_skill_state_changed)
	king_active_skill_controller.skill_state_changed.connect(_on_active_skill_state_changed)
	king_active_skill_controller.skill_cast.connect(_on_active_skill_cast)
	skill_card_1.pressed.connect(_select_skill_choice.bind(0))
	skill_card_2.pressed.connect(_select_skill_choice.bind(1))
	skill_card_3.pressed.connect(_select_skill_choice.bind(2))
	LocalizationService.locale_changed.connect(_on_locale_changed)
	get_window().focus_exited.connect(_clear_hold_movement)
	_refresh_static_text()
	_refresh_live_text()
	death_overlay.visible = not king.is_combat_alive()
	if death_overlay.visible:
		_settle_defeated_run()
		defeat_detail_label.text = LocalizationService.translate_key("phase8.defeat_summary", _build_battle_result())
	enemy_spawn_director.set_active(king.is_combat_alive())


func _physics_process(delta: float) -> void:
	_update_hold_move_direction()
	if king.is_combat_alive():
		GameSessionService.advance(delta)
		var elapsed_time := _get_elapsed_time()
		boss_director.update(elapsed_time, not _active_bosses.is_empty())
		enemy_spawn_director.set_pressure_multiplier(boss_director.get_pressure_multiplier(elapsed_time, not _active_bosses.is_empty()))
		enemy_spawn_director.ensure_population(_living_enemy_count(), elapsed_time)
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
	if event.is_action_pressed("toggle_unit_upgrades"):
		get_viewport().set_input_as_handled()
		_open_upgrade_overlay()
		return
	if upgrade_overlay.visible:
		return
	for skill_slot in range(1, 4):
		if event.is_action_pressed("active_skill_%d" % skill_slot):
			get_viewport().set_input_as_handled()
			_cast_active_skill(skill_slot)
			return
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
	for hotkey_slot in range(1, 8):
		if event.is_action_pressed("summon_unit_%d" % hotkey_slot):
			get_viewport().set_input_as_handled()
			var unit_id := StringName(str(_unit_ids_by_hotkey.get(hotkey_slot, "")))
			if not unit_id.is_empty():
				_summon_unit(unit_id)
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
	GameSessionService.pause_manager.clear_pause(PauseManager.ARMY_UPGRADE)
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
	_boss_configs.clear()
	_threat_config = ContentDatabase.get_goblin_threat_progression()
	var spawn_roster: Array[Dictionary] = []
	for enemy_id in ContentDatabase.get_enemy_ids():
		var enemy_config := ContentDatabase.get_enemy(StringName(enemy_id))
		if enemy_config.is_empty():
			continue
		enemy_config["contact_damage"] = _threat_config.get("contact_damage", {}).duplicate(true)
		_enemy_configs[enemy_id] = enemy_config
		var spawn_data: Dictionary = enemy_config.get("spawn", {})
		spawn_roster.append({
			"enemy_id": enemy_id,
			"weight": float(spawn_data.get("weight", 1.0)),
			"cost": int(spawn_data.get("cost", 1)),
			"unlock_minute": float(spawn_data.get("unlock_minute", 0.0)),
			"tags": spawn_data.get("tags", []).duplicate(),
		})
	for boss_config in ContentDatabase.get_goblin_bosses():
		_boss_configs[str(boss_config.get("id", ""))] = boss_config
	enemy_spawn_director.set_spawn_roster(spawn_roster)
	enemy_spawn_director.set_threat_config(
		_threat_config,
		PlatformService.get_platform_name(),
		GameSessionService.active_session.difficulty
	)


func _load_unit_configs() -> void:
	_unit_configs.clear()
	for unit_id in ContentDatabase.get_unit_ids_for_faction(GameSessionService.active_session.faction_id):
		var unit_config := ContentDatabase.get_unit(StringName(unit_id))
		if not unit_config.is_empty():
			_unit_configs[unit_id] = unit_config


func _load_skill_configs() -> void:
	_skill_configs.clear()
	for skill_id in ContentDatabase.get_king_skill_ids():
		var skill_config := ContentDatabase.get_king_skill(StringName(skill_id))
		if not skill_config.is_empty():
			_skill_configs[str(skill_id)] = skill_config


func _build_summon_controls() -> void:
	_summon_buttons.clear()
	_unit_ids_by_hotkey.clear()
	for child in summon_grid.get_children():
		if child != summon_button_template:
			child.queue_free()
	var ordered_ids: Array = _unit_configs.keys()
	ordered_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_summon: Dictionary = _unit_configs.get(str(left), {}).get("summon", {})
		var right_summon: Dictionary = _unit_configs.get(str(right), {}).get("summon", {})
		return int(left_summon.get("hotkey_slot", 99)) < int(right_summon.get("hotkey_slot", 99))
	)
	for unit_id_value in ordered_ids:
		var unit_id := str(unit_id_value)
		var config: Dictionary = _unit_configs.get(unit_id, {})
		var summon_data: Dictionary = config.get("summon", {})
		var hotkey_slot := int(summon_data.get("hotkey_slot", 0))
		var button := summon_button_template.duplicate() as Button
		if button == null:
			continue
		button.name = "SummonUnit%d" % hotkey_slot
		button.visible = true
		button.set_meta("unit_id", unit_id)
		button.pressed.connect(_summon_unit.bind(StringName(unit_id)))
		summon_grid.add_child(button)
		_summon_buttons[unit_id] = button
		_unit_ids_by_hotkey[hotkey_slot] = unit_id


func _build_upgrade_controls() -> void:
	_upgrade_buttons.clear()
	for child in upgrade_grid.get_children():
		if child != upgrade_button_template:
			child.queue_free()
	var ordered_ids: Array = _unit_configs.keys()
	ordered_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_summon: Dictionary = _unit_configs.get(str(left), {}).get("summon", {})
		var right_summon: Dictionary = _unit_configs.get(str(right), {}).get("summon", {})
		return int(left_summon.get("hotkey_slot", 99)) < int(right_summon.get("hotkey_slot", 99))
	)
	for unit_id_value in ordered_ids:
		var unit_id := str(unit_id_value)
		var button := upgrade_button_template.duplicate() as Button
		if button == null:
			continue
		button.name = "UpgradeUnit%s" % unit_id.to_pascal_case()
		button.visible = true
		button.set_meta("unit_id", unit_id)
		button.pressed.connect(_upgrade_unit.bind(StringName(unit_id)))
		upgrade_grid.add_child(button)
		_upgrade_buttons[unit_id] = button


func _restore_or_create_training_encounter() -> void:
	var state := GameSessionService.get_enemy_combat_state()
	var boss_state := GameSessionService.get_boss_state()
	var spawn_runtime_state: Dictionary = state.get("spawn_runtime_state", {})
	enemy_spawn_director.configure(GameSessionService.active_session.seed, king, spawn_runtime_state)
	boss_director.configure(
		GameSessionService.active_session.seed,
		_threat_config,
		king,
		GameSessionService.active_session.difficulty,
		boss_state.get("director_state", {})
	)
	_next_boss_add_serial = maxi(int(boss_state.get("next_add_serial", 1)), 1)
	var active_bosses_value: Variant = boss_state.get("active_bosses", [])
	if active_bosses_value is Array:
		for boss_snapshot in active_bosses_value:
			if boss_snapshot is Dictionary:
				_restore_boss(boss_snapshot)
	combat_drop_director.configure(
		GameSessionService.active_session.seed,
		state.get("drop_runtime_state", {})
	)
	_next_pickup_serial = maxi(int(state.get("next_pickup_serial", 1)), 1)
	var encounter_id := str(state.get("encounter_id", ""))
	if encounter_id in ["phase2_combat_drill", "phase2_endless_combat", "phase3_endless_goblins", "phase4_survival_projectiles", "phase6_goblin_threat"]:
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
		bool(snapshot.get("engaged", false)),
		snapshot.get("runtime_modifiers", {})
	)


func _restore_boss(snapshot: Dictionary) -> void:
	var boss_id := str(snapshot.get("boss_id", snapshot.get("enemy_id", "")))
	var boss_config: Dictionary = _boss_configs.get(boss_id, {})
	if boss_config.is_empty():
		return
	var position_data: Dictionary = snapshot.get("position", {})
	_create_boss({
		"instance_id": str(snapshot.get("instance_id", "")),
		"boss_id": boss_id,
		"boss_config": boss_config,
		"position": Vector2(float(position_data.get("x", king.global_position.x)), float(position_data.get("y", king.global_position.y))),
		"ascendant_cycle": int(snapshot.get("ascendant_cycle", 0)),
		"runtime_modifiers": snapshot.get("runtime_modifiers", {}),
	}, snapshot)


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
	restored_engaged: bool = false,
	runtime_modifiers: Dictionary = {}
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
	goblin.configure(enemy_config, instance_key, restored_health, restored_engaged, runtime_modifiers)
	goblin.set_target(king)
	goblin.defeated.connect(_on_enemy_defeated)
	goblin.projectile_requested.connect(projectile_pool.request_projectile)
	_training_enemies[instance_key] = goblin


func _create_boss(request: Dictionary, restored_snapshot: Dictionary = {}) -> void:
	var instance_key := str(request.get("instance_id", ""))
	if instance_key.is_empty() or (_active_bosses.has(instance_key) and is_instance_valid(_active_bosses[instance_key])):
		return
	var boss_config: Dictionary = request.get("boss_config", {})
	var boss_id := str(request.get("boss_id", boss_config.get("id", "")))
	if boss_config.is_empty():
		boss_config = _boss_configs.get(boss_id, {})
	var base_enemy_config: Dictionary = _enemy_configs.get(str(boss_config.get("base_enemy_id", "goblin_brute")), {})
	if boss_config.is_empty() or base_enemy_config.is_empty():
		push_error("Boss config could not be resolved: %s" % boss_id)
		return
	var boss := BOSS_SCENE.instantiate() as BossController
	if boss == null:
		push_error("Boss scene could not be instantiated.")
		return
	boss.global_position = request.get("position", king.global_position + Vector2(720.0, 0.0))
	add_child(boss)
	var runtime: Dictionary = request.get("runtime_modifiers", {}).duplicate(true)
	runtime["ascendant_cycle"] = int(request.get("ascendant_cycle", restored_snapshot.get("ascendant_cycle", 0)))
	boss.configure_boss(
		boss_config,
		base_enemy_config,
		instance_key,
		LocalizationService.translate_key(str(boss_config.get("name_key", boss_id))),
		runtime,
		restored_snapshot
	)
	boss.set_target(king)
	boss.defeated.connect(_on_enemy_defeated)
	boss.projectile_requested.connect(projectile_pool.request_projectile)
	boss.boss_add_requested.connect(_on_boss_add_requested)
	_active_bosses[instance_key] = boss


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
	var active_boss_snapshots: Array[Dictionary] = []
	for boss_value in _active_bosses.values():
		var boss := boss_value as BossController
		if is_instance_valid(boss) and boss.is_combat_alive():
			active_boss_snapshots.append(boss.get_combat_snapshot())
	GameSessionService.set_boss_state(
		boss_director.get_runtime_snapshot(),
		active_boss_snapshots,
		_next_boss_add_serial
	)
	GameSessionService.set_army_state(army_controller.get_army_snapshot())
	GameSessionService.set_army_upgrade_state(army_controller.get_upgrade_levels())
	GameSessionService.set_active_skill_state(king_active_skill_controller.get_runtime_snapshot())


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
	summon_roster_label.text = LocalizationService.translate_key("phase4.summon_roster")
	upgrade_menu_button.text = LocalizationService.translate_key("phase5.open_upgrades")
	upgrade_roster_label.text = LocalizationService.translate_key("phase5.upgrade_roster")
	upgrade_close_button.text = LocalizationService.translate_key("phase5.close_upgrades")
	active_skill_title_label.text = LocalizationService.translate_key("phase7.active_skills")
	level_up_title_label.text = LocalizationService.translate_key("phase5.level_up_title")
	level_up_hint_label.text = LocalizationService.translate_key("phase5.level_up_hint")
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
	king.set_level_display(LocalizationService.translate_key(
		"phase6.king_level_short",
		{"level": king_progression_controller.get_run_level()}
	))
	var living_count := _living_enemy_count() + _active_bosses.size()
	enemy_count_label.text = LocalizationService.translate_key(
		"phase2.enemy_count",
		{"count": living_count, "target": enemy_spawn_director.get_target_population(elapsed_time)}
	)
	run_gold_label.text = LocalizationService.translate_key(
		"phase2.run_gold",
		{"amount": RewardGrantService.get_run_gold()}
	)
	_refresh_active_skill_hud()
	if army_controller.unlimited_summons:
		army_capacity_label.text = LocalizationService.translate_key(
			"phase5.army_unlimited",
			{"count": army_controller.get_living_unit_count()}
		)
	else:
		army_capacity_label.text = LocalizationService.translate_key(
			"phase4.army_capacity",
			{"used": army_controller.get_used_capacity(), "max": army_controller.maximum_capacity}
		)
	for unit_id_value in _summon_buttons:
		var unit_id := str(unit_id_value)
		var button := _summon_buttons[unit_id] as Button
		if not is_instance_valid(button):
			continue
		var unit_config: Dictionary = _unit_configs.get(unit_id, {})
		var summon_data: Dictionary = unit_config.get("summon", {})
		button.text = LocalizationService.translate_key(
			"phase5.summon_unit_unlimited" if army_controller.unlimited_summons else "phase4.summon_unit",
			{
				"hotkey": int(summon_data.get("hotkey_slot", 0)),
				"name": LocalizationService.translate_key(str(unit_config.get("name_key", unit_id))),
				"cost": int(summon_data.get("run_gold_cost", 0)),
				"capacity": int(summon_data.get("capacity_cost", 0)),
			}
		)
		button.disabled = not army_controller.can_summon(StringName(unit_id))
	for unit_id_value in _upgrade_buttons:
		var unit_id := str(unit_id_value)
		var button := _upgrade_buttons[unit_id] as Button
		if not is_instance_valid(button):
			continue
		var unit_config: Dictionary = _unit_configs.get(unit_id, {})
		var upgrade_data: Dictionary = unit_config.get("upgrade", {})
		var level := army_controller.get_upgrade_level(StringName(unit_id))
		var max_level := int(upgrade_data.get("max_level", 0))
		if level >= max_level:
			button.text = LocalizationService.translate_key(
				"phase5.upgrade_unit_max",
				{
					"name": LocalizationService.translate_key(str(unit_config.get("name_key", unit_id))),
					"level": level,
				}
			)
		else:
			button.text = LocalizationService.translate_key(
				"phase5.upgrade_unit",
				{
					"name": LocalizationService.translate_key(str(unit_config.get("name_key", unit_id))),
					"level": level,
					"next": level + 1,
					"cost": army_controller.get_upgrade_cost(StringName(unit_id)),
				}
			)
		button.disabled = not army_controller.can_upgrade(StringName(unit_id))
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
	if death_overlay.visible:
		defeat_detail_label.text = LocalizationService.translate_key("phase8.defeat_summary", _build_battle_result())


func _on_enemy_defeated(enemy: GoblinController, _context: Dictionary) -> void:
	var defeated_position := enemy.global_position
	var defeated_boss := enemy as BossController
	if defeated_boss != null:
		GameSessionService.increment_run_stat(&"bosses_defeated")
		_active_bosses.erase(enemy.instance_id)
		boss_director.mark_defeated(defeated_boss.boss_id, enemy.instance_id, _get_elapsed_time())
	else:
		GameSessionService.increment_run_stat(&"enemies_defeated")
		_training_enemies.erase(enemy.instance_id)
	var pickup_id := "run_gold_%08d" % _next_pickup_serial
	_next_pickup_serial += 1
	var reward_data: Dictionary = defeated_boss.reward_data if defeated_boss != null else _enemy_configs.get(str(enemy.enemy_id), {}).get("rewards", {})
	RewardGrantService.grant_run_xp(
		maxi(int(reward_data.get("run_xp", 1)), 1),
		{"source_kind": "boss" if defeated_boss != null else "enemy", "source_id": str(enemy.enemy_id), "instance_id": enemy.instance_id}
	)
	_create_gold_pickup(pickup_id, defeated_position, maxi(int(reward_data.get("run_gold", 1)), 1))
	if defeated_boss == null:
		var healing_drop := combat_drop_director.roll_healing_pickup(reward_data)
		if not healing_drop.is_empty():
			_create_healing_pickup(
				str(healing_drop.get("pickup_id", "")),
				defeated_position + Vector2(42.0, 0.0),
				float(healing_drop.get("max_health_fraction", 0.14))
			)
		enemy_spawn_director.schedule_replacement()
	else:
		_create_healing_pickup("boss_heal_%08d" % _next_pickup_serial, defeated_position + Vector2(54.0, 0.0), 0.3)
		_next_pickup_serial += 1
	get_tree().create_timer(DEFEATED_ENEMY_CLEANUP_SEC).timeout.connect(enemy.queue_free)
	_store_combat_state()
	_refresh_live_text()


func _on_spawn_requested(request: Dictionary) -> void:
	_create_goblin(
		str(request.get("instance_id", "")),
		StringName(str(request.get("enemy_id", "goblin"))),
		request.get("position", king.global_position + Vector2(600.0, 0.0)),
		-1.0,
		false,
		request.get("runtime_modifiers", {})
	)
	_store_combat_state()
	_refresh_live_text()


func _on_boss_spawn_requested(request: Dictionary) -> void:
	_create_boss(request)
	_store_combat_state()
	_refresh_live_text()


func _on_boss_add_requested(request: Dictionary) -> void:
	var instance_key := "boss_add_%08d" % _next_boss_add_serial
	_next_boss_add_serial += 1
	_create_goblin(
		instance_key,
		StringName(str(request.get("enemy_id", "goblin"))),
		request.get("position", king.global_position + Vector2(520.0, 0.0)),
		-1.0,
		true,
		request.get("runtime_modifiers", {})
	)
	_store_combat_state()
	_refresh_live_text()


func _on_gold_collected(pickup: RunGoldPickup, amount: int) -> void:
	_gold_pickups.erase(pickup.pickup_id)
	GameSessionService.increment_run_stat(&"gold_collected", amount)
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


func _summon_unit(unit_id: StringName) -> void:
	var result := army_controller.try_summon(unit_id)
	if bool(result.get("accepted", false)):
		_store_combat_state()
	_refresh_live_text()


func _upgrade_unit(unit_id: StringName) -> void:
	var result := army_controller.try_upgrade(unit_id)
	if bool(result.get("accepted", false)):
		_store_combat_state()
		_refresh_live_text()


func _open_upgrade_overlay() -> void:
	if upgrade_overlay.visible or level_up_overlay.visible or death_overlay.visible or not king.is_combat_alive():
		return
	_clear_hold_movement()
	upgrade_overlay.visible = true
	GameSessionService.pause_manager.request_pause(PauseManager.ARMY_UPGRADE)
	_refresh_live_text()


func _close_upgrade_overlay() -> void:
	if not upgrade_overlay.visible:
		GameSessionService.pause_manager.clear_pause(PauseManager.ARMY_UPGRADE)
		return
	upgrade_overlay.visible = false
	GameSessionService.pause_manager.clear_pause(PauseManager.ARMY_UPGRADE)


func _on_army_capacity_changed(_used: int, _maximum: int) -> void:
	_refresh_live_text()


func _on_unit_summoned(_unit: SummonedUnitController) -> void:
	GameSessionService.set_run_stat_maximum(&"max_army_size", army_controller.get_living_unit_count())
	_store_combat_state()
	_refresh_live_text()


func _on_unit_died(_unit_id: StringName, _context: Dictionary) -> void:
	_store_combat_state()
	_refresh_live_text()


func _on_army_upgrade_changed(_unit_id: StringName, _level: int, _next_cost: int) -> void:
	_store_combat_state()
	_refresh_live_text()


func _on_progression_state_changed(_run_level: int, _run_xp: int, _xp_required: int) -> void:
	_refresh_live_text()


func _on_level_up_started(choices: Array[Dictionary]) -> void:
	_close_upgrade_overlay()
	_current_skill_choices = choices.duplicate(true)
	_refresh_level_up_choices()
	level_up_overlay.visible = true


func _on_level_up_completed(_skill_id: StringName, _new_skill_level: int) -> void:
	level_up_overlay.visible = false
	_current_skill_choices.clear()
	_store_combat_state()
	_refresh_live_text()


func _select_skill_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _current_skill_choices.size():
		return
	var choice: Dictionary = _current_skill_choices[choice_index]
	king_progression_controller.select_skill(StringName(str(choice.get("id", ""))))


func _refresh_level_up_choices() -> void:
	var cards: Array[Button] = [skill_card_1, skill_card_2, skill_card_3]
	for index in cards.size():
		var card := cards[index]
		if index >= _current_skill_choices.size():
			card.visible = false
			continue
		card.visible = true
		var choice: Dictionary = _current_skill_choices[index]
		card.text = LocalizationService.translate_key(
			"phase5.skill_card",
			{
				"name": LocalizationService.translate_key(str(choice.get("name_key", ""))),
				"current": int(choice.get("current_level", 0)),
				"next": int(choice.get("current_level", 0)) + 1,
				"max": int(choice.get("max_level", 0)),
				"description": LocalizationService.translate_key(str(choice.get("description_key", ""))),
			}
		)


func _on_king_defeated(_context: Dictionary) -> void:
	_close_upgrade_overlay()
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	_clear_hold_movement()
	enemy_spawn_director.set_active(false)
	projectile_pool.set_combat_enabled(false)
	ally_projectile_pool.set_combat_enabled(false)
	army_controller.set_combat_enabled(false)
	for enemy_value in _training_enemies.values():
		var enemy := enemy_value as GoblinController
		if is_instance_valid(enemy):
			enemy.set_target(king)
	for boss_value in _active_bosses.values():
		var boss := boss_value as BossController
		if is_instance_valid(boss):
			boss.set_target(king)
	death_overlay.visible = true
	var result := _build_battle_result()
	GameSessionService.active_session.battle_score = int(result.get("score", 0))
	RewardGrantService.settle_active_run(result)
	defeat_detail_label.text = LocalizationService.translate_key("phase8.defeat_summary", _build_battle_result())
	_store_combat_state()
	_refresh_live_text()


func _on_king_health_changed(_current: float, _maximum: float, _delta: float, _context: Dictionary) -> void:
	_refresh_live_text()


func _on_target_changed(_target: GoblinController) -> void:
	_refresh_live_text()


func _on_locale_changed(_locale: String) -> void:
	_refresh_static_text()
	_refresh_live_text()
	for boss_value in _active_bosses.values():
		var boss := boss_value as BossController
		if is_instance_valid(boss):
			boss.refresh_display_name(LocalizationService.translate_key(boss.name_key))
	if level_up_overlay.visible:
		_refresh_level_up_choices()


func _restart_combat_drill() -> void:
	_skip_exit_snapshot = true
	GameSessionService.pause_manager.clear_pause(PauseManager.LEVEL_UP)
	GameSessionService.pause_manager.clear_pause(PauseManager.ARMY_UPGRADE)
	if GameSessionService.has_active_session():
		GameSessionService.end_session(_build_battle_result())
	var session_seed := int(Time.get_ticks_usec() & 0x7fffffff)
	GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", session_seed)
	SceneService.change_scene_to_file("res://scenes/gameplay/movement_arena.tscn")


func _return_to_menu() -> void:
	joystick.reset()
	king.set_virtual_direction(Vector2.ZERO)
	_clear_hold_movement()
	enemy_spawn_director.set_active(false)
	projectile_pool.set_combat_enabled(false)
	ally_projectile_pool.set_combat_enabled(false)
	army_controller.set_combat_enabled(false)
	if king.is_combat_alive():
		_store_combat_state()
	else:
		_skip_exit_snapshot = true
		GameSessionService.end_session(_build_battle_result())
	GameSessionService.pause_manager.clear_pause(PauseManager.LEVEL_UP)
	GameSessionService.pause_manager.clear_pause(PauseManager.ARMY_UPGRADE)
	SceneService.change_scene_to_file("res://scenes/menus/main_menu.tscn")


func _cast_active_skill(slot: int) -> void:
	if upgrade_overlay.visible or level_up_overlay.visible or death_overlay.visible:
		return
	king_active_skill_controller.try_cast_slot(slot)
	_refresh_active_skill_hud()


func _on_active_skill_state_changed(_current: float = 0.0, _maximum: float = 0.0) -> void:
	_refresh_active_skill_hud()


func _on_active_skill_cast(_skill_id: StringName, _affected_targets: int) -> void:
	GameSessionService.increment_run_stat(&"active_skills_cast")
	_store_combat_state()
	_refresh_active_skill_hud()


func _refresh_active_skill_hud() -> void:
	if not is_instance_valid(king_active_skill_controller):
		return
	var current_rage := king_active_skill_controller.get_rage()
	var maximum_rage := king_active_skill_controller.get_maximum_rage()
	rage_bar.max_value = maximum_rage
	rage_bar.value = current_rage
	rage_label.text = LocalizationService.translate_key("phase7.rage", {"current": floori(current_rage), "max": floori(maximum_rage)})
	var buttons: Array[Button] = [active_skill_button_1, active_skill_button_2, active_skill_button_3]
	var hotkeys := ["Q", "E", "R"]
	for index in buttons.size():
		var slot := index + 1
		var button := buttons[index]
		var skill := king_active_skill_controller.get_skill_config(slot)
		var state := king_active_skill_controller.get_slot_state(slot)
		if skill.is_empty() or state.is_empty():
			button.visible = false
			continue
		button.visible = true
		var name := LocalizationService.translate_key(str(skill.get("name_key", "")))
		var cost := ceili(float(state.get("rage_cost", 0.0)))
		var cooldown := float(state.get("cooldown_remaining", 0.0))
		if cooldown > 0.0:
			button.text = LocalizationService.translate_key("phase7.skill_cooldown", {"hotkey": hotkeys[index], "name": name, "cooldown": snappedf(cooldown, 0.1)})
		elif not bool(state.get("has_rage", false)):
			button.text = LocalizationService.translate_key("phase7.skill_no_rage", {"hotkey": hotkeys[index], "name": name, "cost": cost})
		else:
			button.text = LocalizationService.translate_key("phase7.skill_ready", {"hotkey": hotkeys[index], "name": name, "cost": cost})
		button.tooltip_text = LocalizationService.translate_key(str(skill.get("description_key", "")))
		button.disabled = not bool(state.get("ready", false)) or upgrade_overlay.visible or level_up_overlay.visible or death_overlay.visible


func _build_battle_result() -> Dictionary:
	if not GameSessionService.has_active_session():
		return {"time": 0.0, "score": 0, "enemies": 0, "bosses": 0, "level": 1, "gold": 0, "army": 0, "skills": 0, "account_gold_reward": 0, "account_gold_total": PlayerProfileService.get_resource(&"account_gold")}
	var session := GameSessionService.active_session
	var stats := GameSessionService.get_run_stats()
	var enemies := int(stats.get("enemies_defeated", 0))
	var bosses := int(stats.get("bosses_defeated", 0))
	var skill_casts := int(stats.get("active_skills_cast", 0))
	var score := enemies * 10 + bosses * 250 + floori(session.elapsed_time * 2.0) + maxi(session.run_level - 1, 0) * 100
	return {
		"reason": "king_defeated",
		"time": snappedf(session.elapsed_time, 0.1),
		"score": score,
		"enemies": enemies,
		"bosses": bosses,
		"level": session.run_level,
		"gold": session.run_gold,
		"army": int(stats.get("max_army_size", 0)),
		"skills": skill_casts,
		"account_gold_reward": int(stats.get("account_gold_reward", 0)),
		"account_gold_total": PlayerProfileService.get_resource(&"account_gold"),
	}


func _settle_defeated_run() -> void:
	if not GameSessionService.has_active_session():
		return
	var result := _build_battle_result()
	GameSessionService.active_session.battle_score = int(result.get("score", 0))
	RewardGrantService.settle_active_run(result)


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
