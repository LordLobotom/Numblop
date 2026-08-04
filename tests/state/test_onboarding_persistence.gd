extends NumblopTestCase

const TEST_PATH := "user://numblop_onboarding_test.json"


func test_new_profiles_start_with_the_tutorial_pending() -> void:
    var onboarding := LocalOnboarding.new()
    check(not onboarding.completed, "A new child has not seen the tutorial")
    equal(onboarding.step, 0, "A new child starts at the first step")


func test_corrupt_onboarding_values_fall_back_safely() -> void:
    var onboarding := LocalOnboarding.new({"completed": "yes", "step": "seven"})
    check(not onboarding.completed, "A corrupt flag never skips the tutorial")
    equal(onboarding.step, 0, "A corrupt step falls back to the sequence start")
    equal(
        LocalOnboarding.new({"step": -4}).step,
        0,
        "A negative step cannot point before the sequence start"
    )
    var rebuilt := LocalOnboarding.new(onboarding.to_dictionary())
    equal(rebuilt.to_dictionary(), onboarding.to_dictionary(), "Round trip is stable")


func test_tutorial_progress_and_completion_survive_a_restart() -> void:
    _remove_test_file()
    var onboarding := LocalOnboarding.new()
    onboarding.step = 6

    equal(
        SaveManager.save_game_state(
            LearningProfile.new(),
            10,
            20,
            TEST_PATH,
            {},
            {},
            null,
            null,
            null,
            onboarding.to_dictionary()
        ),
        OK,
        "Tutorial step save"
    )
    var resumed := LocalOnboarding.new(SaveManager.load_onboarding(TEST_PATH))
    equal(resumed.step, 6, "A restart resumes on the step the child stopped on")
    check(not resumed.completed, "An unfinished tutorial is not marked completed")

    resumed.completed = true
    equal(
        SaveManager.save_game_state(
            LearningProfile.new(),
            10,
            20,
            TEST_PATH,
            {},
            {},
            null,
            null,
            null,
            resumed.to_dictionary()
        ),
        OK,
        "Tutorial completion save"
    )
    check(
        LocalOnboarding.new(SaveManager.load_onboarding(TEST_PATH)).completed,
        "A finished tutorial never runs again"
    )
    _remove_test_file()


func test_unrelated_saves_keep_the_tutorial_state_on_disk() -> void:
    # Cosmetics, nickname and profile saves all go through the same writer; none of them
    # knows about the tutorial, so its state has to survive being left out.
    _remove_test_file()
    var onboarding := LocalOnboarding.new({"completed": true, "step": 11})
    SaveManager.save_game_state(
        LearningProfile.new(),
        0,
        0,
        TEST_PATH,
        {},
        {},
        null,
        null,
        null,
        onboarding.to_dictionary()
    )
    equal(
        SaveManager.save_profile(LearningProfile.new(), TEST_PATH),
        OK,
        "Profile-only save"
    )
    var reloaded := LocalOnboarding.new(SaveManager.load_onboarding(TEST_PATH))
    check(reloaded.completed, "A profile save does not restart the tutorial")
    equal(reloaded.step, 11, "A profile save keeps the tutorial position")
    _remove_test_file()


func test_saves_written_before_the_tutorial_existed_load_as_pending() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_PATH)
    var loaded := LocalOnboarding.new(SaveManager.load_onboarding(TEST_PATH))
    check(not loaded.completed, "A save without the field is not silently completed")
    equal(loaded.step, 0, "A save without the field starts at the first step")
    _remove_test_file()


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
