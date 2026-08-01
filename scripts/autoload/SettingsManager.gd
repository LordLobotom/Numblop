extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SYSTEM_LOCALE := "system"
const SUPPORTED_LOCALES: Array[String] = ["en", "cs"]
const DEFAULT_MUSIC_VOLUME := 0.75
const DEFAULT_SFX_VOLUME := 0.9

var locale_preference := SYSTEM_LOCALE
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var audio_muted := false


func _ready() -> void:
    load_settings()
    apply_locale()
    apply_audio()


func load_settings(path: String = SETTINGS_PATH) -> void:
    locale_preference = SYSTEM_LOCALE
    music_volume = DEFAULT_MUSIC_VOLUME
    sfx_volume = DEFAULT_SFX_VOLUME
    audio_muted = false
    var config := ConfigFile.new()
    if config.load(path) == OK:
        var saved := str(config.get_value("language", "locale", SYSTEM_LOCALE))
        if saved == SYSTEM_LOCALE or SUPPORTED_LOCALES.has(saved):
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


func set_locale_preference(locale: String, path: String = SETTINGS_PATH) -> Error:
    if locale != SYSTEM_LOCALE and not SUPPORTED_LOCALES.has(locale):
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


func effective_locale() -> String:
    if locale_preference != SYSTEM_LOCALE:
        return locale_preference
    var system_locale := OS.get_locale_language()
    return "cs" if system_locale == "cs" else "en"


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
    return config.save(path)
