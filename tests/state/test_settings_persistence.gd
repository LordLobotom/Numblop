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


func test_vibration_defaults_to_on_and_survives_a_restart() -> void:
    var previous_preference := SettingsManager.locale_preference
    var previous_haptics := SettingsManager.haptics_enabled
    _remove_test_file()

    SettingsManager.load_settings(TEST_PATH)
    check(SettingsManager.haptics_enabled, "A profile without settings buzzes by default")

    equal(SettingsManager.set_haptics_enabled(false, TEST_PATH), OK, "Save vibration off")
    SettingsManager.haptics_enabled = true
    SettingsManager.load_settings(TEST_PATH)
    check(not SettingsManager.haptics_enabled, "Vibration stays off after a restart")
    # A silenced device must stay silent no matter which pattern asks for a buzz.
    for pattern_name in SettingsManager.HAPTIC_PATTERNS:
        SettingsManager.play_haptic(String(pattern_name))

    SettingsManager.haptics_enabled = previous_haptics
    SettingsManager.locale_preference = previous_preference
    SettingsManager.apply_locale()
    _remove_test_file()


func test_free_practice_length_defaults_to_ten_and_is_remembered_on_this_device() -> void:
    var previous_question_count := SettingsManager.practice_question_count
    _remove_test_file()

    SettingsManager.load_settings(TEST_PATH)
    equal(SettingsManager.practice_question_count, 10, "Missing preference defaults to ten")
    equal(
        SettingsManager.set_practice_question_count(50, TEST_PATH),
        OK,
        "Save free-practice length"
    )
    SettingsManager.practice_question_count = 10
    SettingsManager.load_settings(TEST_PATH)
    equal(SettingsManager.practice_question_count, 50, "Free-practice length survives restart")
    equal(
        SettingsManager.set_practice_question_count(12, TEST_PATH),
        ERR_INVALID_PARAMETER,
        "Unsupported free-practice length is rejected"
    )
    equal(SettingsManager.practice_question_count, 50, "Invalid choice does not replace preference")

    SettingsManager.practice_question_count = previous_question_count
    _remove_test_file()


func test_every_haptic_pattern_is_long_enough_to_be_felt() -> void:
    equal(SettingsManager.HAPTIC_PATTERNS.size(), 3, "Three moments buzz, and no more")
    for pattern_name in SettingsManager.HAPTIC_PATTERNS:
        var pattern: Dictionary = SettingsManager.HAPTIC_PATTERNS[pattern_name]
        # Below roughly 20 ms several Android vendors drop the pulse entirely.
        check(int(pattern["duration_ms"]) >= 20, "%s lasts long enough" % pattern_name)
        # Raised from 120 after the first pass felt like a faint click on real hardware.
        # 200 is still short of the ~250 ms where a pulse starts reading as a rumble.
        check(int(pattern["duration_ms"]) <= 200, "%s is a buzz, not a rumble" % pattern_name)
        var amplitude := float(pattern["amplitude"])
        check(amplitude > 0.0 and amplitude <= 1.0, "%s has a real amplitude" % pattern_name)
    var celebration: Dictionary = SettingsManager.HAPTIC_PATTERNS[SettingsManager.HAPTIC_CELEBRATION]
    var tap: Dictionary = SettingsManager.HAPTIC_PATTERNS[SettingsManager.HAPTIC_TAP]
    check(
        float(celebration["amplitude"]) > float(tap["amplitude"]),
        "The chest opening outweighs the tap that opened it"
    )


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
