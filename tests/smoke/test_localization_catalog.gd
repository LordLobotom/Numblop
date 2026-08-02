extends NumblopTestCase


func test_catalog_contains_english_and_czech_for_every_key() -> void:
    var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
    check(file != null, "Localization catalog must open")
    if file == null:
        return
    var header := file.get_csv_line()
    equal(Array(header), ["keys", "en", "cs"], "Catalog header")
    var key_count := 0
    while file.get_position() < file.get_length():
        var row := file.get_csv_line()
        if row.size() == 1 and row[0].is_empty():
            continue
        equal(row.size(), 3, "Catalog row width")
        if row.size() == 3:
            check(not row[0].is_empty(), "Translation key cannot be empty")
            check(not row[1].is_empty(), "English text cannot be empty")
            check(not row[2].is_empty(), "Czech text cannot be empty")
            key_count += 1
    check(key_count >= 8, "Expected initial translation keys")


func test_runtime_catalog_switches_between_english_and_czech() -> void:
    var previous_locale := TranslationServer.get_locale()
    TranslationServer.set_locale("en")
    equal(TranslationServer.translate("HOME_PLAY"), "Play", "English runtime translation")
    TranslationServer.set_locale("cs")
    equal(TranslationServer.translate("HOME_PLAY"), "Hrát", "Czech runtime translation")
    TranslationServer.set_locale(previous_locale)


func test_czech_mastery_band_names_match_the_learning_language() -> void:
    var previous_locale := TranslationServer.get_locale()
    TranslationServer.set_locale("cs")
    equal(TranslationServer.translate("MAP_FACT_BUILDING"), "Objevuji", "Red band")
    equal(TranslationServer.translate("MAP_FACT_PRACTICING"), "Procvičuji", "Purple band")
    equal(TranslationServer.translate("MAP_FACT_MASTERED"), "Upevňuji", "Orange band")
    equal(TranslationServer.translate("MAP_FACT_AUTOMATED"), "Mám jistotu", "Green band")
    TranslationServer.set_locale(previous_locale)
