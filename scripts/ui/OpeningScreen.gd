class_name OpeningScreen
extends Control

signal opening_finished

const FIRST_LAUNCH_LOCALE := "system"
const OPENING_LOCALE := "en"

## Ten flags will not fit across 390 px in one row, so they wrap to 5 + 5. The narrowest column
## the safe area leaves is 358 px, and five of these plus four gaps come to 340 -- comfortably
## inside it, while still well past the 48 px touch minimum. Growing either number past 65 px
## of pitch drops the row to four flags and the layout breaks into 4 + 4 + 2.
const FLAG_SIZE := Vector2(60.0, 60.0)

@onready var logo: TextureRect = %Logo
@onready var loading_label: Label = %LoadingLabel
@onready var language_panel: VBoxContainer = %LanguagePanel
@onready var language_prompt: Label = %LanguagePrompt
@onready var language_buttons: HFlowContainer = %LanguageButtons
@onready var select_player: AudioStreamPlayer = %SelectPlayer

var _loading_pulse: Tween
var _is_finishing := false
var _opening_locale_forced := false
var _flag_buttons: Dictionary = {}


func _ready() -> void:
    _force_opening_locale()
    _build_language_buttons()
    _refresh_text()
    _play_opening()


## The flag a given locale is chosen with, or null. Generated nodes carry no unique name, so
## this is how the tutorial and the tests reach one -- the same shape as `MapScreen.stage_button`.
func language_button(locale: String) -> TextureButton:
    return _flag_buttons.get(locale, null) as TextureButton


func _build_language_buttons() -> void:
    for language in LanguageCatalog.LANGUAGES:
        var locale := String(language["locale"])
        var button := TextureButton.new()
        button.name = "%sButton" % locale.to_upper()
        button.custom_minimum_size = FLAG_SIZE
        button.focus_mode = Control.FOCUS_ALL
        button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        button.ignore_texture_size = true
        button.stretch_mode = TextureButton.STRETCH_SCALE
        button.texture_normal = load(LanguageCatalog.flag_path(locale))
        # Nothing is choosable until the panel is actually revealed.
        button.disabled = true
        button.pressed.connect(_on_language_selected.bind(locale))
        language_buttons.add_child(button)
        _flag_buttons[locale] = button


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        if _opening_locale_forced:
            return
        _refresh_text()


func _refresh_text() -> void:
    loading_label.text = tr("OPENING_LOADING")
    language_prompt.text = tr("OPENING_LANGUAGE_PROMPT")
    for locale in _flag_buttons:
        var button: TextureButton = _flag_buttons[locale]
        button.tooltip_text = tr(LanguageCatalog.name_key(String(locale)))


func _force_opening_locale() -> void:
    _opening_locale_forced = true
    TranslationServer.set_locale(OPENING_LOCALE)


func _play_opening() -> void:
    await get_tree().process_frame
    logo.pivot_offset = logo.size / 2.0

    var reveal := create_tween().set_parallel(true)
    reveal.tween_property(logo, "modulate", Color.WHITE, 0.4)
    reveal.tween_property(logo, "scale", Vector2(1.06, 1.06), 0.65) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await reveal.finished

    var settle := create_tween()
    settle.tween_property(logo, "scale", Vector2.ONE, 0.2) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    await settle.finished

    _start_loading_pulse()
    if SettingsManager.locale_preference == FIRST_LAUNCH_LOCALE:
        _show_language_choices()
        return

    await get_tree().create_timer(0.55).timeout
    _finish_opening()


func _start_loading_pulse() -> void:
    _loading_pulse = create_tween().set_loops()
    _loading_pulse.tween_property(loading_label, "modulate:a", 0.42, 0.5) \
        .set_trans(Tween.TRANS_SINE)
    _loading_pulse.tween_property(loading_label, "modulate:a", 1.0, 0.5) \
        .set_trans(Tween.TRANS_SINE)


func _show_language_choices() -> void:
    if _loading_pulse != null:
        _loading_pulse.kill()
    loading_label.visible = false
    language_panel.visible = true
    _set_buttons_disabled(false)
    var reveal_choices := create_tween()
    reveal_choices.tween_property(language_panel, "modulate", Color.WHITE, 0.3)


func _set_buttons_disabled(disabled: bool) -> void:
    for locale in _flag_buttons:
        (_flag_buttons[locale] as TextureButton).disabled = disabled


func _on_language_selected(locale: String) -> void:
    if _is_finishing:
        return
    _set_buttons_disabled(true)
    select_player.play()
    var result := SettingsManager.set_locale_preference(locale)
    if result != OK:
        push_error("Could not save the selected opening language")
        _set_buttons_disabled(false)
        return
    TranslationServer.set_locale(OPENING_LOCALE)
    _finish_opening()


func _finish_opening() -> void:
    if _is_finishing:
        return
    _is_finishing = true
    if _loading_pulse != null:
        _loading_pulse.kill()
    var fade := create_tween()
    fade.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    await fade.finished
    _opening_locale_forced = false
    SettingsManager.apply_locale()
    opening_finished.emit()
    queue_free()
