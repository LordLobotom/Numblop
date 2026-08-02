extends NumblopTestCase


func test_public_identity_and_portrait_window_are_pinned() -> void:
    equal(ProjectSettings.get_setting("application/config/name"), "Numblop", "Public name")
    equal(ProjectSettings.get_setting("application/config/version"), "0.1.0", "Public version")
    equal(
        ProjectSettings.get_setting("application/config/icon"),
        "res://ui/branding/numblop_ico.png",
        "Numblop application icon"
    )
    equal(ProjectSettings.get_setting("display/window/size/viewport_width"), 390, "Viewport width")
    equal(ProjectSettings.get_setting("display/window/size/viewport_height"), 844, "Viewport height")
    equal(ProjectSettings.get_setting("display/window/size/window_width_override"), 450, "Desktop width")
    equal(ProjectSettings.get_setting("display/window/size/window_height_override"), 900, "Desktop height")
    equal(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "Portrait orientation")


func test_android_identity_and_offline_export_contract_are_pinned() -> void:
    var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
    check(file != null, "Export presets must open")
    if file == null:
        return
    var config := file.get_as_text()
    check(config.contains('package/unique_name="cz.gutcloud.numblop"'), "Permanent package ID")
    check(config.contains("permissions/internet=false"), "Android exports remain offline")
    check(config.contains('gradle_build/export_format=1'), "Release preset builds an AAB")
    equal(config.count('version/name="0.1.0"'), 2, "Android exports use the public version")
    check(not config.contains("audio/*"), "MVP audio must remain exportable")


func test_numblop_icon_is_used_by_windows_and_android_exports() -> void:
    var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
    check(file != null, "Export presets must open")
    if file == null:
        return
    var config := file.get_as_text()
    var icon_path := "res://ui/branding/numblop_ico.png"
    check(config.contains('application/icon="%s"' % icon_path), "Windows executable icon")
    equal(
        config.count('launcher_icons/main_192x192="%s"' % icon_path),
        2,
        "Android debug and release launcher icons"
    )


func test_windows_export_uses_the_public_version() -> void:
    var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
    check(file != null, "Export presets must open")
    if file == null:
        return
    var config := file.get_as_text()
    var app_version := str(ProjectSettings.get_setting("application/config/version"))
    check(
        config.contains('application/product_version="%s"' % app_version),
        "Windows export uses the public version"
    )
