extends NumblopTestCase


func test_profile_starts_with_all_eighty_facts() -> void:
    var profile := LearningProfile.new()
    equal(profile.mastery.size(), 80, "Fact count")
    equal(profile.current_table(), 2, "Initial table")
    equal(profile.mastered_fact_count(), 0, "Initial mastered facts")


func test_question_mode_boundaries_are_exact() -> void:
    equal(LearningRules.mode_for_mastery(0), LearningRules.QuestionMode.CHOICE_FOUR)
    equal(LearningRules.mode_for_mastery(59), LearningRules.QuestionMode.CHOICE_FOUR)
    equal(LearningRules.mode_for_mastery(60), LearningRules.QuestionMode.CHOICE_SIX)
    equal(LearningRules.mode_for_mastery(89), LearningRules.QuestionMode.CHOICE_SIX)
    equal(LearningRules.mode_for_mastery(90), LearningRules.QuestionMode.NUMBER_INPUT)
    equal(LearningRules.mode_for_mastery(100), LearningRules.QuestionMode.NUMBER_INPUT)


func test_answer_scoring_uses_speed_without_a_countdown() -> void:
    equal(LearningRules.mastery_delta(true, 2.5, LearningRules.QuestionMode.CHOICE_FOUR), 5)
    equal(LearningRules.mastery_delta(true, 2.51, LearningRules.QuestionMode.CHOICE_FOUR), 3)
    equal(LearningRules.mastery_delta(true, 3.0, LearningRules.QuestionMode.CHOICE_SIX), 5)
    equal(LearningRules.mastery_delta(true, 4.01, LearningRules.QuestionMode.NUMBER_INPUT), 3)
    equal(LearningRules.mastery_delta(false, 0.1, LearningRules.QuestionMode.CHOICE_FOUR), -2)


func test_nine_ready_facts_unlock_and_tables_never_relock() -> void:
    var profile := LearningProfile.new()
    for multiplier in range(LearningRules.REQUIRED_FACTS_TO_UNLOCK - 1):
        profile.set_mastery(2, multiplier, 80)
    equal(profile.current_table(), 2, "Eight ready facts keep table 3 locked")
    profile.set_mastery(2, LearningRules.REQUIRED_FACTS_TO_UNLOCK - 1, 80)
    equal(profile.current_table(), 3, "Table 3 should unlock")
    profile.set_mastery(2, 4, 0)
    equal(profile.current_table(), 3, "An unlocked table must stay unlocked")


func test_mastery_is_clamped() -> void:
    var profile := LearningProfile.new()
    profile.set_mastery(2, 2, 120)
    equal(profile.get_mastery(2, 2), 100)
    profile.set_mastery(2, 2, -8)
    equal(profile.get_mastery(2, 2), 0)


func test_last_practiced_survives_a_save_and_defaults_to_never() -> void:
    var profile := LearningProfile.new()
    equal(profile.get_last_practiced(2, 3), 0, "A fresh profile has practised nothing")
    profile.mark_practiced(2, 3, 1_754_400_000)
    profile.set_mastery(2, 3, 100)

    var restored := LearningProfile.from_dictionary(profile.to_dictionary())
    equal(restored.get_last_practiced(2, 3), 1_754_400_000, "Timestamp round-trips")
    equal(restored.get_last_practiced(2, 4), 0, "Untouched facts stay at never")


func test_a_version_one_save_loads_with_no_practice_history() -> void:
    # Saves written before review scheduling existed carry no timestamps. Zero is the honest
    # answer -- nothing is known about those facts, so the review slot should visit them first.
    var legacy := {
        "version": 1,
        "highest_unlocked_index": 1,
        "mastery": {LearningRules.fact_key(2, 3): 100},
    }
    var profile := LearningProfile.from_dictionary(legacy)
    equal(profile.get_mastery(2, 3), 100, "Mastery still loads")
    equal(profile.get_last_practiced(2, 3), 0, "Missing timestamps read as never")


func test_the_session_length_grows_from_the_sixth_table() -> void:
    for table_value in [2, 3, 4, 5]:
        equal(LearningRules.session_length(table_value), 10, "Table %d" % table_value)
        check(not LearningRules.uses_extended_mix(table_value), "Table %d is short" % table_value)
    for table_value in [6, 7, 8, 9]:
        equal(LearningRules.session_length(table_value), 12, "Table %d" % table_value)
        check(LearningRules.uses_extended_mix(table_value), "Table %d is long" % table_value)


func test_final_table_completion_is_permanent_and_practice_eligible() -> void:
    var profile := LearningProfile.new()
    for table_value in LearningRules.TABLES:
        for multiplier in range(LearningRules.REQUIRED_FACTS_TO_UNLOCK):
            profile.set_mastery(table_value, multiplier, LearningRules.UNLOCK_MASTERY)

    check(profile.final_table_completed, "Final table completion is remembered")
    check(profile.is_table_practice_eligible(9), "Completed 9x is practice eligible")
    profile.set_mastery(9, 0, 0)
    check(profile.final_table_completed, "Later mastery loss cannot undo completion")
    check(profile.is_table_practice_eligible(9), "Practice eligibility remains permanent")


func test_only_permanently_completed_tables_are_practice_eligible() -> void:
    var profile := LearningProfile.new()
    check(not profile.is_table_practice_eligible(2), "Current unfinished table is not eligible")
    for multiplier in range(LearningRules.REQUIRED_FACTS_TO_UNLOCK):
        profile.set_mastery(2, multiplier, LearningRules.UNLOCK_MASTERY)
    check(profile.is_table_practice_eligible(2), "Passed table is eligible")
    check(not profile.is_table_practice_eligible(3), "New current table is not yet eligible")
