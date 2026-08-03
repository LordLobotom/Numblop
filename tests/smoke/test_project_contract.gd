extends NumblopTestCase


func test_public_identity_and_portrait_window_are_pinned() -> void:
    equal(ProjectSettings.get_setting("application/config/name"), "Numblop", "Public name")
    equal(ProjectSettings.get_setting("application/config/version"), "0.2.2", "Public version")
    equal(
        ProjectSettings.get_setting("application/config/icon"),
        "res://ui/branding/numblop_ico.png",
        "Numblop application icon"
    )
    equal(
        ProjectSettings.get_setting("application/boot_splash/image"),
        "res://ui/branding/boot_splash.png",
        "Branded boot splash replaces the engine logo"
    )
    check(
        ProjectSettings.get_setting("application/boot_splash/bg_color") is Color,
        "Boot splash background color is pinned"
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
    equal(config.count('version/name="0.2.2"'), 2, "Android exports use the public version")
    equal(config.count("version/code=4"), 2, "Android exports share the Play version code")
    check(config.contains('gradle_build/min_sdk="24"'), "Release preset pins Min SDK 24")
    check(config.contains('gradle_build/target_sdk="36"'), "Release preset pins Target SDK 36")
    # tools/export.ps1 -Target android-release-unsigned flips this off for one build and
    # restores it; a committed "false" means a crashed export left the preset behind.
    equal(config.count("package/signed=true"), 2, "Both Android presets stay signed by default")
    equal(config.count("permissions/vibrate=true"), 2, "Reward chest haptic needs VIBRATE")
    equal(config.count("user_data_backup/allow=true"), 2, "Profile survives device migration")
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
        config.count('launcher_icons/main_192x192="res://ui/branding/android/icon_main_192.png"'),
        2,
        "Android debug and release launcher icons"
    )
    for adaptive_layer in ["foreground", "background", "monochrome"]:
        equal(
            config.count(
                'launcher_icons/adaptive_%s_432x432="res://ui/branding/android/icon_%s_432.png"'
                % [adaptive_layer, adaptive_layer]
            ),
            2,
            "Adaptive %s icon wired in both Android presets" % adaptive_layer
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
