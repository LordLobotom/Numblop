extends NumblopTestCase


func test_main_scene_has_touch_ready_portrait_controls() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    var scene := packed.instantiate()
    var play_button: Button = scene.get_node("%PlayButton")
    var language_select: OptionButton = scene.get_node("%LanguageSelect")
    equal(scene.get_node("%TitleLabel").text, "Numblop", "Public title")
    check(play_button.custom_minimum_size.y >= 48.0, "Play touch target")
    check(language_select.custom_minimum_size.y >= 48.0, "Language touch target")
    scene.free()


func test_theme_bundles_fredoka_with_czech_glyphs() -> void:
    var theme: Theme = load("res://ui/theme.tres")
    check(theme != null, "Theme must load")
    if theme == null:
        return
    check(theme.default_font != null, "Fredoka must be the default font")
    if theme.default_font == null:
        return
    var czech_glyphs := "áčďéěíňóřšťúůýž"
    for index in czech_glyphs.length():
        var codepoint := czech_glyphs.unicode_at(index)
        check(theme.default_font.has_char(codepoint), "Fredoka missing Czech glyph: %s" % codepoint)
