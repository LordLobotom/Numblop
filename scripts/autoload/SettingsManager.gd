extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SYSTEM_LOCALE := "system"
const SUPPORTED_LOCALES: Array[String] = ["en", "cs"]

var locale_preference := SYSTEM_LOCALE


func _ready() -> void:
    load_settings()
    apply_locale()


func load_settings(path: String = SETTINGS_PATH) -> void:
    var config := ConfigFile.new()
    if config.load(path) == OK:
        var saved := str(config.get_value("language", "locale", SYSTEM_LOCALE))
        if saved == SYSTEM_LOCALE or SUPPORTED_LOCALES.has(saved):
            locale_preference = saved


func set_locale_preference(locale: String, path: String = SETTINGS_PATH) -> Error:
    if locale != SYSTEM_LOCALE and not SUPPORTED_LOCALES.has(locale):
        return ERR_INVALID_PARAMETER
    locale_preference = locale
    apply_locale()
    var config := ConfigFile.new()
    config.set_value("language", "locale", locale_preference)
    return config.save(path)


func effective_locale() -> String:
    if locale_preference != SYSTEM_LOCALE:
        return locale_preference
    var system_locale := OS.get_locale_language()
    return "cs" if system_locale == "cs" else "en"


func apply_locale() -> void:
    var locale := effective_locale()
    TranslationServer.set_locale(locale)
    EventBus.locale_changed.emit(locale)
