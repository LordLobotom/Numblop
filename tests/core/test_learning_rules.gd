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
