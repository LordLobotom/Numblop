extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SYSTEM_LOCALE := "system"
const DEFAULT_MUSIC_VOLUME := 0.75
const DEFAULT_SFX_VOLUME := 0.9
const DEFAULT_PRACTICE_QUESTION_COUNT := 10

## The only three moments that buzz, and how hard.
##
## Amplitude matters more than length: a short pulse at the device default is a tick nobody
## notices. Nothing runs below 20 ms because several Android vendors swallow shorter pulses.
## Amplitude needs API 26, so Android 24 and 25 fall back to the default strength on their own.
##
## These lengths are doubled from the first pass, which read as a faint click on real hardware
## rather than as feedback. Amplitude is unchanged: it was already at or near full.
const HAPTIC_TAP := "tap"
const HAPTIC_CELEBRATION := "celebration"
const HAPTIC_MILESTONE := "milestone"
const HAPTIC_PATTERNS := {
    HAPTIC_TAP: {"duration_ms": 50, "amplitude": 0.5},
    HAPTIC_CELEBRATION: {"duration_ms": 180, "amplitude": 1.0},
    HAPTIC_MILESTONE: {"duration_ms": 160, "amplitude": 0.8},
}

var locale_preference := SYSTEM_LOCALE
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var audio_muted := false
var haptics_enabled := true
var practice_question_count := DEFAULT_PRACTICE_QUESTION_COUNT

## Whether this device backs progress up through Play Games Services.
##
## On by default: losing a phone and losing a year of practice with it is the problem worth solving,
## and Google -- through the device account and Family Link for supervised children -- already
## governs whether a child may sign in at all. Numblop adds no gate of its own in front of that.
##
## It lives here in device settings rather than in the progress file because it records a choice
## about this device, so resetting a child's profile must not silently change it.
var play_games_enabled := true


func _ready() -> void:
    load_settings()
    apply_locale()
    apply_audio()


func load_settings(path: String = SETTINGS_PATH) -> void:
    locale_preference = SYSTEM_LOCALE
    music_volume = DEFAULT_MUSIC_VOLUME
    sfx_volume = DEFAULT_SFX_VOLUME
    audio_muted = false
    haptics_enabled = true
    practice_question_count = DEFAULT_PRACTICE_QUESTION_COUNT
    play_games_enabled = true
    var config := ConfigFile.new()
    if config.load(path) == OK:
        var saved := str(config.get_value("language", "locale", SYSTEM_LOCALE))
        if saved == SYSTEM_LOCALE or LanguageCatalog.has_locale(saved):
            locale_preference = saved
        music_volume = clampf(
            float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)),
            0.0,
            1.0
        )
        sfx_volume = clampf(
            float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)),
            0.0,
            1.0
        )
        audio_muted = bool(config.get_value("audio", "muted", false))
        haptics_enabled = bool(config.get_value("haptics", "enabled", true))
        var saved_practice_count: Variant = config.get_value(
            "practice",
            "question_count",
            DEFAULT_PRACTICE_QUESTION_COUNT
        )
        if saved_practice_count is int or saved_practice_count is float:
            var candidate := int(saved_practice_count)
            if LearningRules.is_free_practice_length(candidate):
                practice_question_count = candidate
        play_games_enabled = bool(config.get_value("play_games", "enabled", true))


func set_locale_preference(locale: String, path: String = SETTINGS_PATH) -> Error:
    if locale != SYSTEM_LOCALE and not LanguageCatalog.has_locale(locale):
        return ERR_INVALID_PARAMETER
    locale_preference = locale
    apply_locale()
    return _save_settings(path)


func preview_audio_preferences(
    requested_music_volume: float,
    requested_sfx_volume: float,
    requested_muted: bool
) -> void:
    music_volume = clampf(requested_music_volume, 0.0, 1.0)
    sfx_volume = clampf(requested_sfx_volume, 0.0, 1.0)
    audio_muted = requested_muted
    apply_audio()


func save_audio_preferences(path: String = SETTINGS_PATH) -> Error:
    return _save_settings(path)


func set_audio_preferences(
    requested_music_volume: float,
    requested_sfx_volume: float,
    requested_muted: bool,
    path: String = SETTINGS_PATH
) -> Error:
    preview_audio_preferences(
        requested_music_volume,
        requested_sfx_volume,
        requested_muted
    )
    return _save_settings(path)


func audio_preferences() -> Dictionary:
    return {
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "muted": audio_muted,
    }


func set_haptics_enabled(enabled: bool, path: String = SETTINGS_PATH) -> Error:
    haptics_enabled = enabled
    return _save_settings(path)


func set_practice_question_count(
    question_count: int,
    path: String = SETTINGS_PATH
) -> Error:
    if not LearningRules.is_free_practice_length(question_count):
        return ERR_INVALID_PARAMETER
    practice_question_count = question_count
    return _save_settings(path)


func set_play_games_enabled(enabled: bool, path: String = SETTINGS_PATH) -> Error:
    play_games_enabled = enabled
    return _save_settings(path)


## Buzzes one of the named patterns, unless the child turned vibration off.
##
## `Input.vibrate_handheld` is a no-op away from a handheld device, so Windows and Web need no
## guard of their own.
func play_haptic(pattern_name: String) -> void:
    if not haptics_enabled:
        return
    var pattern: Dictionary = HAPTIC_PATTERNS.get(pattern_name, {})
    if pattern.is_empty():
        push_error("Unknown haptic pattern: %s" % pattern_name)
        return
    Input.vibrate_handheld(int(pattern["duration_ms"]), float(pattern["amplitude"]))


## The locale actually in use: an explicit choice, or the device language when it is one we ship.
##
## The full device locale keeps Brazilian and European Portuguese distinct. The catalog resolver
## folds region tags for language-only translations and handles legacy Norwegian aliases.
func effective_locale() -> String:
    if locale_preference != SYSTEM_LOCALE:
        return locale_preference
    return LanguageCatalog.resolve_device_locale(OS.get_locale())


func apply_locale() -> void:
    var locale := effective_locale()
    TranslationServer.set_locale(locale)
    EventBus.locale_changed.emit(locale)


func apply_audio() -> void:
    _apply_bus_volume("Music", music_volume)
    _apply_bus_volume("SFX", sfx_volume)
    EventBus.audio_settings_changed.emit(music_volume, sfx_volume, audio_muted)


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        return
    AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))
    AudioServer.set_bus_mute(bus_index, audio_muted or linear_volume <= 0.0)


func _save_settings(path: String) -> Error:
    var config := ConfigFile.new()
    config.set_value("language", "locale", locale_preference)
    config.set_value("audio", "music_volume", music_volume)
    config.set_value("audio", "sfx_volume", sfx_volume)
    config.set_value("audio", "muted", audio_muted)
    config.set_value("haptics", "enabled", haptics_enabled)
    config.set_value("practice", "question_count", practice_question_count)
    config.set_value("play_games", "enabled", play_games_enabled)
    return config.save(path)
