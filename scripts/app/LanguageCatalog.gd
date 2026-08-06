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
## home markets; the rest alphabetically by their own name.
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
