class_name SettingsScreen
extends Control

signal home_requested
signal map_requested
signal outfit_requested
signal trophy_requested
signal exit_requested

@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel
@onready var language_label: Label = %LanguageLabel
@onready var language_buttons: HFlowContainer = %LanguageButtons
@onready var music_label: Label = %MusicLabel
@onready var music_value: Label = %MusicValue
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_label: Label = %SfxLabel
@onready var sfx_value: Label = %SfxValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var mute_button: IconToggle = %MuteButton
@onready var haptics_button: IconToggle = %HapticsButton
@onready var sound_caption: Label = %SoundCaption
@onready var haptics_caption: Label = %HapticsCaption
@onready var cloud_item: VBoxContainer = %CloudItem
@onready var cloud_button: IconToggle = %CloudButton
@onready var cloud_caption: Label = %CloudCaption
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
var _flag_buttons: Dictionary = {}
var _flag_checks: Dictionary = {}

const COMPACT_DIALOG_WIDTH := 420.0
const DIALOG_SIDE_MARGIN := 20.0
const DIALOG_MAX_WIDTH := 360.0
const VERSION_SETTING := "application/config/version"
const VERSION_FALLBACK := "0.1.0"
## Ten flags wrap to 5 + 5 inside the settings card. 48 px is the touch minimum, and the flag
## itself is inset so the checkmark in the corner never covers it.
const FLAG_BUTTON_SIZE := Vector2(48.0, 48.0)
const FLAG_IMAGE_SIZE := Vector2(38.0, 38.0)


func _ready() -> void:
    _build_language_buttons()
    music_slider.value_changed.connect(_on_audio_value_changed)
    sfx_slider.value_changed.connect(_on_audio_value_changed)
    sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
    mute_button.toggled.connect(_on_sound_toggled)
    haptics_button.toggled.connect(_on_haptics_toggled)
    cloud_button.toggled.connect(_on_cloud_toggled)
    PlayGames.availability_changed.connect(_on_play_games_availability_changed)
    PlayGames.sign_in_state_changed.connect(_on_play_games_sign_in_changed)
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
    # The tile says "Sound", not "Mute": lit means audible. The stored flag is the mute, so
    # the two are inverses of each other and this is the one place that conversion happens.
    mute_button.button_pressed = not SettingsManager.audio_muted
    haptics_button.button_pressed = SettingsManager.haptics_enabled
    cloud_button.button_pressed = SettingsManager.play_games_enabled
    _syncing_controls = false
    mute_button.refresh()
    haptics_button.refresh()
    cloud_button.refresh()
    _refresh_volume_values()
    _refresh_language_selection()
    _refresh_toggle_accessibility()
    refresh_play_games()


func _refresh_text() -> void:
    title_label.text = tr("SETTINGS_TITLE")
    var app_version := str(ProjectSettings.get_setting(VERSION_SETTING, VERSION_FALLBACK))
    version_label.text = tr("SETTINGS_VERSION").format({"version": app_version})
    language_label.text = tr("SETTINGS_LANGUAGE")
    music_label.text = tr("SETTINGS_MUSIC")
    sfx_label.text = tr("SETTINGS_SFX")
    sound_caption.text = tr("SETTINGS_SOUND")
    haptics_caption.text = tr("SETTINGS_HAPTICS")
    cloud_caption.text = tr("SETTINGS_CLOUD")
    _refresh_toggle_accessibility()
    exit_button.text = tr("SETTINGS_EXIT")
    dialog_title.text = tr("SETTINGS_EXIT_TITLE")
    dialog_message.text = tr("SETTINGS_EXIT_CONFIRM")
    confirm_exit_button.text = tr("SETTINGS_EXIT_YES")
    cancel_exit_button.text = tr("SETTINGS_EXIT_CANCEL")
    hint_label.text = tr("SETTINGS_HINT")
    for locale in _flag_buttons:
        var button: TextureButton = _flag_buttons[locale]
        button.tooltip_text = tr(LanguageCatalog.name_key(String(locale)))
    _refresh_volume_values()


func _refresh_volume_values() -> void:
    music_value.text = tr("SETTINGS_VOLUME_VALUE").format({
        "value": roundi(music_slider.value),
    })
    sfx_value.text = tr("SETTINGS_VOLUME_VALUE").format({
        "value": roundi(sfx_slider.value),
    })


## The flag a given locale is chosen with, or null. Generated nodes carry no unique name, so
## this is how the tests reach one -- the same shape as `MapScreen.stage_button`.
func language_button(locale: String) -> TextureButton:
    return _flag_buttons.get(locale, null) as TextureButton


func _build_language_buttons() -> void:
    for language in LanguageCatalog.LANGUAGES:
        var locale := String(language["locale"])
        var button := TextureButton.new()
        button.name = "%sButton" % locale.to_upper()
        button.custom_minimum_size = FLAG_BUTTON_SIZE
        button.focus_mode = Control.FOCUS_ALL
        button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        button.ignore_texture_size = true
        button.stretch_mode = TextureButton.STRETCH_SCALE
        button.pressed.connect(_select_language.bind(locale))

        # The flag is a child rather than the button texture so the checkmark can overlap the
        # button's corner without sitting on top of the flag itself.
        var flag := TextureRect.new()
        flag.name = "Flag"
        flag.custom_minimum_size = FLAG_IMAGE_SIZE
        flag.set_anchors_preset(Control.PRESET_CENTER)
        flag.offset_left = -FLAG_IMAGE_SIZE.x / 2.0
        flag.offset_top = -FLAG_IMAGE_SIZE.y / 2.0
        flag.offset_right = FLAG_IMAGE_SIZE.x / 2.0
        flag.offset_bottom = FLAG_IMAGE_SIZE.y / 2.0
        flag.grow_horizontal = Control.GROW_DIRECTION_BOTH
        flag.grow_vertical = Control.GROW_DIRECTION_BOTH
        flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
        flag.texture = load(LanguageCatalog.flag_path(locale))
        flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        button.add_child(flag)

        var check := CheckmarkIcon.new()
        check.name = "Check"
        check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
        check.offset_left = -20.0
        check.offset_bottom = 22.0
        check.grow_horizontal = Control.GROW_DIRECTION_BEGIN
        check.mouse_filter = Control.MOUSE_FILTER_IGNORE
        check.line_width = 3.0
        check.scale_factor = 0.9
        check.outline_color = Color.WHITE
        check.outline_width = 6.0
        button.add_child(check)

        language_buttons.add_child(button)
        _flag_buttons[locale] = button
        _flag_checks[locale] = check


func _refresh_language_selection() -> void:
    var locale := SettingsManager.effective_locale()
    for entry in _flag_buttons:
        var selected := String(entry) == locale
        (_flag_checks[entry] as CheckmarkIcon).visible = selected
        # The unselected flags stay legible but clearly step back from the chosen one.
        (_flag_buttons[entry] as TextureButton).modulate = (
            Color.WHITE if selected else Color(1, 1, 1, 0.58)
        )


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


## `audible` is the tile's own state; the setting it drives is the mute, so it inverts.
func _on_sound_toggled(audible: bool) -> void:
    _refresh_toggle_accessibility()
    if _syncing_controls:
        return
    _preview_audio_preferences()
    _save_audio_preferences()
    # Turning it back on demonstrates what was turned on.
    if audible:
        preview_player.play()


## Shows or hides the cloud-save tile.
##
## Hidden unless a usable plugin is present, which means every Windows and Web player -- and every
## Android build without the plugin -- sees the original two tiles and nothing else. Offering a
## backup switch that cannot work would be a promise the game has no way to keep.
func refresh_play_games() -> void:
    cloud_item.visible = PlayGames.available()
    _refresh_toggle_accessibility()


func _on_play_games_availability_changed(_available: bool) -> void:
    if is_node_ready():
        refresh_play_games()


func _on_play_games_sign_in_changed(_signed_in: bool) -> void:
    if is_node_ready():
        _refresh_toggle_accessibility()


## The tile is lit by the *setting*, exactly like the sound and vibration tiles beside it.
##
## Tying it to whether sign-in actually succeeded was considered and rejected: a switch whose light
## ignores the tap is not a switch. Whether Google let the device in is reported through the
## accessible name instead, where it informs without turning the control into a status lamp.
func _on_cloud_toggled(enabled: bool) -> void:
    if _syncing_controls:
        return
    # The autoload owns both the stored preference and the session, so nothing here writes the
    # setting itself -- otherwise the two could disagree about whether the SDK may start.
    PlayGames.set_enabled(enabled)
    _refresh_toggle_accessibility()


func _on_haptics_toggled(enabled: bool) -> void:
    _refresh_toggle_accessibility()
    if _syncing_controls:
        return
    if SettingsManager.set_haptics_enabled(enabled) != OK:
        push_error("Could not save the vibration setting")
        return
    # Turning it on demonstrates what was turned on.
    if enabled:
        SettingsManager.play_haptic(SettingsManager.HAPTIC_TAP)


## The tiles carry no text of their own, so the state a sighted child reads from the colour
## has to be spoken somewhere too.
func _refresh_toggle_accessibility() -> void:
    if not is_node_ready():
        return
    mute_button.tooltip_text = tr(
        "SETTINGS_SOUND_ON_ACCESSIBLE" if mute_button.button_pressed
        else "SETTINGS_SOUND_OFF_ACCESSIBLE"
    )
    haptics_button.tooltip_text = tr(
        "SETTINGS_HAPTICS_OFF_ACCESSIBLE" if not haptics_button.button_pressed
        else "SETTINGS_HAPTICS_ON_ACCESSIBLE"
    )
    # Three states, not two: off, on and working, on but not signed in. The last one is the whole
    # reason this reads the session rather than only the switch -- a guardian who turned backup on
    # and never got signed in has nothing else on this screen that would tell them.
    var cloud_key := "SETTINGS_CLOUD_OFF_ACCESSIBLE"
    if cloud_button.button_pressed:
        cloud_key = (
            "SETTINGS_CLOUD_ON_ACCESSIBLE" if PlayGames.signed_in()
            else "SETTINGS_CLOUD_WAITING_ACCESSIBLE"
        )
    cloud_button.tooltip_text = tr(cloud_key)


func _preview_audio_preferences() -> void:
    SettingsManager.preview_audio_preferences(
        music_slider.value / 100.0,
        sfx_slider.value / 100.0,
        not mute_button.button_pressed
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
