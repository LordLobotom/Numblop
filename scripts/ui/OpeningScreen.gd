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

## The picture is drawn smaller than the button it sits in, so the checkmark can claim the corner
## without covering the flag -- the same split the settings screen uses at 48/38.
const FLAG_IMAGE_SIZE := Vector2(48.0, 48.0)

@onready var logo: TextureRect = %Logo
@onready var loading_label: Label = %LoadingLabel
@onready var language_panel: VBoxContainer = %LanguagePanel
@onready var language_prompt: Label = %LanguagePrompt
@onready var language_buttons: HFlowContainer = %LanguageButtons
@onready var selected_language_label: Label = %SelectedLanguageLabel
@onready var continue_button: Button = %ContinueButton
@onready var select_player: AudioStreamPlayer = %SelectPlayer

var _loading_pulse: Tween
var _intro_tween: Tween
var _intro_skipped := false
var _is_finishing := false
var _opening_locale_forced := false
var _flag_buttons: Dictionary = {}
var _flag_checks: Dictionary = {}
var _selected_locale := ""


func _ready() -> void:
    _force_opening_locale()
    _build_language_buttons()
    continue_button.pressed.connect(_on_continue_pressed)
    _refresh_selection()
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
        # Nothing is choosable until the panel is actually revealed.
        button.disabled = true
        button.pressed.connect(_on_language_selected.bind(locale))

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
        check.offset_left = -24.0
        check.offset_bottom = 26.0
        check.grow_horizontal = Control.GROW_DIRECTION_BEGIN
        check.mouse_filter = Control.MOUSE_FILTER_IGNORE
        check.line_width = 3.5
        check.scale_factor = 1.0
        check.outline_color = Color.WHITE
        check.outline_width = 7.0
        check.visible = false
        button.add_child(check)

        language_buttons.add_child(button)
        _flag_buttons[locale] = button
        _flag_checks[locale] = check


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        if _opening_locale_forced:
            return
        _refresh_text()


func _refresh_text() -> void:
    loading_label.text = tr("OPENING_LOADING")
    language_prompt.text = tr("OPENING_LANGUAGE_PROMPT")
    continue_button.text = tr("PRACTICE_CONTINUE")
    # Once a flag is tapped the whole screen is already in that language, so `tr()` on the name
    # key hands back the endonym the child recognises -- "Cestina", not "Czech".
    selected_language_label.text = (
        "" if _selected_locale.is_empty() else tr(LanguageCatalog.name_key(_selected_locale))
    )
    for locale in _flag_buttons:
        var button: TextureButton = _flag_buttons[locale]
        button.tooltip_text = tr(LanguageCatalog.name_key(String(locale)))


func _force_opening_locale() -> void:
    _opening_locale_forced = true
    TranslationServer.set_locale(OPENING_LOCALE)


func _play_opening() -> void:
    await get_tree().process_frame
    if _intro_skipped:
        return
    logo.pivot_offset = logo.size / 2.0

    _intro_tween = create_tween().set_parallel(true)
    _intro_tween.tween_property(logo, "modulate", Color.WHITE, 0.4)
    _intro_tween.tween_property(logo, "scale", Vector2(1.06, 1.06), 0.65) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await _intro_tween.finished
    if _intro_skipped:
        return

    _intro_tween = create_tween()
    _intro_tween.tween_property(logo, "scale", Vector2.ONE, 0.2) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    await _intro_tween.finished
    if _intro_skipped:
        return

    _start_loading_pulse()
    if SettingsManager.locale_preference == FIRST_LAUNCH_LOCALE:
        _show_language_choices()
        return

    await get_tree().create_timer(0.55).timeout
    if _intro_skipped:
        return
    _finish_opening()


## Lands straight on the finished chooser, with the logo settled and the panel up. The responsive
## captures need the same pixels every run, and the intro is a chain of tweens and a timer -- one
## slow frame and the shot catches a half-faded logo. Killing the tween also strands `_play_opening`
## on an `await` that will never resolve, which is what keeps the auto-finish from firing.
func reveal_language_choices_now() -> void:
    _intro_skipped = true
    if _intro_tween != null and _intro_tween.is_valid():
        _intro_tween.kill()
    logo.modulate = Color.WHITE
    logo.scale = Vector2.ONE
    _reveal_language_panel()
    language_panel.modulate = Color.WHITE


func _start_loading_pulse() -> void:
    _loading_pulse = create_tween().set_loops()
    _loading_pulse.tween_property(loading_label, "modulate:a", 0.42, 0.5) \
        .set_trans(Tween.TRANS_SINE)
    _loading_pulse.tween_property(loading_label, "modulate:a", 1.0, 0.5) \
        .set_trans(Tween.TRANS_SINE)


func _show_language_choices() -> void:
    _reveal_language_panel()
    var reveal_choices := create_tween()
    reveal_choices.tween_property(language_panel, "modulate", Color.WHITE, 0.3)


func _reveal_language_panel() -> void:
    if _loading_pulse != null:
        _loading_pulse.kill()
    loading_label.visible = false
    language_panel.visible = true
    _set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
    for locale in _flag_buttons:
        (_flag_buttons[locale] as TextureButton).disabled = disabled


## Tapping a flag only marks the choice -- nothing is saved and nothing closes until Continue.
## With ten languages on the very first screen a child sees, the first tap must be undoable.
func _on_language_selected(locale: String) -> void:
    if _is_finishing:
        return
    _selected_locale = locale
    select_player.play()
    # The confirmation reads in the language being confirmed, so the whole screen switches.
    TranslationServer.set_locale(locale)
    _refresh_selection()
    _refresh_text()


func _refresh_selection() -> void:
    # Before the first tap every flag is an equal offer, so nothing is dimmed yet.
    var has_choice := not _selected_locale.is_empty()
    for locale in _flag_buttons:
        var selected := String(locale) == _selected_locale
        (_flag_checks[locale] as CheckmarkIcon).visible = selected
        # The unselected flags stay legible but clearly step back from the chosen one.
        (_flag_buttons[locale] as TextureButton).modulate = (
            Color.WHITE if selected or not has_choice else Color(1, 1, 1, 0.58)
        )
    continue_button.disabled = not has_choice


func _on_continue_pressed() -> void:
    if _is_finishing or _selected_locale.is_empty():
        return
    var result := SettingsManager.set_locale_preference(_selected_locale)
    if result != OK:
        push_error("Could not save the selected opening language")
        return
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
