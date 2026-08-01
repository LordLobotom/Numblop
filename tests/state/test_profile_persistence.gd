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


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
