extends NumblopTestCase

## Guards the Play Console import against the catalog drifting away from it.
##
## The exporter reads names, descriptions and step targets straight from `AchievementCatalog`, so
## those cannot drift. The Play point values cannot be derived from anything and are a hand-kept
## table, which is exactly the kind of list that is forgotten when a new achievement is added.

const EXPORTER := preload("res://tests/smoke/export_play_achievements.gd")


func test_every_achievement_has_a_play_point_value() -> void:
    var points: Dictionary = EXPORTER.POINTS
    for entry in AchievementCatalog.definitions():
        var achievement_id := String(entry["id"])
        check(points.has(achievement_id), "%s has a Play point value" % achievement_id)
    equal(
        points.size(),
        AchievementCatalog.definitions().size(),
        "No Play point value outlives the achievement it belonged to"
    )


func test_play_point_values_obey_the_console_budget() -> void:
    var points: Dictionary = EXPORTER.POINTS
    var total := 0
    for achievement_id in points:
        var value := int(points[achievement_id])
        check(value > 0, "%s scores something" % achievement_id)
        equal(value % 5, 0, "%s is a multiple of 5" % achievement_id)
        check(
            value <= EXPORTER.MAXIMUM_ACHIEVEMENT_POINTS,
            "%s is within the per-achievement cap" % achievement_id
        )
        total += value
    check(
        total <= EXPORTER.MAXIMUM_TOTAL_POINTS,
        "The catalog spends %d of the %d Play points available" % [
            total,
            EXPORTER.MAXIMUM_TOTAL_POINTS,
        ]
    )


func test_every_shipped_language_maps_to_a_locale_the_game_is_configured_for() -> void:
    # A single unconfigured locale rejects the whole import, and Console reports it by listing all
    # 25 achievements rather than the locale, so it is cheaper to catch here. Two codes do not
    # follow the `xx-YY` pattern: Slovak is bare `sk`, and Norwegian is `no-NO`.
    var play_locales: Dictionary = EXPORTER.PLAY_LOCALES
    var console_locales: Array = EXPORTER.CONSOLE_LOCALES
    for locale in LanguageCatalog.locales():
        if locale == EXPORTER.DEFAULT_LOCALE:
            continue
        check(play_locales.has(locale), "%s has a Play Console locale code" % locale)
        if not play_locales.has(locale):
            continue
        var play_locale := String(play_locales[locale])
        check(
            console_locales.has(play_locale),
            "%s maps to %s which the game is configured for" % [locale, play_locale]
        )


func test_no_achievement_text_contains_a_comma_in_any_language() -> void:
    # The Console CSVs are unquoted, and one comma shifts every column after it.
    var previous_locale := TranslationServer.get_locale()
    for locale in LanguageCatalog.locales():
        TranslationServer.set_locale(locale)
        for entry in AchievementCatalog.definitions():
            var format_args: Variant = entry.get("format_args", {})
            for key in [String(entry["title_key"]), String(entry["description_key"])]:
                var text := tr(key)
                if format_args is Dictionary and not (format_args as Dictionary).is_empty():
                    text = text.format(format_args)
                check(
                    not text.contains(","),
                    "%s in %s has no comma: '%s'" % [key, locale, text]
                )
    TranslationServer.set_locale(previous_locale)
