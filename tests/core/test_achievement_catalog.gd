extends NumblopTestCase


func test_catalog_lists_first_steps_four_streaks_and_one_island_per_table() -> void:
    var definitions := AchievementCatalog.definitions()
    equal(
        definitions.size(),
        1 + AchievementCatalog.STREAK_TARGETS.size() + LearningRules.TABLES.size(),
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
    for table_value in LearningRules.TABLES:
        contains(ids, AchievementCatalog.island_id(table_value), "Island %d" % table_value)


func test_reward_values_match_the_agreed_coin_amounts() -> void:
    equal(AchievementCatalog.reward_coins(AchievementCatalog.FIRST_STEPS_ID), 100, "First steps")
    equal(AchievementCatalog.reward_coins("streak_10"), 10, "Streak 10")
    equal(AchievementCatalog.reward_coins("streak_20"), 20, "Streak 20")
    equal(AchievementCatalog.reward_coins("streak_50"), 50, "Streak 50")
    equal(AchievementCatalog.reward_coins("streak_100"), 100, "Streak 100")
    equal(AchievementCatalog.reward_coins("island_2"), 50, "Island reward")
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


func _evaluate(
    profile: LearningProfile,
    completed_sessions: int,
    best_streak: int
) -> Dictionary:
    var by_id: Dictionary = {}
    for entry in AchievementCatalog.evaluate(profile, {
        "completed_sessions": completed_sessions,
        "best_streak": best_streak,
    }):
        by_id[String(entry["id"])] = entry
    return by_id
