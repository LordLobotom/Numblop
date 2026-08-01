extends Control

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var profile_label: Label = %ProfileLabel
@onready var progress_label: Label = %ProgressLabel
@onready var play_button: Button = %PlayButton
@onready var status_label: Label = %StatusLabel
@onready var privacy_label: Label = %PrivacyLabel
@onready var language_label: Label = %LanguageLabel
@onready var language_select: OptionButton = %LanguageSelect


func _ready() -> void:
    play_button.pressed.connect(_on_play_pressed)
    language_select.item_selected.connect(_on_language_selected)
    _populate_language_selector()
    _refresh_text(false)
    if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
        call_deferred("_center_desktop_window")


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _populate_language_selector()
        _refresh_text(false)


func _populate_language_selector() -> void:
    var selected_locale := SettingsManager.locale_preference
    language_select.clear()
    _add_locale_option(tr("LANGUAGE_SYSTEM"), SettingsManager.SYSTEM_LOCALE)
    _add_locale_option(tr("LANGUAGE_ENGLISH"), "en")
    _add_locale_option(tr("LANGUAGE_CZECH"), "cs")
    for index in language_select.item_count:
        if str(language_select.get_item_metadata(index)) == selected_locale:
            language_select.select(index)
            break


func _add_locale_option(label: String, locale: String) -> void:
    language_select.add_item(label)
    language_select.set_item_metadata(language_select.item_count - 1, locale)


func _refresh_text(session_created: bool) -> void:
    title_label.text = "Numblop"
    subtitle_label.text = tr("APP_TAGLINE")
    profile_label.text = tr("HOME_PROFILE")
    progress_label.text = tr("HOME_PROGRESS").format({
        "table": AppState.profile.current_table(),
        "mastered": AppState.profile.mastered_fact_count(),
    })
    play_button.text = tr("HOME_PLAY")
    language_label.text = tr("LANGUAGE_LABEL")
    privacy_label.text = tr("HOME_PRIVACY")
    status_label.text = (
        tr("HOME_STATUS_SESSION").format({"count": AppState.active_session.size()})
        if session_created
        else tr("HOME_STATUS_READY")
    )


func _on_play_pressed() -> void:
    AppState.begin_session()
    _refresh_text(true)


func _on_language_selected(index: int) -> void:
    var locale := str(language_select.get_item_metadata(index))
    var result := SettingsManager.set_locale_preference(locale)
    if result != OK:
        push_error("Could not save the selected language")
    _refresh_text(not AppState.active_session.is_empty())


func _center_desktop_window() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    var window_size := DisplayServer.window_get_size()
    var centered := usable_rect.position + (usable_rect.size - window_size) / 2
    DisplayServer.window_set_position(centered)
