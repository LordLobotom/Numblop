class_name LanguageCatalog
extends RefCounted

## The languages Numblop ships in, in the order their flags are shown.
##
## One list, used three ways: `SettingsManager` validates a saved preference against it, and both
## the opening screen and the settings screen build their flag buttons from it. Adding a language
## is a row here plus a column in `localization/strings.csv` -- no scene edits.
##
## `locale` is the code the `TranslationServer` is set to and the column name in the catalog CSV.
## Norwegian ships as Bokmal (`nb`), which is what Android devices and Play Console report.

const FLAG_DIRECTORY := "res://ui/buttons/"

## English first because it is the opening-screen language, then Czech and Slovak as the
## home markets. The original languages keep their familiar order and later additions follow in
## the order in which they shipped.
const LANGUAGES: Array[Dictionary] = [
    {"locale": "en", "flag": "button_language_english.png", "name_key": "LANGUAGE_ENGLISH"},
    {"locale": "cs", "flag": "button_language_czech.png", "name_key": "LANGUAGE_CZECH"},
    {"locale": "sk", "flag": "button_language_slovakia.png", "name_key": "LANGUAGE_SLOVAK"},
    {"locale": "de", "flag": "button_language_germany.png", "name_key": "LANGUAGE_GERMAN"},
    {"locale": "es", "flag": "button_language_spain.png", "name_key": "LANGUAGE_SPANISH"},
    {"locale": "fi", "flag": "button_language_finland.png", "name_key": "LANGUAGE_FINNISH"},
    {"locale": "fr", "flag": "button_language_france.png", "name_key": "LANGUAGE_FRENCH"},
    {"locale": "nb", "flag": "button_language_norway.png", "name_key": "LANGUAGE_NORWEGIAN"},
    {"locale": "pl", "flag": "button_language_poland.png", "name_key": "LANGUAGE_POLISH"},
    {"locale": "sv", "flag": "button_language_sweden.png", "name_key": "LANGUAGE_SWEDISH"},
    {
        "locale": "pt_BR",
        "flag": "button_language_brazil.png",
        "name_key": "LANGUAGE_PORTUGUESE_BRAZIL",
    },
    {
        "locale": "pt_PT",
        "flag": "button_language_portugal.png",
        "name_key": "LANGUAGE_PORTUGUESE_PORTUGAL",
    },
    {"locale": "it", "flag": "button_language_italy.png", "name_key": "LANGUAGE_ITALIAN"},
    {
        "locale": "da",
        "flag": "button_language_denmark.png",
        "name_key": "LANGUAGE_DANISH",
    },
    {"locale": "nl", "flag": "button_language_netherlands.png", "name_key": "LANGUAGE_DUTCH"},
    {"locale": "ja", "flag": "button_language_japan.png", "name_key": "LANGUAGE_JAPANESE"},
    {"locale": "ko", "flag": "button_language_south-korea.png", "name_key": "LANGUAGE_KOREAN"},
    {"locale": "tr", "flag": "button_language_turkey.png", "name_key": "LANGUAGE_TURKISH"},
    {"locale": "vi", "flag": "button_language_vietnam.png", "name_key": "LANGUAGE_VIETNAMESE"},
    {
        "locale": "id",
        "flag": "button_language_indonesia.png",
        "name_key": "LANGUAGE_INDONESIAN",
    },
]


static func locales() -> Array[String]:
    var codes: Array[String] = []
    for language in LANGUAGES:
        codes.append(String(language["locale"]))
    return codes


static func has_locale(locale: String) -> bool:
    for language in LANGUAGES:
        if String(language["locale"]) == locale:
            return true
    return false


static func flag_path(locale: String) -> String:
    for language in LANGUAGES:
        if String(language["locale"]) == locale:
            return FLAG_DIRECTORY + String(language["flag"])
    return ""


static func name_key(locale: String) -> String:
    for language in LANGUAGES:
        if String(language["locale"]) == locale:
            return String(language["name_key"])
    return ""


## Turns a device locale such as `pt-BR`, `ja_JP`, or legacy Norwegian `no` into a locale the
## catalog ships. Region-specific Portuguese stays distinct; other regional tags fold to their
## language-only catalog entry. A device language Numblop does not ship resolves to English.
static func resolve_device_locale(reported_locale: String) -> String:
    var normalized := reported_locale.replace("-", "_")
    normalized = normalized.split(".")[0].split("@")[0]
    for locale in locales():
        if locale.to_lower() == normalized.to_lower():
            return locale
    var language := normalized.split("_")[0].to_lower()
    if language == "no" or language == "nn":
        return "nb"
    if language == "pt":
        return "pt_BR"
    return language if has_locale(language) else "en"
