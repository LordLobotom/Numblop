extends NumblopTestCase

const TEST_PATH := "user://numblop_settings_test.cfg"


func test_explicit_language_choice_is_remembered() -> void:
    var previous_preference: String = SettingsManager.locale_preference
    var previous_audio := SettingsManager.audio_preferences()
    _remove_test_file()
    equal(
        SettingsManager.set_locale_preference("cs", TEST_PATH),
        OK,
        "Save Czech preference"
    )
    SettingsManager.locale_preference = SettingsManager.SYSTEM_LOCALE
    SettingsManager.load_settings(TEST_PATH)
    equal(SettingsManager.locale_preference, "cs", "Remembered Czech preference")
    SettingsManager.locale_preference = previous_preference
    SettingsManager.preview_audio_preferences(
        float(previous_audio["music_volume"]),
        float(previous_audio["sfx_volume"]),
        bool(previous_audio["muted"])
    )
    SettingsManager.apply_locale()
    _remove_test_file()


func test_audio_preferences_are_clamped_saved_and_applied_to_separate_buses() -> void:
    var previous_preference := SettingsManager.locale_preference
    var previous_audio := SettingsManager.audio_preferences()
    _remove_test_file()

    equal(
        SettingsManager.set_audio_preferences(1.4, 0.35, true, TEST_PATH),
        OK,
        "Save audio preferences"
    )
    SettingsManager.preview_audio_preferences(0.0, 0.0, false)
    SettingsManager.load_settings(TEST_PATH)
    equal(SettingsManager.music_volume, 1.0, "Music volume is clamped")
    equal(SettingsManager.sfx_volume, 0.35, "SFX volume is remembered")
    check(SettingsManager.audio_muted, "Mute is remembered")
    SettingsManager.apply_audio()

    var music_bus := AudioServer.get_bus_index("Music")
    var sfx_bus := AudioServer.get_bus_index("SFX")
    check(music_bus >= 0, "Music bus exists")
    check(sfx_bus >= 0, "SFX bus exists")
    if music_bus >= 0 and sfx_bus >= 0:
        check(AudioServer.is_bus_mute(music_bus), "Music bus is muted")
        check(AudioServer.is_bus_mute(sfx_bus), "SFX bus is muted")

    SettingsManager.locale_preference = previous_preference
    SettingsManager.preview_audio_preferences(
        float(previous_audio["music_volume"]),
        float(previous_audio["sfx_volume"]),
        bool(previous_audio["muted"])
    )
    SettingsManager.apply_locale()
    _remove_test_file()


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
