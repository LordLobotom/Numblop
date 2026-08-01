extends NumblopTestCase

const TEST_PATH := "user://numblop_progression_test.json"


func test_progression_round_trip_keeps_coins_experience_and_level() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    equal(SaveManager.save_game_state(profile, 37, 245, TEST_PATH), OK, "State save")
    var loaded := LocalProgress.new(SaveManager.load_progress(TEST_PATH))

    equal(loaded.coins, 37, "Saved coins")
    equal(loaded.experience, 245, "Saved experience")
    equal(loaded.level(), 3, "Derived level")
    _remove_test_file()


func test_legacy_profile_loads_with_safe_progress_defaults() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    profile.set_mastery(2, 3, 42)
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(profile.to_dictionary()))
    file = null

    var loaded_profile := SaveManager.load_profile(TEST_PATH)
    var loaded_progress := SaveManager.load_progress(TEST_PATH)
    equal(loaded_profile.get_mastery(2, 3), 42, "Legacy mastery")
    equal(loaded_progress["coins"], 0, "Legacy coins")
    equal(loaded_progress["experience"], 0, "Legacy experience")
    _remove_test_file()


func test_completed_session_reward_is_fixed_atomic_and_applied_once() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    var progress := LocalProgress.new()
    var result := _completed_result()
    var reward := progress.apply_completed_session(result, profile, _save_test_state)

    equal(reward["coins"], 10, "Reward coins")
    equal(reward["experience"], 10, "Reward experience")
    equal(progress.coins, 10, "Coin total")
    equal(progress.experience, 10, "Experience total")
    equal(progress.level(), 1, "Initial level band")
    equal(
        progress.apply_completed_session(result, profile, _save_test_state),
        {},
        "The same session cannot pay twice"
    )
    var saved := SaveManager.load_progress(TEST_PATH)
    equal(saved["coins"], 10, "Atomically saved coins")
    equal(saved["experience"], 10, "Atomically saved experience")
    _remove_test_file()


func test_abandoned_session_never_changes_progression() -> void:
    var profile := LearningProfile.new()
    var progress := LocalProgress.new({"coins": 5, "experience": 90})
    var result := SessionResult.new(_questions())
    result.record_answer(result.current_question().answer(), 1.0, 0)
    result.abandon()

    equal(progress.apply_completed_session(result, profile, Callable()), {}, "No reward")
    equal(progress.coins, 5, "Coins unchanged")
    equal(progress.experience, 90, "Experience unchanged")


func test_level_advances_at_each_hundred_experience() -> void:
    var progress := LocalProgress.new({"experience": 99})
    equal(progress.level(), 1, "Level before threshold")
    var reward := progress.apply_completed_session(
        _completed_result(),
        LearningProfile.new(),
        Callable()
    )
    equal(reward["level"], 2, "Reward crosses level threshold")
    equal(progress.experience, 109, "Experience after reward")


func test_map_stage_state_exposes_progress_without_changing_learning_rules() -> void:
    var original_profile := AppState.profile
    var map_profile := LearningProfile.new()
    AppState.profile = map_profile

    var initial_states := AppState.map_stage_states()
    equal(initial_states.size(), LearningRules.TABLES.size(), "Every table has a stage")
    check(initial_states[0]["current"], "The two-times table starts current")
    check(not initial_states[1]["unlocked"], "The next table starts locked")

    for multiplier in LearningRules.MULTIPLIERS:
        map_profile.set_mastery(2, multiplier, LearningRules.UNLOCK_MASTERY)
    var advanced_states := AppState.map_stage_states()
    check(advanced_states[0]["completed"], "Unlocked trail is complete")
    equal(advanced_states[0]["mastered_facts"], 10, "Completed fact count")
    check(advanced_states[1]["current"], "The three-times table becomes current")

    AppState.profile = original_profile


func _completed_result() -> SessionResult:
    var result := SessionResult.new(_questions())
    for index in LearningRules.SESSION_LENGTH:
        var question := result.current_question()
        var submitted := question.answer() if index % 2 == 0 else -1
        result.record_answer(submitted, 5.0, 0)
    return result


func _questions() -> Array[PracticeQuestion]:
    var questions: Array[PracticeQuestion] = []
    for multiplier in LearningRules.MULTIPLIERS:
        questions.append(
            PracticeQuestion.new(
                2,
                multiplier,
                LearningRules.QuestionMode.CHOICE_FOUR,
                [0, 2, 4, 6]
            )
        )
    return questions


func _save_test_state(profile: LearningProfile, coins: int, experience: int) -> Error:
    return SaveManager.save_game_state(profile, coins, experience, TEST_PATH)


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
