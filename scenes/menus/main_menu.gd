extends Control

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var challenges_button: Button = %ChallengesButton
@onready var kings_button: Button = %KingsButton
@onready var army_button: Button = %ArmyButton
@onready var rankings_button: Button = %RankingsButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var language_picker: OptionButton = %LanguagePicker
@onready var platform_label: Label = %PlatformLabel
@onready var roster_label: Label = %RosterLabel
@onready var status_label: Label = %StatusLabel
@onready var account_gold_label: Label = %AccountGoldLabel
@onready var treasury_overlay: Control = %TreasuryOverlay
@onready var treasury_title_label: Label = %TreasuryTitleLabel
@onready var treasury_balance_label: Label = %TreasuryBalanceLabel
@onready var treasury_hint_label: Label = %TreasuryHintLabel
@onready var treasury_grid: GridContainer = %TreasuryGrid
@onready var treasury_button_template: Button = %TreasuryButtonTemplate
@onready var treasury_stats_label: Label = %TreasuryStatsLabel
@onready var treasury_close_button: Button = %TreasuryCloseButton

var _treasury_buttons: Dictionary = {}


func _ready() -> void:
	LocalizationService.locale_changed.connect(_on_locale_changed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	kings_button.pressed.connect(_open_treasury)
	treasury_close_button.pressed.connect(_close_treasury)
	exit_button.pressed.connect(_on_exit_button_pressed)
	AccountProgressionService.upgrade_purchased.connect(_on_account_upgrade_purchased)
	_build_treasury_controls()
	_setup_language_picker()
	_refresh_text()


func _setup_language_picker() -> void:
	language_picker.clear()
	language_picker.add_item("English (US)")
	language_picker.set_item_metadata(0, "en-US")
	language_picker.add_item("Tiếng Việt")
	language_picker.set_item_metadata(1, "vi-VN")
	for index in language_picker.item_count:
		if str(language_picker.get_item_metadata(index)) == LocalizationService.current_locale:
			language_picker.select(index)
			break
	if not language_picker.item_selected.is_connected(_on_language_selected):
		language_picker.item_selected.connect(_on_language_selected)


func _refresh_text() -> void:
	title_label.text = LocalizationService.translate_key("menu.title")
	subtitle_label.text = LocalizationService.translate_key("menu.subtitle")
	account_gold_label.text = LocalizationService.translate_key("phase8.account_gold", {"amount": AccountProgressionService.get_account_gold()})
	continue_button.text = LocalizationService.translate_key("menu.continue")
	start_button.text = LocalizationService.translate_key("menu.start_battle")
	challenges_button.text = LocalizationService.translate_key("menu.challenges")
	kings_button.text = LocalizationService.translate_key("phase8.open_treasury")
	army_button.text = LocalizationService.translate_key("menu.army")
	rankings_button.text = LocalizationService.translate_key("menu.rankings")
	settings_button.text = LocalizationService.translate_key("menu.settings")
	exit_button.text = LocalizationService.translate_key("menu.exit_game")
	exit_button.visible = PlatformService.supports_application_quit()
	continue_button.visible = GameSessionService.has_active_session()
	platform_label.text = LocalizationService.translate_key(
		"phase0.platform",
		{"platform": PlatformService.get_platform_name()}
	)
	roster_label.text = LocalizationService.translate_key(
		"phase0.roster",
		{"count": ContentDatabase.factions.size()}
	)
	status_label.text = LocalizationService.translate_key("phase2.menu_status")
	_refresh_treasury_text()


func _on_language_selected(index: int) -> void:
	LocalizationService.set_locale(str(language_picker.get_item_metadata(index)))


func _on_locale_changed(_locale: String) -> void:
	_refresh_text()


func _on_start_button_pressed() -> void:
	var session_seed := int(Time.get_ticks_usec() & 0x7fffffff)
	GameSessionService.start_session(&"tran_hung_dao", &"dai_viet", session_seed)
	_open_movement_drill()


func _on_continue_button_pressed() -> void:
	if not GameSessionService.has_active_session():
		return
	_open_movement_drill()


func _on_exit_button_pressed() -> void:
	PlatformService.request_application_quit()


func _build_treasury_controls() -> void:
	for child in treasury_grid.get_children():
		if child != treasury_button_template:
			child.queue_free()
	treasury_button_template.visible = false
	_treasury_buttons.clear()
	for upgrade_id_value in ContentDatabase.get_account_upgrade_ids():
		var upgrade_id := str(upgrade_id_value)
		var button := treasury_button_template.duplicate() as Button
		button.name = "Treasury_%s" % upgrade_id
		button.visible = true
		button.set_meta("upgrade_id", upgrade_id)
		button.pressed.connect(_purchase_account_upgrade.bind(StringName(upgrade_id)))
		treasury_grid.add_child(button)
		_treasury_buttons[upgrade_id] = button


func _refresh_treasury_text() -> void:
	if not is_instance_valid(treasury_title_label):
		return
	var account_gold := AccountProgressionService.get_account_gold()
	treasury_title_label.text = LocalizationService.translate_key("phase8.treasury_title")
	treasury_balance_label.text = LocalizationService.translate_key("phase8.account_gold", {"amount": account_gold})
	treasury_hint_label.text = LocalizationService.translate_key("phase8.treasury_hint")
	treasury_close_button.text = LocalizationService.translate_key("phase8.close_treasury")
	var profile := PlayerProfileService.get_profile_snapshot()
	var statistics: Dictionary = profile.get("statistics", {})
	treasury_stats_label.text = LocalizationService.translate_key("phase8.career_stats", {
		"runs": int(statistics.get("completed_runs", 0)),
		"kills": int(statistics.get("total_kills", 0)),
		"bosses": int(statistics.get("boss_kills", 0)),
		"score": int(statistics.get("highest_battle_score", 0)),
	})
	for upgrade_id_value in _treasury_buttons.keys():
		var upgrade_id := str(upgrade_id_value)
		var button := _treasury_buttons[upgrade_id] as Button
		if not is_instance_valid(button):
			continue
		var config := ContentDatabase.get_account_upgrade(StringName(upgrade_id))
		var level := AccountProgressionService.get_upgrade_level(StringName(upgrade_id))
		var max_level := int(config.get("max_level", 0))
		var upgrade_name := LocalizationService.translate_key(str(config.get("name_key", "")))
		var description := LocalizationService.translate_key(str(config.get("description_key", "")))
		if level >= max_level:
			button.text = LocalizationService.translate_key("phase8.upgrade_max", {"name": upgrade_name, "level": level, "max": max_level, "description": description})
		else:
			button.text = LocalizationService.translate_key("phase8.upgrade_card", {
				"name": upgrade_name,
				"level": level,
				"next": level + 1,
				"max": max_level,
				"cost": AccountProgressionService.get_upgrade_cost(StringName(upgrade_id)),
				"description": description,
			})
		button.disabled = not AccountProgressionService.can_purchase(StringName(upgrade_id))


func _open_treasury() -> void:
	_refresh_treasury_text()
	treasury_overlay.visible = true


func _close_treasury() -> void:
	treasury_overlay.visible = false


func _purchase_account_upgrade(upgrade_id: StringName) -> void:
	AccountProgressionService.try_purchase(upgrade_id)
	_refresh_text()


func _on_account_upgrade_purchased(_upgrade_id: StringName, _level: int) -> void:
	_refresh_text()


func _open_movement_drill() -> void:
	var error := SceneService.change_scene_to_file("res://scenes/gameplay/movement_arena.tscn")
	if error != OK:
		status_label.text = LocalizationService.translate_key("bootstrap.failed")
