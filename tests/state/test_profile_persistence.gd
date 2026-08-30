extends NumblopTestCase

const TEST_PATH := "user://numblop_profile_test.json"


func test_profile_round_trip_preserves_unlocks_and_mastery() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 80)
    profile.set_mastery(3, 7, 46)
    equal(SaveManager.save_profile(profile, TEST_PATH), OK, "Save result")
    var loaded := SaveManager.load_profile(TEST_PATH)
    equal(loaded.current_table(), 3, "Unlocked table")
    equal(loaded.get_mastery(3, 7), 46, "Saved mastery")
    _remove_test_file()


func test_final_table_completion_round_trips_after_mastery_falls() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    for table_value in LearningRules.TABLES:
        for multiplier in range(LearningRules.REQUIRED_FACTS_TO_UNLOCK):
            profile.set_mastery(table_value, multiplier, LearningRules.UNLOCK_MASTERY)
    profile.set_mastery(9, 0, 0)
    equal(SaveManager.save_profile(profile, TEST_PATH), OK, "Save final completion")

    var loaded := SaveManager.load_profile(TEST_PATH)
    check(loaded.final_table_completed, "Final completion survives the round trip")
    check(loaded.is_table_practice_eligible(9), "9x remains practice eligible")
    _remove_test_file()


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
