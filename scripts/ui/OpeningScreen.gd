class_name OpeningScreen
extends Control

signal opening_finished

const FIRST_LAUNCH_LOCALE := "system"
const OPENING_LOCALE := "en"

@onready var logo: TextureRect = %Logo
@onready var loading_label: Label = %LoadingLabel
@onready var language_panel: VBoxContainer = %LanguagePanel
@onready var language_prompt: Label = %LanguagePrompt
@onready var english_button: TextureButton = %EnglishButton
@onready var czech_button: TextureButton = %CzechButton
@onready var select_player: AudioStreamPlayer = %SelectPlayer

var _loading_pulse: Tween
var _is_finishing := false
var _opening_locale_forced := false


func _ready() -> void:
    _force_opening_locale()
    english_button.pressed.connect(_on_language_selected.bind("en"))
    czech_button.pressed.connect(_on_language_selected.bind("cs"))
    _refresh_text()
    _play_opening()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        if _opening_locale_forced:
            return
        _refresh_text()


func _refresh_text() -> void:
    loading_label.text = tr("OPENING_LOADING")
    language_prompt.text = tr("OPENING_LANGUAGE_PROMPT")
    english_button.tooltip_text = tr("LANGUAGE_ENGLISH")
    czech_button.tooltip_text = tr("LANGUAGE_CZECH")


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
    english_button.disabled = false
    czech_button.disabled = false
    var reveal_choices := create_tween()
    reveal_choices.tween_property(language_panel, "modulate", Color.WHITE, 0.3)


func _on_language_selected(locale: String) -> void:
    if _is_finishing:
        return
    english_button.disabled = true
    czech_button.disabled = true
    select_player.play()
    var result := SettingsManager.set_locale_preference(locale)
    if result != OK:
        push_error("Could not save the selected opening language")
        english_button.disabled = false
        czech_button.disabled = false
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
