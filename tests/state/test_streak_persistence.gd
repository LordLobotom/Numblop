extends NumblopTestCase

const TEST_PATH := "user://numblop_streak_test.json"


func test_streak_continues_across_arbitrary_round_boundaries() -> void:
    var streak := LocalStreak.new()
    for _index in 10:
        streak.record_answer(true)
    for _index in 7:
        streak.record_answer(true)

    equal(streak.current_count, 17, "Correct answers continue across rounds")
    equal(streak.all_time_high, 0, "Active streak is recorded only when interrupted")
    equal(streak.milestones, [], "No interruption means no trophy milestone")
    equal(streak.best_count(), 17, "The record a player is shown counts the run in progress")


func test_the_shown_record_rises_during_the_run_that_sets_it() -> void:
    # Testers saw the trophy screen sit on the old number until they finally got one wrong.
    var streak := LocalStreak.new()
    _record_correct(streak, 3)
    streak.record_answer(false, 1000, 120)
    equal(streak.best_count(), 3, "An ended run is the record")

    _record_correct(streak, 2)
    equal(streak.best_count(), 3, "A shorter run in progress does not lower the record")
    _record_correct(streak, 2)
    equal(streak.best_count(), 4, "Passing the old high counts immediately")
    equal(streak.all_time_high, 3, "The milestone gate still waits for the mistake")


func test_the_shown_record_survives_a_restart_mid_run() -> void:
    _remove_test_file()
    var streak := LocalStreak.new()
    _record_correct(streak, 9)
    equal(
        SaveManager.save_game_state(
            LearningProfile.new(), 0, 0, TEST_PATH, {}, streak.to_dictionary()
        ),
        OK,
        "Streak save"
    )
    var loaded := LocalStreak.new(SaveManager.load_streak(TEST_PATH))
    equal(loaded.best_count(), 9, "Closing the app mid-run does not lose the record")
    equal(loaded.all_time_high, 0, "The ended-run high is still untouched")
    _remove_test_file()


func test_only_interrupted_new_highs_create_timestamped_milestones() -> void:
    var streak := LocalStreak.new()
    _record_correct(streak, 3)
    var first := streak.record_answer(false, 1000, 120)
    equal(first["count"], 3, "First ended streak is a record")
    equal(streak.current_count, 0, "Mistake resets current streak")

    _record_correct(streak, 2)
    equal(streak.record_answer(false, 2000, 120), {}, "Lower streak is not recorded")
    equal(streak.milestones.size(), 1, "Lower streak does not add a trophy row")

    _record_correct(streak, 5)
    var second := streak.record_answer(false, 3000, 60)
    equal(second["count"], 5, "Later higher streak is recorded")
    equal(second["ended_at_unix"], 3000, "Interruption time is retained")
    equal(second["utc_offset_minutes"], 60, "Local time offset is retained")
    equal(streak.all_time_high, 5, "Ended all-time high")
    equal(streak.milestones.size(), 2, "Increasing record history")


func test_active_streak_and_record_history_round_trip_with_the_profile() -> void:
    _remove_test_file()
    var streak := LocalStreak.new()
    _record_correct(streak, 4)
    streak.record_answer(false, 123456, 120)
    _record_correct(streak, 6)

    equal(
        SaveManager.save_game_state(
            LearningProfile.new(),
            12,
            34,
            TEST_PATH,
            {},
            streak.to_dictionary()
        ),
        OK,
        "Streak save"
    )
    var loaded := LocalStreak.new(SaveManager.load_streak(TEST_PATH))
    equal(loaded.current_count, 6, "Active streak survives restart")
    equal(loaded.all_time_high, 4, "Ended high survives restart")
    equal(loaded.milestones.size(), 1, "Milestone history survives restart")
    equal(loaded.milestones[0]["ended_at_unix"], 123456, "Milestone time survives")

    var updated_profile := LearningProfile.new()
    updated_profile.set_mastery(2, 3, 25)
    equal(SaveManager.save_profile(updated_profile, TEST_PATH), OK, "Mastery-only save")
    loaded = LocalStreak.new(SaveManager.load_streak(TEST_PATH))
    equal(loaded.current_count, 6, "Per-answer mastery save preserves active streak")
    equal(loaded.milestones.size(), 1, "Per-answer mastery save preserves records")
    _remove_test_file()


func test_legacy_save_receives_an_empty_streak() -> void:
    _remove_test_file()
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(LearningProfile.new().to_dictionary()))
    file = null

    var loaded := LocalStreak.new(SaveManager.load_streak(TEST_PATH))
    equal(loaded.current_count, 0, "Legacy current streak")
    equal(loaded.all_time_high, 0, "Legacy all-time high")
    equal(loaded.milestones, [], "Legacy milestone history")
    _remove_test_file()


func _record_correct(streak: LocalStreak, count: int) -> void:
    for _index in count:
        streak.record_answer(true)


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
