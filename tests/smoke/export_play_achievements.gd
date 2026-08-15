extends Node

## Writes the Play Console bulk-achievement import from the game's own catalog.
##
## Console offers a ZIP import instead of typing 25 achievements into a web form ten times over.
## The names, descriptions and step targets in that ZIP must be the ones the game actually shows,
## so they are read from `AchievementCatalog` and `localization/strings.csv` rather than retyped:
## anything retyped drifts the first time a string is reworded.
##
## Two things genuinely are editorial and live here rather than in the catalog: the Play point
## value of each achievement, and the fact that none of them is hidden.

const OUTPUT_DIRECTORY := "res://artifacts/play-achievements"
const ICON_SOURCE_DIRECTORY := "res://store/achievements"
## The default locale carries `Name` and `Description` in the metadata file; Console rejects a
## localization row that repeats it.
const DEFAULT_LOCALE := "en"

## Play Console locale codes for the ten shipped languages.
##
## Console rejects the whole import if one row names a locale the game is not configured for, and
## it then lists every achievement rather than the offending locale, so these are copied from the
## game's own language list in Console rather than guessed from the language tag. Two do not follow
## the `xx-YY` pattern that the other seven do: **Slovak is bare `sk`** with no region, and
## Norwegian is `no-NO` rather than `nb-NO`.
const PLAY_LOCALES: Dictionary = {
    "cs": "cs-CZ",
    "sk": "sk",
    "de": "de-DE",
    "es": "es-ES",
    "fi": "fi-FI",
    "fr": "fr-FR",
    "nb": "no-NO",
    "pl": "pl-PL",
    "sv": "sv-SE",
}

## Every locale the game is configured for in Play Games Services, as shown in Console. A
## localization row may only name one of these. Kept here so a wrong code fails the test suite
## instead of a Console upload.
const CONSOLE_LOCALES: Array[String] = [
    "en-US", "en-AU", "en-CA", "en-GB", "en-IN", "en-SG", "en-ZA",
    "fi-FI", "fr-FR", "fr-CA", "no-NO", "de-DE", "pl-PL", "sk", "cs-CZ",
    "es-419", "es-US", "es-ES", "sv-SE",
]

## Play XP is `100 * points`, a game may spend 2000 points in total, each value is a multiple of 5,
## and no single achievement may exceed 200. These are scaled by how much practice each one really
## costs a child, and they deliberately spend only about half the budget: Google's own advice is to
## keep a reserve for achievements added with later content.
const POINTS: Dictionary = {
    "first_steps": 5,
    "streak_10": 5,
    "streak_20": 10,
    "streak_50": 20,
    "streak_100": 40,
    "streak_500": 80,
    "streak_1000": 120,
    "experience_500": 15,
    "experience_1000": 25,
    "experience_5000": 60,
    "experience_10000": 100,
    "collection_body_color": 40,
    "collection_belly_color": 45,
    "collection_hat": 45,
    "collection_glasses": 40,
    "collection_necklace": 40,
    "collection_footwear": 40,
    "island_2": 25,
    "island_3": 30,
    "island_4": 35,
    "island_5": 40,
    "island_6": 45,
    "island_7": 50,
    "island_8": 55,
    "island_9": 65,
}
const MAXIMUM_TOTAL_POINTS := 2000
const MAXIMUM_ACHIEVEMENT_POINTS := 200

var _failed := false


func _ready() -> void:
    var output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        _fail("Could not create %s" % OUTPUT_DIRECTORY)
        return

    var definitions := AchievementCatalog.definitions()
    var names := _default_names(definitions)
    _check_points(definitions)
    _check_names(names)

    _write(output.path_join("AchievementsMetadata.csv"), _metadata_rows(definitions, names))
    _write(
        output.path_join("AchievementsLocalizations.csv"),
        _localization_rows(definitions, names)
    )
    _write(output.path_join("AchievementsIconsMappings.csv"), _icon_rows(definitions, names))
    _copy_icons(definitions, output)

    if _failed:
        get_tree().quit(1)
        return
    print("NUMBLOP_PLAY_ACHIEVEMENTS_OK")
    get_tree().quit(0)


## `Name,Description,Incremental Value,Steps Needed,Initial State,Points,List Order`, no header row.
##
## Everything except the first round is incremental: Play draws a progress bar for those, and the
## game already knows the absolute progress to push. `List Order` follows the catalog, so the
## Console list reads in the same order as the Trophies screen.
func _metadata_rows(definitions: Array[Dictionary], names: Dictionary) -> Array[String]:
    _set_locale(DEFAULT_LOCALE)
    var rows: Array[String] = []
    var list_order := 1
    for entry in definitions:
        var achievement_id := String(entry["id"])
        var target := int(entry["target"])
        var incremental := target > 1
        rows.append(_row([
            names[achievement_id],
            _text(String(entry["description_key"]), entry.get("format_args", {})),
            "True" if incremental else "False",
            str(target) if incremental else "",
            # Nothing here is a spoiler, and a child who cannot see what to aim for cannot aim.
            "Revealed",
            str(int(POINTS[achievement_id])),
            str(list_order),
        ]))
        list_order += 1
    return rows


## `Name,Localized name,Localized description,Locale`, no header row.
func _localization_rows(definitions: Array[Dictionary], names: Dictionary) -> Array[String]:
    var rows: Array[String] = []
    for locale in LanguageCatalog.locales():
        if locale == DEFAULT_LOCALE:
            continue
        if not PLAY_LOCALES.has(locale):
            _fail("No Play locale code for %s" % locale)
            continue
        if not CONSOLE_LOCALES.has(String(PLAY_LOCALES[locale])):
            _fail("Play locale %s is not configured for the game" % PLAY_LOCALES[locale])
            continue
        _set_locale(locale)
        for entry in definitions:
            var format_args: Variant = entry.get("format_args", {})
            rows.append(_row([
                names[String(entry["id"])],
                _text(String(entry["title_key"]), format_args),
                _text(String(entry["description_key"]), format_args),
                String(PLAY_LOCALES[locale]),
            ]))
    return rows


## `Name,icon filename`, no header row. Every file it names must be inside the same ZIP.
func _icon_rows(definitions: Array[Dictionary], names: Dictionary) -> Array[String]:
    var rows: Array[String] = []
    for entry in definitions:
        var achievement_id := String(entry["id"])
        rows.append(_row([names[achievement_id], "%s.png" % achievement_id]))
    return rows


func _default_names(definitions: Array[Dictionary]) -> Dictionary:
    _set_locale(DEFAULT_LOCALE)
    var names: Dictionary = {}
    for entry in definitions:
        names[String(entry["id"])] = _text(
            String(entry["title_key"]),
            entry.get("format_args", {})
        )
    return names


func _copy_icons(definitions: Array[Dictionary], output: String) -> void:
    var source := ProjectSettings.globalize_path(ICON_SOURCE_DIRECTORY)
    for entry in definitions:
        var file_name := "%s.png" % String(entry["id"])
        var from := source.path_join(file_name)
        if not FileAccess.file_exists(from):
            _fail("Missing Console icon: %s" % from)
            continue
        if DirAccess.copy_absolute(from, output.path_join(file_name)) != OK:
            _fail("Could not copy %s" % file_name)


## Console rejects a whole import over the point budget, so it is caught here rather than there.
func _check_points(definitions: Array[Dictionary]) -> void:
    var total := 0
    for entry in definitions:
        var achievement_id := String(entry["id"])
        if not POINTS.has(achievement_id):
            _fail("No Play point value for %s" % achievement_id)
            continue
        var points := int(POINTS[achievement_id])
        if points <= 0 or points % 5 != 0:
            _fail("%s: points must be a positive multiple of 5, got %d" % [achievement_id, points])
        if points > MAXIMUM_ACHIEVEMENT_POINTS:
            _fail("%s: %d points exceeds the %d cap" % [
                achievement_id,
                points,
                MAXIMUM_ACHIEVEMENT_POINTS,
            ])
        total += points
    if total > MAXIMUM_TOTAL_POINTS:
        _fail("Point total %d exceeds the %d budget" % [total, MAXIMUM_TOTAL_POINTS])
    print("Play points: %d of %d, %d left for later achievements" % [
        total,
        MAXIMUM_TOTAL_POINTS,
        MAXIMUM_TOTAL_POINTS - total,
    ])


## The default name is the key the other two files join on, so a duplicate would silently merge two
## achievements into one.
func _check_names(names: Dictionary) -> void:
    var seen: Dictionary = {}
    for achievement_id in names:
        var name_text := String(names[achievement_id])
        if seen.has(name_text):
            _fail("Duplicate achievement name '%s' (%s and %s)" % [
                name_text,
                seen[name_text],
                achievement_id,
            ])
        seen[name_text] = achievement_id


func _set_locale(locale: String) -> void:
    TranslationServer.set_locale(locale)


func _text(key: String, format_args: Variant) -> String:
    var text := tr(key)
    if format_args is Dictionary and not (format_args as Dictionary).is_empty():
        text = text.format(format_args)
    return text


## Console reads these as plain comma-separated values with no quoting, and documents that a name
## or description may not contain a comma. A stray one would shift every later column, so it is a
## hard failure rather than something to escape around.
func _row(values: Array) -> String:
    var cells: Array[String] = []
    for value in values:
        var cell := String(value).strip_edges()
        if cell.contains(","):
            _fail("Comma in Play achievement field: '%s'" % cell)
            cell = cell.replace(",", " ")
        cells.append(cell)
    return ",".join(cells)


func _write(path: String, rows: Array[String]) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _fail("Could not write %s" % path)
        return
    # No header row: Console treats the first line as data.
    file.store_string("\r\n".join(rows) + "\r\n")
    file.close()
    print("WROTE %s (%d rows)" % [path.get_file(), rows.size()])


func _fail(message: String) -> void:
    push_error(message)
    printerr(message)
    _failed = true
