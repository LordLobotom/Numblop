extends NumblopTestCase

## The save file is the only copy of everything a child has practised. These cases are about the
## moments it could be lost: a process killed mid-write, a corrupted file, a half-finished rename.

const TEST_PATH := "user://numblop_durability_test.json"


func test_a_save_leaves_no_temporary_file_behind() -> void:
    _remove_test_file()
    equal(
        SaveManager.save_game_state(LearningProfile.new(), 10, 20, TEST_PATH),
        OK,
        "First save"
    )
    check(FileAccess.file_exists(TEST_PATH), "Profile exists after a save")
    check(
        not FileAccess.file_exists(TEST_PATH + SaveManager.TEMP_SUFFIX),
        "The temporary file is renamed into place, never left behind"
    )
    _remove_test_file()


func test_the_second_save_keeps_the_first_one_as_a_backup() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 10, 20, TEST_PATH)
    check(
        not FileAccess.file_exists(TEST_PATH + SaveManager.BACKUP_SUFFIX),
        "The very first save has nothing to back up"
    )

    SaveManager.save_game_state(LearningProfile.new(), 99, 20, TEST_PATH)
    check(
        FileAccess.file_exists(TEST_PATH + SaveManager.BACKUP_SUFFIX),
        "The previous save becomes the backup"
    )
    equal(SaveManager.load_progress(TEST_PATH)["coins"], 99, "The primary holds the newest coins")
    _remove_test_file()


func test_a_truncated_profile_recovers_the_previous_save() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 140, 60, TEST_PATH)
    SaveManager.save_game_state(LearningProfile.new(), 150, 70, TEST_PATH)

    # Exactly what a process killed mid-write used to leave behind.
    var truncated := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    truncated.store_string("{\"version\": 10, \"coins\": 15")
    truncated.close()

    var recoveries_before := SaveManager.recovered_loads
    var progress := SaveManager.load_progress(TEST_PATH)
    equal(progress["coins"], 140, "The backup's coins are recovered, not a fresh profile")
    check(SaveManager.recovered_loads > recoveries_before, "The fallthrough is counted")
    _remove_test_file()


func test_a_missing_primary_with_a_backup_still_loads() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 33, 44, TEST_PATH)
    SaveManager.save_game_state(LearningProfile.new(), 55, 66, TEST_PATH)
    # The window between the two renames inside _write_atomically.
    DirAccess.remove_absolute(TEST_PATH)

    equal(SaveManager.load_progress(TEST_PATH)["coins"], 33, "Recovered through the backup")
    _remove_test_file()


func test_a_corrupt_profile_with_no_backup_starts_fresh_without_crashing() -> void:
    _remove_test_file()
    var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    broken.store_string("this is not json at all")
    broken.close()

    equal(SaveManager.load_progress(TEST_PATH)["coins"], 0, "Falls back to a new profile")
    equal(SaveManager.load_profile(TEST_PATH).highest_unlocked_index, 0, "Fresh learning profile")
    _remove_test_file()


func test_recovering_from_the_backup_survives_the_next_save() -> void:
    # The recovered state has to become the real save again, or the next write would quietly
    # rebuild a fresh profile on top of the rescue.
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 210, 90, TEST_PATH)
    SaveManager.save_game_state(LearningProfile.new(), 220, 95, TEST_PATH)
    var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    broken.store_string("{")
    broken.close()

    var recovered := SaveManager.load_progress(TEST_PATH)
    SaveManager.save_game_state(
        LearningProfile.new(),
        int(recovered["coins"]),
        int(recovered["experience"]),
        TEST_PATH
    )
    equal(SaveManager.load_progress(TEST_PATH)["coins"], 210, "The rescue is now the real save")
    _remove_test_file()


func test_delete_profile_removes_the_backup_as_well() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 1, 1, TEST_PATH)
    SaveManager.save_game_state(LearningProfile.new(), 2, 2, TEST_PATH)
    SaveManager.delete_profile(TEST_PATH)

    check(not FileAccess.file_exists(TEST_PATH), "Profile removed")
    check(
        not FileAccess.file_exists(TEST_PATH + SaveManager.BACKUP_SUFFIX),
        "Backup removed, so nothing can be resurrected by accident"
    )
    equal(SaveManager.load_progress(TEST_PATH)["coins"], 0, "A deleted profile really is gone")


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
