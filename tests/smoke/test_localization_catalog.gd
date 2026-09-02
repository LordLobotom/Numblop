extends NumblopTestCase

## Every column in `localization/strings.csv` is a language the game ships. A blank cell is not
## a gap a player forgives: Godot falls back to the raw key, so the screen reads "MAP_TITLE".

const EXPECTED_HEADER := [
    "keys", "en", "cs", "sk", "de", "es", "fi", "fr", "nb", "pl", "sv",
    "pt_BR", "pt_PT", "it", "da", "nl", "ja", "ko", "tr", "vi", "id",
]


func test_catalog_contains_every_shipped_language_for_every_key() -> void:
    var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
    check(file != null, "Localization catalog must open")
    if file == null:
        return
    var header := file.get_csv_line()
    equal(Array(header), EXPECTED_HEADER, "Catalog header")
    var key_count := 0
    while file.get_position() < file.get_length():
        var row := file.get_csv_line()
        if row.size() == 1 and row[0].is_empty():
            continue
        equal(row.size(), EXPECTED_HEADER.size(), "Catalog row width")
        if row.size() != EXPECTED_HEADER.size():
            continue
        check(not row[0].is_empty(), "Translation key cannot be empty")
        for column in range(1, row.size()):
            check(
                not row[column].is_empty(),
                "%s is missing its %s text" % [row[0], EXPECTED_HEADER[column]]
            )
        key_count += 1
    check(key_count >= 8, "Expected initial translation keys")


func test_the_catalog_columns_match_the_languages_the_game_offers() -> void:
    # The picker builds itself from LanguageCatalog, so a language added there without a column
    # here would show a flag that switches the whole app to raw keys.
    var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
    check(file != null, "Localization catalog must open")
    if file == null:
        return
    var columns := Array(file.get_csv_line())
    columns.remove_at(0)
    for locale in LanguageCatalog.locales():
        check(columns.has(locale), "%s has a column in the catalog" % locale)
    equal(columns.size(), LanguageCatalog.locales().size(), "No orphan catalog columns")


func test_every_translation_keeps_the_placeholders_english_uses() -> void:
    # A dropped {count} silently prints the sentence without the number; a renamed one prints
    # the braces. Neither shows up until that language is actually played.
    var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
    check(file != null, "Localization catalog must open")
    if file == null:
        return
    var header := file.get_csv_line()
    var pattern := RegEx.create_from_string("\\{[a-z_]+\\}")
    while file.get_position() < file.get_length():
        var row := file.get_csv_line()
        if row.size() != header.size():
            continue
        var expected := _placeholders(pattern, row[1])
        for column in range(2, row.size()):
            equal(
                _placeholders(pattern, row[column]),
                expected,
                "%s [%s] keeps the English placeholders" % [row[0], header[column]]
            )


func test_runtime_catalog_switches_between_the_shipped_languages() -> void:
    var previous_locale := TranslationServer.get_locale()
    var expected_play := {
        "en": "Play",
        "cs": "Hrát",
        "sk": "Hrať",
        "de": "Spielen",
        "es": "Jugar",
        "fi": "Pelaa",
        "fr": "Jouer",
        "nb": "Spill",
        "pl": "Graj",
        "sv": "Spela",
        "pt_BR": "Jogar",
        "pt_PT": "Jogar",
        "it": "Gioca",
        "da": "Spil",
        "nl": "Spelen",
        "ja": "プレイ",
        "ko": "플레이",
        "tr": "Oyna",
        "vi": "Chơi",
        "id": "Main",
    }
    for locale in expected_play:
        TranslationServer.set_locale(String(locale))
        equal(
            TranslationServer.translate("HOME_PLAY"),
            String(expected_play[locale]),
            "%s runtime translation" % locale
        )
    TranslationServer.set_locale(previous_locale)


func test_device_locales_resolve_to_the_right_catalog_column() -> void:
    equal(LanguageCatalog.resolve_device_locale("pt_BR"), "pt_BR", "Brazilian Portuguese")
    equal(LanguageCatalog.resolve_device_locale("pt-PT"), "pt_PT", "European Portuguese")
    equal(LanguageCatalog.resolve_device_locale("pt"), "pt_BR", "Generic Portuguese default")
    equal(LanguageCatalog.resolve_device_locale("ja_JP"), "ja", "Japanese region folds")
    equal(LanguageCatalog.resolve_device_locale("ko-KR"), "ko", "Korean region folds")
    equal(LanguageCatalog.resolve_device_locale("no_NO"), "nb", "Legacy Norwegian folds")
    equal(LanguageCatalog.resolve_device_locale("zh_CN"), "en", "Unsupported locale falls back")


func test_czech_mastery_band_names_match_the_learning_language() -> void:
    var previous_locale := TranslationServer.get_locale()
    TranslationServer.set_locale("cs")
    equal(TranslationServer.translate("MAP_FACT_BUILDING"), "Objevuji", "Red band")
    equal(TranslationServer.translate("MAP_FACT_PRACTICING"), "Procvičuji", "Purple band")
    equal(TranslationServer.translate("MAP_FACT_MASTERED"), "Upevňuji", "Orange band")
    equal(TranslationServer.translate("MAP_FACT_AUTOMATED"), "Mám jistotu", "Green band")
    TranslationServer.set_locale(previous_locale)


func _placeholders(pattern: RegEx, text: String) -> Array:
    var found: Array = []
    for result in pattern.search_all(text):
        found.append(result.get_string())
    found.sort()
    return found
