extends NumblopTestCase


func test_responsive_harness_pins_both_portrait_sizes_and_locales() -> void:
    var capture_script := _read("res://tests/smoke/capture_responsive.gd")
    var command_script := _read("res://tools/capture-responsive.ps1")
    check(capture_script.contains("Vector2i(390, 844)"), "Phone portrait capture")
    check(capture_script.contains("Vector2i(450, 900)"), "Desktop portrait capture")
    check(capture_script.contains("Vector2i(900, 900)"), "Wide Web capture")
    check(capture_script.contains('["en", "cs"]'), "English and Czech captures")
    check(command_script.contains("NUMBLOP_RESPONSIVE_ARTIFACTS_OK"), "Artifact marker")
    check(command_script.contains("artifacts\\responsive"), "Ignored artifact output")


func test_responsive_harness_covers_every_m1_screen_state() -> void:
    var capture_script := _read("res://tests/smoke/capture_responsive.gd")
    for screen_name in [
        "home",
        "home_accessories",
        "home_duck",
        "home_name",
        "cosmetics",
        "cosmetics_color",
        "cosmetics_buy",
        "cosmetics_hat",
        "trophy",
        "map",
        "map_detail",
        "map_unlock",
        "settings",
        "settings_exit",
        "choice",
        "milestone",
        "keypad",
        "reward",
    ]:
        check(capture_script.contains('"%s"' % screen_name), "Capture state: %s" % screen_name)


func _read(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    check(file != null, "File must open: %s" % path)
    return "" if file == null else file.get_as_text()
