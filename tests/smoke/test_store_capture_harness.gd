extends NumblopTestCase


func test_store_harness_produces_play_compliant_bilingual_screenshots() -> void:
    var capture_script := _read("res://tests/smoke/capture_store.gd")
    var command_script := _read("res://tools/capture-store.ps1")
    check(capture_script.contains("Vector2i(1080, 1920)"), "9:16 store capture size")
    check(capture_script.contains("size_2d_override"), "Store captures reuse the app stretch")
    check(command_script.contains("NUMBLOP_STORE_ARTIFACTS_OK"), "Artifact marker")
    check(command_script.contains("store\\screenshots"), "Versioned store output")
    for screen_name in [
        "home_accessories",
        "map",
        "choice",
        "keypad",
        "reward",
        "cosmetics",
    ]:
        check(capture_script.contains('"%s"' % screen_name), "Store state: %s" % screen_name)


func _read(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    check(file != null, "File must open: %s" % path)
    return "" if file == null else file.get_as_text()
