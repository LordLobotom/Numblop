extends NumblopTestCase

const TEST_PATH := "user://numblop_nickname_test.json"


func test_sanitize_trims_strips_control_characters_and_clamps_length() -> void:
    equal(LocalNickname.sanitize("  Anička  "), "Anička", "Edges are trimmed")
    equal(LocalNickname.sanitize("   \t  "), "", "Whitespace-only becomes empty")
    equal(LocalNickname.sanitize("Pepa\nNovák"), "PepaNovák", "Control characters removed")
    equal(
        LocalNickname.sanitize("VeryLongNicknameWellOverTheLimit"),
        "VeryLongNickname",
        "Nickname is clamped to 16 characters"
    )


func test_v6_save_without_nickname_loads_as_empty() -> void:
    _remove_test_file()
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 6
    legacy["coins"] = 40
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file = null

    equal(SaveManager.load_nickname(TEST_PATH), "", "Legacy save has no nickname")
    equal(SaveManager.load_profile_id(TEST_PATH), "", "Legacy save has no profile id")
    _remove_test_file()


func test_nickname_round_trips_and_untouched_saves_preserve_it() -> void:
    _remove_test_file()
    equal(
        SaveManager.save_game_state(
            LearningProfile.new(), 12, 34, TEST_PATH, {}, {}, "  Žofka  "
        ),
        OK,
        "Nickname save"
    )
    equal(SaveManager.load_nickname(TEST_PATH), "Žofka", "Nickname is sanitized and saved")
    equal(SaveManager.load_progress(TEST_PATH)["coins"], 12, "Coins survive a nickname save")

    equal(SaveManager.save_profile(LearningProfile.new(), TEST_PATH), OK, "Mastery-only save")
    equal(SaveManager.load_nickname(TEST_PATH), "Žofka", "Per-answer save preserves nickname")

    equal(
        SaveManager.save_game_state(LearningProfile.new(), 12, 34, TEST_PATH, {}, {}, ""),
        OK,
        "Clearing save"
    )
    equal(SaveManager.load_nickname(TEST_PATH), "", "Nickname can be cleared back to empty")
    _remove_test_file()


func test_non_string_nickname_in_save_falls_back_to_empty() -> void:
    _remove_test_file()
    var corrupted := LearningProfile.new().to_dictionary()
    corrupted["nickname"] = 12345
    corrupted["profile_id"] = 67890
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(corrupted))
    file = null

    equal(SaveManager.load_nickname(TEST_PATH), "", "Non-string nickname falls back")
    equal(SaveManager.load_profile_id(TEST_PATH), "", "Non-string profile id falls back")
    _remove_test_file()


func test_profile_id_is_generated_once_and_stays_stable() -> void:
    _remove_test_file()
    equal(
        SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_PATH),
        OK,
        "First v7 save"
    )
    var first_id := SaveManager.load_profile_id(TEST_PATH)
    equal(first_id.length(), 32, "Profile id is 32 hex characters")

    equal(
        SaveManager.save_game_state(LearningProfile.new(), 5, 9, TEST_PATH, {}, {}, "Kuba"),
        OK,
        "Second save"
    )
    equal(SaveManager.load_profile_id(TEST_PATH), first_id, "Profile id never changes")
    _remove_test_file()


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
