extends NumblopTestCase


func test_public_identity_and_portrait_window_are_pinned() -> void:
    equal(ProjectSettings.get_setting("application/config/name"), "Numblop", "Public name")
    equal(ProjectSettings.get_setting("application/config/version"), "0.5.2", "Public version")
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


func test_stretch_settings_guarantee_the_design_height_is_never_squeezed() -> void:
    # With canvas_items + expand the scale is min(window.x / 390, window.y / 844), so the
    # viewport is 844 tall whenever the display is relatively wider than the design, and
    # taller otherwise. Height therefore never drops below 844 and only width grows
    # (390 on a 19.5:9 phone, 474 on 16:9, 633 on a 4:3 tablet). That is what lets every
    # screen author a fixed vertical stack and stay responsive on the horizontal axis
    # alone. Changing either setting reintroduces vertical overflow.
    equal(
        ProjectSettings.get_setting("display/window/stretch/mode"),
        "canvas_items",
        "Stretch mode keeps the design resolution as the layout unit"
    )
    equal(
        ProjectSettings.get_setting("display/window/stretch/aspect"),
        "expand",
        "Expand grows the viewport instead of letterboxing or squeezing it"
    )


func test_android_identity_and_offline_export_contract_are_pinned() -> void:
    var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
    check(file != null, "Export presets must open")
    if file == null:
        return
    var config := file.get_as_text()
    check(config.contains('package/unique_name="cz.gutcloud.numblop"'), "Permanent package ID")
    check(config.contains('gradle_build/export_format=1'), "Release preset builds an AAB")
    equal(config.count('version/name="0.5.2"'), 2, "Android exports use the public version")
    equal(config.count("version/code=24"), 2, "Android exports share the Play version code")
    check(config.contains('gradle_build/min_sdk="24"'), "Release preset pins Min SDK 24")
    check(config.contains('gradle_build/target_sdk="36"'), "Release preset pins Target SDK 36")
    # tools/export.ps1 -Target android-release-unsigned flips this off for one build and
    # restores it; a committed "false" means a crashed export left the preset behind.
    equal(config.count("package/signed=true"), 2, "Both Android presets stay signed by default")
    equal(config.count("permissions/vibrate=true"), 2, "Reward chest haptic needs VIBRATE")
    equal(config.count("user_data_backup/allow=true"), 2, "Profile survives device migration")
    check(not config.contains("audio/*"), "MVP audio must remain exportable")


## Numblop requested no network access at all until Play Games Services was approved (M5, see
## `docs/GOOGLE_PLAY_GAMES.md`). The `permissions/internet=false` pin that used to live above was
## deliberately replaced rather than deleted: the point of that tripwire was that nobody could put
## a children's app online by accident, and these assertions carry the same duty forward.
func test_network_access_is_exactly_what_play_games_needs_and_nothing_more() -> void:
    var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
    check(file != null, "Export presets must open")
    if file == null:
        return
    var config := file.get_as_text()
    equal(config.count("permissions/internet=true"), 2, "Play Games sign-in and sync need INTERNET")
    equal(
        config.count("permissions/access_network_state=true"),
        2,
        "Knowing whether the device is offline avoids pointless sync attempts"
    )
    # An advertising id in a children's app is a policy violation and would make the data-safety
    # declaration false. Google Play services modules have pulled it in before, so it is asserted
    # rather than assumed; a merged-manifest check belongs with the release verification.
    check(
        not config.contains("permissions/ad_id=true"),
        "No advertising id permission may be requested"
    )
    for forbidden in [
        "permissions/access_fine_location=true",
        "permissions/access_coarse_location=true",
        "permissions/camera=true",
        "permissions/record_audio=true",
        "permissions/read_contacts=true",
    ]:
        check(not config.contains(forbidden), "%s stays off" % forbidden)
    # The plugin is linked through the Gradle build, so a preset that skips it silently ships an
    # app whose sign-in can never work.
    equal(
        config.count("gradle_build/use_gradle_build=true"),
        2,
        "Both Android presets build through Gradle so the Play Games plugin is linked"
    )


func test_aab_verifier_checks_the_merged_network_permission_contract() -> void:
    var file := FileAccess.open("res://tools/verify-aab.ps1", FileAccess.READ)
    check(file != null, "AAB verifier must open")
    if file == null:
        return
    var verifier := file.get_as_text()
    for required in [
        "android\\.permission\\.VIBRATE",
        "android\\.permission\\.INTERNET",
        "android\\.permission\\.ACCESS_NETWORK_STATE",
    ]:
        check(verifier.contains(required), "AAB verifier requires %s" % required)
    for forbidden in [
        "android\\.permission\\.AD_ID",
        "com\\.google\\.android\\.gms\\.permission\\.AD_ID",
        "android\\.permission\\.ACCESS_FINE_LOCATION",
        "android\\.permission\\.ACCESS_COARSE_LOCATION",
        "android\\.permission\\.CAMERA",
        "android\\.permission\\.RECORD_AUDIO",
        "android\\.permission\\.READ_CONTACTS",
    ]:
        check(verifier.contains(forbidden), "AAB verifier rejects %s" % forbidden)
    check(
        not verifier.contains("Numblop must stay offline"),
        "Verifier no longer rejects the approved Play Games network permission"
    )


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
    # The two drawn layers keep their artwork names; only the derived glyph is generated.
    for layer in [
        ["foreground", "res://ui/branding/android/icon_numblop_front.png"],
        ["background", "res://ui/branding/android/icon_numblop_back.png"],
        ["monochrome", "res://ui/branding/android/icon_monochrome_432.png"],
    ]:
        equal(
            config.count(
                'launcher_icons/adaptive_%s_432x432="%s"' % [layer[0], layer[1]]
            ),
            2,
            "Adaptive %s icon wired in both Android presets" % layer[0]
        )
        check(
            FileAccess.file_exists(layer[1]),
            "Adaptive %s icon exists on disk" % layer[0]
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
