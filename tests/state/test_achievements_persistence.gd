extends NumblopTestCase

const TEST_PATH := "user://numblop_achievements_test.json"


func test_a_reward_is_only_ever_granted_once() -> void:
    var achievements := LocalAchievements.new()
    equal(achievements.grant("streak_10"), 10, "First grant pays the reward")
    equal(achievements.grant("streak_10"), 0, "Second grant pays nothing")
    check(achievements.has_granted("streak_10"), "Grant is recorded")
    equal(achievements.granted.size(), 1, "No duplicate entries")


func test_unknown_and_corrupt_entries_are_dropped_on_load() -> void:
    var achievements := LocalAchievements.new({
        "granted": ["streak_10", "streak_10", "not_an_achievement", 7],
    })
    equal(achievements.granted, ["streak_10"], "Only known unique ids survive")
    equal(LocalAchievements.new({"granted": "broken"}).granted, [], "Corrupt list falls back")
    equal(achievements.grant("not_an_achievement"), 0, "Unknown achievement pays nothing")


func test_granted_achievements_survive_a_save_and_reload() -> void:
    _remove_test_file()
    var achievements := LocalAchievements.new()
    achievements.grant(AchievementCatalog.FIRST_STEPS_ID)
    achievements.grant("island_2")
    equal(
        SaveManager.save_game_state(
            LearningProfile.new(),
            300,
            120,
            TEST_PATH,
            {},
            {},
            null,
            achievements.to_dictionary(),
            6
        ),
        OK,
        "Achievement save"
    )

    var loaded := LocalAchievements.new(SaveManager.load_achievements(TEST_PATH))
    check(loaded.has_granted(AchievementCatalog.FIRST_STEPS_ID), "First steps stays granted")
    check(loaded.has_granted("island_2"), "Island stays granted")
    equal(loaded.grant("island_2"), 0, "Reloaded grants cannot be claimed again")
    equal(int(SaveManager.load_progress(TEST_PATH)["completed_sessions"]), 6, "Session counter")
    _remove_test_file()


func test_a_mastery_only_save_preserves_granted_achievements() -> void:
    _remove_test_file()
    var achievements := LocalAchievements.new()
    achievements.grant("streak_20")
    SaveManager.save_game_state(
        LearningProfile.new(),
        10,
        10,
        TEST_PATH,
        {},
        {},
        null,
        achievements.to_dictionary(),
        3
    )

    var profile := LearningProfile.new()
    profile.set_mastery(2, 3, 40)
    equal(SaveManager.save_profile(profile, TEST_PATH), OK, "Mastery-only save")

    var reloaded := LocalAchievements.new(SaveManager.load_achievements(TEST_PATH))
    check(reloaded.has_granted("streak_20"), "Streak 20 survives a profile save")
    equal(int(SaveManager.load_progress(TEST_PATH)["completed_sessions"]), 3, "Counter survives")
    _remove_test_file()


func test_legacy_save_infers_a_finished_round_from_earned_experience() -> void:
    _remove_test_file()
    var legacy := LearningProfile.new().to_dictionary()
    legacy["coins"] = 42
    legacy["experience"] = 42
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file = null

    var progress := LocalProgress.new(SaveManager.load_progress(TEST_PATH))
    equal(progress.completed_sessions, 1, "Experience proves a finished round")
    equal(
        LocalAchievements.new(SaveManager.load_achievements(TEST_PATH)).granted,
        [],
        "Legacy save has granted nothing yet"
    )

    var evaluated := AchievementCatalog.evaluate(LearningProfile.new(), {
        "completed_sessions": progress.completed_sessions,
        "best_streak": 0,
    })
    for entry in evaluated:
        if String(entry["id"]) == AchievementCatalog.FIRST_STEPS_ID:
            check(bool(entry["completed"]), "First steps is earned retroactively")
    _remove_test_file()


func test_a_fresh_save_reports_no_finished_rounds() -> void:
    _remove_test_file()
    var progress := LocalProgress.new(SaveManager.load_progress(TEST_PATH))
    equal(progress.completed_sessions, 0, "No rounds without a save")
    equal(progress.coins, 0, "No coins without a save")
    _remove_test_file()


func test_collection_targets_match_the_paid_items_in_the_cosmetics_catalog() -> void:
    for category in AchievementCatalog.COLLECTION_TARGETS:
        var category_name := String(category)
        var paid_items := 0
        for item in CosmeticCatalog.items(category_name):
            if int(item["price"]) > 0:
                paid_items += 1
        check(paid_items > 0, "%s is a real cosmetic category" % category_name)
        equal(
            int(AchievementCatalog.COLLECTION_TARGETS[category]),
            paid_items,
            "%s collection target matches the shop" % category_name
        )


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
