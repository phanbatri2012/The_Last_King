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
@onready var language_picker: OptionButton = %LanguagePicker
@onready var platform_label: Label = %PlatformLabel
@onready var roster_label: Label = %RosterLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	LocalizationService.locale_changed.connect(_on_locale_changed)
	start_button.pressed.connect(_on_phase_one_button_pressed)
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
	continue_button.text = LocalizationService.translate_key("menu.continue")
	start_button.text = LocalizationService.translate_key("menu.start_battle")
	challenges_button.text = LocalizationService.translate_key("menu.challenges")
	kings_button.text = LocalizationService.translate_key("menu.kings")
	army_button.text = LocalizationService.translate_key("menu.army")
	rankings_button.text = LocalizationService.translate_key("menu.rankings")
	settings_button.text = LocalizationService.translate_key("menu.settings")
	continue_button.visible = GameSessionService.has_active_session()
	platform_label.text = LocalizationService.translate_key(
		"phase0.platform",
		{"platform": PlatformService.get_platform_name()}
	)
	roster_label.text = LocalizationService.translate_key(
		"phase0.roster",
		{"count": ContentDatabase.factions.size()}
	)
	status_label.text = LocalizationService.translate_key("phase0.status")


func _on_language_selected(index: int) -> void:
	LocalizationService.set_locale(str(language_picker.get_item_metadata(index)))


func _on_locale_changed(_locale: String) -> void:
	_refresh_text()


func _on_phase_one_button_pressed() -> void:
	status_label.text = LocalizationService.translate_key("phase0.phase1_not_implemented")
