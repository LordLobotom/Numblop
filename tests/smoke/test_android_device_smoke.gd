extends NumblopTestCase


func test_android_device_command_installs_launches_and_filters_logs() -> void:
    var script := _read("res://tools/android-smoke.ps1")
    check(script.contains("cz.gutcloud.numblop"), "Permanent package ID")
    check(script.contains('"install", "-r", "-t"'), "Update-compatible debug install")
    check(script.contains("force-stop"), "Clean launch")
    check(script.contains("android.intent.category.LAUNCHER"), "Launcher start")
    check(script.contains('"logcat", "-d", "--pid='), "PID-filtered device log")
    check(script.contains("NUMBLOP_ANDROID_DEVICE_SMOKE_OK"), "Success marker")


func test_release_guide_has_the_physical_m1_checklist() -> void:
    var releases := _read("res://docs/RELEASES.md")
    check(releases.contains("tools/android-smoke.ps1"), "Documented command")
    check(releases.contains("four choices, six choices, and the numeric keypad"), "Answer modes")
    check(releases.contains("Tap the chest once"), "Chest verification")
    check(releases.contains("switch apps"), "Lifecycle verification")
    check(releases.contains("networking disabled"), "Offline verification")


func _read(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    check(file != null, "File must open: %s" % path)
    return "" if file == null else file.get_as_text()
