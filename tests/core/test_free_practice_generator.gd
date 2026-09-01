extends NumblopTestCase


func test_explicit_tables_are_balanced_and_exclusive() -> void:
    var profile := _completed_profile([2, 3, 4])
    var questions := FreePracticeGenerator.generate(profile, [2, 3, 4], 20, 24680)
    var counts := _table_counts(questions)

    equal(questions.size(), 20, "Requested length")
    check(_count_spread(counts) <= 1, "Explicit tables differ by at most one question")
    for question in questions:
        contains([2, 3, 4], question.table_value, "Only explicitly selected tables")
    _check_no_immediate_duplicates(questions)


func test_empty_selection_uses_every_completed_table() -> void:
    var profile := _completed_profile([2, 3, 4])
    var questions := FreePracticeGenerator.generate(profile, [], 50, 13579)
    var counts := _table_counts(questions)

    equal(counts.size(), 3, "All completed tables appear")
    for table_value in [2, 3, 4]:
        check(counts.has(table_value), "Completed table %d participates" % table_value)


func test_smart_review_prioritizes_a_materially_weaker_table() -> void:
    var profile := _completed_profile([2, 3])
    for table_value in [2, 3]:
        for multiplier in LearningRules.MULTIPLIERS:
            profile.set_mastery(table_value, multiplier, 100)
    profile.set_mastery(2, 7, 0)

    var questions := FreePracticeGenerator.generate(profile, [], 30, 777)
    var fact_counts: Dictionary = {}
    for question in questions:
        fact_counts[question.fact_key()] = int(fact_counts.get(question.fact_key(), 0)) + 1
    check(
        int(fact_counts.get(LearningRules.fact_key(2, 7), 0))
        > int(fact_counts.get(LearningRules.fact_key(3, 7), 0)),
        "The materially weaker fact receives more smart-review slots"
    )
    check(_table_counts(questions).has(3), "The stronger table is not starved")


func test_smart_review_is_balanced_when_mastery_is_similar() -> void:
    var profile := _completed_profile([2, 3, 4, 5])
    for table_value in [2, 3, 4, 5]:
        for multiplier in LearningRules.MULTIPLIERS:
            profile.set_mastery(table_value, multiplier, 85)

    var counts := _table_counts(FreePracticeGenerator.generate(profile, [], 30, 888))
    check(_count_spread(counts) <= 1, "Similar tables settle into a balanced mix")


func test_free_practice_is_deterministic_and_builds_valid_questions() -> void:
    var profile := _completed_profile([2, 3])
    profile.set_mastery(2, 0, 60)
    var first := FreePracticeGenerator.generate(profile, [2, 3], 10, 4242)
    var second := FreePracticeGenerator.generate(profile, [2, 3], 10, 4242)

    equal(_signature(first), _signature(second), "Seeded free practice")
    for question in first:
        if question.mode == LearningRules.QuestionMode.NUMBER_INPUT:
            equal(question.choices, [], "Typed questions have no choices")
        else:
            contains(question.choices, question.answer(), "Choices include the answer")


func test_all_supported_free_practice_lengths_are_generated_exactly() -> void:
    var profile := _completed_profile([2])
    for question_count in LearningRules.FREE_PRACTICE_LENGTHS:
        equal(
            FreePracticeGenerator.generate(profile, [2], question_count, 99).size(),
            question_count,
            "Free-practice length %d" % question_count
        )


func _completed_profile(tables: Array[int]) -> LearningProfile:
    var profile := LearningProfile.new()
    for table_value in tables:
        for multiplier in range(LearningRules.REQUIRED_FACTS_TO_UNLOCK):
            profile.set_mastery(table_value, multiplier, LearningRules.UNLOCK_MASTERY)
    return profile


func _table_counts(questions: Array[PracticeQuestion]) -> Dictionary:
    var counts: Dictionary = {}
    for question in questions:
        counts[question.table_value] = int(counts.get(question.table_value, 0)) + 1
    return counts


func _count_spread(counts: Dictionary) -> int:
    var lowest := 1_000_000
    var highest := 0
    for count in counts.values():
        lowest = mini(lowest, int(count))
        highest = maxi(highest, int(count))
    return highest - lowest


func _check_no_immediate_duplicates(questions: Array[PracticeQuestion]) -> void:
    for index in range(1, questions.size()):
        check(
            questions[index - 1].fact_key() != questions[index].fact_key(),
            "No immediate duplicate at %d" % index
        )


func _signature(questions: Array[PracticeQuestion]) -> String:
    var parts: Array[String] = []
    for question in questions:
        parts.append("%s:%s" % [question.fact_key(), question.choices])
    return "|".join(parts)
