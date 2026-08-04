class_name SettingsScreen
extends Control

signal home_requested
signal map_requested
signal outfit_requested
signal trophy_requested
signal exit_requested

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel
@onready var language_label: Label = %LanguageLabel
@onready var english_button: TextureButton = %EnglishButton
@onready var czech_button: TextureButton = %CzechButton
@onready var english_label: Label = %EnglishLabel
@onready var czech_label: Label = %CzechLabel
@onready var english_check: CheckmarkIcon = %EnglishCheck
@onready var czech_check: CheckmarkIcon = %CzechCheck
@onready var music_label: Label = %MusicLabel
@onready var music_value: Label = %MusicValue
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_label: Label = %SfxLabel
@onready var sfx_value: Label = %SfxValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var mute_button: CheckButton = %MuteButton
@onready var hint_label: Label = %HintLabel
@onready var exit_button: Button = %ExitButton
@onready var exit_dialog: Control = %ExitDialog
@onready var exit_scrim: ColorRect = %ExitScrim
@onready var dialog_panel: PanelContainer = %DialogPanel
@onready var dialog_title: Label = %DialogTitle
@onready var dialog_message: Label = %DialogMessage
@onready var dialog_buttons: BoxContainer = %DialogButtons
@onready var cancel_exit_button: Button = %CancelExitButton
@onready var confirm_exit_button: Button = %ConfirmExitButton
@onready var preview_player: AudioStreamPlayer = %PreviewPlayer
@onready var save_timer: Timer = %SaveTimer
@onready var navigation: NavBar = $SafeArea/Content/Navigation

var _syncing_controls := false

const COMPACT_DIALOG_WIDTH := 420.0
const DIALOG_SIDE_MARGIN := 20.0
const DIALOG_MAX_WIDTH := 360.0
const VERSION_SETTING := "application/config/version"
const VERSION_FALLBACK := "0.1.0"


func _ready() -> void:
    english_button.pressed.connect(_select_language.bind("en"))
    czech_button.pressed.connect(_select_language.bind("cs"))
    music_slider.value_changed.connect(_on_audio_value_changed)
    sfx_slider.value_changed.connect(_on_audio_value_changed)
    sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
    mute_button.toggled.connect(_on_mute_toggled)
    exit_button.pressed.connect(show_exit_confirmation)
    cancel_exit_button.pressed.connect(hide_exit_confirmation)
    confirm_exit_button.pressed.connect(_confirm_exit)
    exit_scrim.gui_input.connect(_on_exit_scrim_input)
    resized.connect(_update_exit_dialog_layout)
    navigation.outfit_requested.connect(_request_future_feature.bind(outfit_requested))
    navigation.map_requested.connect(_request_map)
    navigation.home_requested.connect(_request_home)
    navigation.trophy_requested.connect(_request_future_feature.bind(trophy_requested))
    save_timer.timeout.connect(_save_audio_preferences)
    _sync_controls_from_settings()
    _refresh_text()
    _update_exit_dialog_layout()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _refresh_language_selection()


func show_future_feature() -> void:
    hint_label.text = tr("HOME_FEATURE_LATER")


func refresh_from_settings() -> void:
    _sync_controls_from_settings()
    _refresh_text()


func _sync_controls_from_settings() -> void:
    _syncing_controls = true
    music_slider.value = SettingsManager.music_volume * 100.0
    sfx_slider.value = SettingsManager.sfx_volume * 100.0
    mute_button.button_pressed = SettingsManager.audio_muted
    _syncing_controls = false
    _refresh_volume_values()
    _refresh_language_selection()


func _refresh_text() -> void:
    title_label.text = tr("SETTINGS_TITLE")
    subtitle_label.text = tr("SETTINGS_SUBTITLE")
    var app_version := str(ProjectSettings.get_setting(VERSION_SETTING, VERSION_FALLBACK))
    version_label.text = tr("SETTINGS_VERSION").format({"version": app_version})
    language_label.text = tr("SETTINGS_LANGUAGE")
    english_label.text = tr("LANGUAGE_ENGLISH")
    czech_label.text = tr("LANGUAGE_CZECH")
    music_label.text = tr("SETTINGS_MUSIC")
    sfx_label.text = tr("SETTINGS_SFX")
    mute_button.text = tr("SETTINGS_MUTE_ALL")
    exit_button.text = tr("SETTINGS_EXIT")
    dialog_title.text = tr("SETTINGS_EXIT_TITLE")
    dialog_message.text = tr("SETTINGS_EXIT_CONFIRM")
    confirm_exit_button.text = tr("SETTINGS_EXIT_YES")
    cancel_exit_button.text = tr("SETTINGS_EXIT_CANCEL")
    hint_label.text = tr("SETTINGS_HINT")
    english_button.tooltip_text = tr("LANGUAGE_ENGLISH")
    czech_button.tooltip_text = tr("LANGUAGE_CZECH")
    _refresh_volume_values()


func _refresh_volume_values() -> void:
    music_value.text = tr("SETTINGS_VOLUME_VALUE").format({
        "value": roundi(music_slider.value),
    })
    sfx_value.text = tr("SETTINGS_VOLUME_VALUE").format({
        "value": roundi(sfx_slider.value),
    })


func _refresh_language_selection() -> void:
    var locale := SettingsManager.effective_locale()
    english_check.visible = locale == "en"
    czech_check.visible = locale == "cs"
    english_button.modulate = Color.WHITE if locale == "en" else Color(1, 1, 1, 0.58)
    czech_button.modulate = Color.WHITE if locale == "cs" else Color(1, 1, 1, 0.58)


func _select_language(locale: String) -> void:
    var result := SettingsManager.set_locale_preference(locale)
    if result != OK:
        push_error("Could not save the selected settings language")
        return
    _refresh_language_selection()
    preview_player.play()


func _on_audio_value_changed(_value: float) -> void:
    if _syncing_controls:
        return
    _preview_audio_preferences()
    _refresh_volume_values()
    save_timer.start()


func _on_sfx_drag_ended(value_changed: bool) -> void:
    if value_changed and not SettingsManager.audio_muted:
        preview_player.play()


func _on_mute_toggled(muted: bool) -> void:
    if _syncing_controls:
        return
    _preview_audio_preferences()
    _save_audio_preferences()
    if not muted:
        preview_player.play()


func _preview_audio_preferences() -> void:
    SettingsManager.preview_audio_preferences(
        music_slider.value / 100.0,
        sfx_slider.value / 100.0,
        mute_button.button_pressed
    )


func _save_audio_preferences() -> void:
    save_timer.stop()
    var result := SettingsManager.save_audio_preferences()
    if result != OK:
        push_error("Could not save audio settings")


func _flush_audio_preferences() -> void:
    _preview_audio_preferences()
    _save_audio_preferences()


func _request_home() -> void:
    _flush_audio_preferences()
    home_requested.emit()


func _request_map() -> void:
    _flush_audio_preferences()
    map_requested.emit()


func _request_future_feature(feature_signal: Signal) -> void:
    _flush_audio_preferences()
    feature_signal.emit()


func show_exit_confirmation() -> void:
    _flush_audio_preferences()
    _update_exit_dialog_layout()
    exit_dialog.visible = true
    cancel_exit_button.grab_focus()


func hide_exit_confirmation() -> void:
    exit_dialog.visible = false
    exit_button.grab_focus()


func close_exit_confirmation_if_open() -> bool:
    if not exit_dialog.visible:
        return false
    hide_exit_confirmation()
    return true


func _update_exit_dialog_layout() -> void:
    var available_width := maxf(280.0, size.x - DIALOG_SIDE_MARGIN * 2.0)
    dialog_panel.custom_minimum_size.x = minf(DIALOG_MAX_WIDTH, available_width)
    dialog_buttons.vertical = size.x < COMPACT_DIALOG_WIDTH


func _on_exit_scrim_input(event: InputEvent) -> void:
    if (
        event is InputEventMouseButton
        and event.button_index == MOUSE_BUTTON_LEFT
        and event.pressed
    ):
        hide_exit_confirmation()
        exit_scrim.accept_event()


func _unhandled_input(event: InputEvent) -> void:
    if exit_dialog.visible and event.is_action_pressed("ui_cancel"):
        hide_exit_confirmation()
        get_viewport().set_input_as_handled()


func _confirm_exit() -> void:
    _flush_audio_preferences()
    exit_dialog.visible = false
    exit_requested.emit()
