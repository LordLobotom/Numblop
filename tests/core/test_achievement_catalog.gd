extends NumblopTestCase


func test_catalog_lists_first_steps_streaks_xp_tiers_and_one_island_per_table() -> void:
    var definitions := AchievementCatalog.definitions()
    equal(
        definitions.size(),
        (
            1
            + AchievementCatalog.STREAK_TARGETS.size()
            + AchievementCatalog.EXPERIENCE_TARGETS.size()
            + AchievementCatalog.COLLECTION_TARGETS.size()
            + LearningRules.TABLES.size()
        ),
        "Catalog size"
    )
    var ids: Array[String] = []
    for definition in definitions:
        check(not ids.has(String(definition["id"])), "Achievement ids are unique")
        ids.append(String(definition["id"]))
        check(not String(definition["title_key"]).is_empty(), "Title key")
        check(not String(definition["description_key"]).is_empty(), "Description key")
        check(int(definition["reward_coins"]) > 0, "Reward is worth claiming")
    contains(ids, AchievementCatalog.FIRST_STEPS_ID, "First steps achievement")
    for target in AchievementCatalog.STREAK_TARGETS:
        contains(ids, AchievementCatalog.streak_id(target), "Streak %d achievement" % target)
    for target in AchievementCatalog.EXPERIENCE_TARGETS:
        contains(ids, AchievementCatalog.experience_id(target), "XP %d achievement" % target)
    for category in AchievementCatalog.COLLECTION_TARGETS:
        contains(
            ids,
            AchievementCatalog.collection_id(String(category)),
            "%s collection achievement" % category
        )
    for table_value in LearningRules.TABLES:
        contains(ids, AchievementCatalog.island_id(table_value), "Island %d" % table_value)


func test_reward_values_match_the_agreed_coin_amounts() -> void:
    equal(AchievementCatalog.reward_coins(AchievementCatalog.FIRST_STEPS_ID), 100, "First steps")
    equal(AchievementCatalog.reward_coins("streak_10"), 10, "Streak 10")
    equal(AchievementCatalog.reward_coins("streak_20"), 20, "Streak 20")
    equal(AchievementCatalog.reward_coins("streak_50"), 50, "Streak 50")
    equal(AchievementCatalog.reward_coins("streak_100"), 100, "Streak 100")
    equal(AchievementCatalog.reward_coins("island_2"), 50, "Island reward")
    for target in AchievementCatalog.EXPERIENCE_TARGETS:
        equal(
            AchievementCatalog.reward_coins(AchievementCatalog.experience_id(target)),
            50,
            "XP %d pays 50 coins" % target
        )
    for category in AchievementCatalog.COLLECTION_TARGETS:
        equal(
            AchievementCatalog.reward_coins(AchievementCatalog.collection_id(String(category))),
            50,
            "%s collection pays 50 coins" % category
        )
    equal(AchievementCatalog.reward_coins("unknown"), 0, "Unknown achievement pays nothing")


func test_streak_and_first_round_progress_track_the_player_statistics() -> void:
    var evaluated := _evaluate(LearningProfile.new(), 0, 0)
    equal(int(evaluated[AchievementCatalog.FIRST_STEPS_ID]["progress"]), 0, "No round yet")
    check(not bool(evaluated[AchievementCatalog.FIRST_STEPS_ID]["completed"]), "Not completed")

    evaluated = _evaluate(LearningProfile.new(), 1, 23)
    check(bool(evaluated[AchievementCatalog.FIRST_STEPS_ID]["completed"]), "First round done")
    check(bool(evaluated["streak_10"]["completed"]), "Streak 10 reached")
    check(bool(evaluated["streak_20"]["completed"]), "Streak 20 reached")
    check(not bool(evaluated["streak_50"]["completed"]), "Streak 50 still open")
    equal(int(evaluated["streak_50"]["progress"]), 23, "Partial streak progress")
    equal(int(evaluated["streak_50"]["target"]), 50, "Streak target")


func test_island_completes_only_when_every_fact_reaches_full_mastery() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 100)
    profile.set_mastery(2, 5, 99)

    var evaluated := _evaluate(profile, 4, 0)
    equal(int(evaluated["island_2"]["target"]), LearningRules.MULTIPLIERS.size(), "Island target")
    equal(int(evaluated["island_2"]["progress"]), 9, "Nine of ten facts fully mastered")
    check(not bool(evaluated["island_2"]["completed"]), "99 is not full mastery")

    profile.set_mastery(2, 5, 100)
    evaluated = _evaluate(profile, 4, 0)
    check(bool(evaluated["island_2"]["completed"]), "Island completes at full mastery")
    check(not bool(evaluated["island_3"]["completed"]), "Other islands stay open")


func test_progress_never_reports_more_than_the_target() -> void:
    var evaluated := _evaluate(LearningProfile.new(), 40, 500)
    equal(int(evaluated["streak_10"]["progress"]), 10, "Streak progress is capped")
    equal(int(evaluated[AchievementCatalog.FIRST_STEPS_ID]["progress"]), 1, "Rounds are capped")


func test_experience_tiers_track_the_lifetime_correct_answer_count() -> void:
    var evaluated := _evaluate(LearningProfile.new(), 3, 0, 500)
    check(bool(evaluated["experience_100"]["completed"]), "100 XP reached")
    check(bool(evaluated["experience_500"]["completed"]), "500 XP reached exactly")
    check(not bool(evaluated["experience_1000"]["completed"]), "1000 XP still open")
    equal(int(evaluated["experience_1000"]["progress"]), 500, "Partial XP progress")
    equal(int(evaluated["experience_10000"]["target"]), 10000, "Highest XP target")

    evaluated = _evaluate(LearningProfile.new(), 0, 0, 0)
    check(not bool(evaluated["experience_100"]["completed"]), "No XP yet")
    equal(int(evaluated["experience_100"]["progress"]), 0, "No XP progress")


func test_a_collection_completes_only_when_every_paid_item_is_owned() -> void:
    var hat_target := int(AchievementCatalog.COLLECTION_TARGETS["hat"])
    var evaluated := _evaluate(LearningProfile.new(), 4, 0, 0, {"hat": hat_target - 1})
    equal(int(evaluated["collection_hat"]["target"]), hat_target, "Hat collection target")
    equal(int(evaluated["collection_hat"]["progress"]), hat_target - 1, "One hat missing")
    check(not bool(evaluated["collection_hat"]["completed"]), "Almost is not a collection")
    check(not bool(evaluated["collection_glasses"]["completed"]), "Other collections stay open")

    evaluated = _evaluate(LearningProfile.new(), 4, 0, 0, {"hat": hat_target})
    check(bool(evaluated["collection_hat"]["completed"]), "Every hat owned completes it")


func test_a_profile_without_purchases_starts_every_collection_at_zero() -> void:
    var evaluated := _evaluate(LearningProfile.new(), 0, 0)
    for category in AchievementCatalog.COLLECTION_TARGETS:
        var entry: Dictionary = evaluated[AchievementCatalog.collection_id(String(category))]
        equal(int(entry["progress"]), 0, "%s starts empty" % category)
        check(not bool(entry["completed"]), "%s is not completed" % category)


func _evaluate(
    profile: LearningProfile,
    completed_sessions: int,
    best_streak: int,
    experience: int = 0,
    owned_cosmetics: Dictionary = {}
) -> Dictionary:
    var by_id: Dictionary = {}
    for entry in AchievementCatalog.evaluate(profile, {
        "completed_sessions": completed_sessions,
        "best_streak": best_streak,
        "experience": experience,
        "owned_cosmetics": owned_cosmetics,
    }):
        by_id[String(entry["id"])] = entry
    return by_id
