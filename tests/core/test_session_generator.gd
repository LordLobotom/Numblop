extends NumblopTestCase


func test_initial_session_fills_missing_review_slots_from_current_table() -> void:
    var profile := LearningProfile.new()
    var questions := SessionGenerator.generate(profile, 12345)
    equal(questions.size(), 10, "Session length")
    for question in questions:
        equal(question.table_value, 2, "Only the current table is available")
    _check_no_immediate_duplicates(questions)


func test_session_uses_seven_two_one_mix_when_review_pools_exist() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 80)
    profile.set_mastery(2, 0, 95)
    profile.set_mastery(2, 1, 95)

    var questions := SessionGenerator.generate(profile, 777)
    var current_count := 0
    var weak_count := 0
    var automated_count := 0
    for question in questions:
        if question.table_value == 3:
            current_count += 1
        elif profile.get_mastery(question.table_value, question.multiplier) >= 90:
            automated_count += 1
        else:
            weak_count += 1
    equal(current_count, 7, "Current table quota")
    equal(weak_count, 2, "Older weak quota")
    equal(automated_count, 1, "Automated review quota")
    _check_no_immediate_duplicates(questions)


func test_generation_is_deterministic_for_a_seed() -> void:
    var profile := LearningProfile.new()
    var first := SessionGenerator.generate(profile, 99)
    var second := SessionGenerator.generate(profile, 99)
    equal(_signature(first), _signature(second), "Seeded sessions")


func test_choices_are_unique_and_include_the_answer() -> void:
    var profile := LearningProfile.new()
    profile.set_mastery(2, 0, 60)
    var questions := SessionGenerator.generate(profile, 4321)
    for question in questions:
        var expected_size := (
            4 if question.mode == LearningRules.QuestionMode.CHOICE_FOUR else 6
        )
        equal(question.choices.size(), expected_size, "Choice count")
        equal(_unique_count(question.choices), expected_size, "Choices must be unique")
        contains(question.choices, question.answer(), "Correct answer")


func _check_no_immediate_duplicates(questions: Array[PracticeQuestion]) -> void:
    for index in range(1, questions.size()):
        check(
            questions[index - 1].fact_key() != questions[index].fact_key(),
            "Immediate duplicate at question %d" % index
        )


func _signature(questions: Array[PracticeQuestion]) -> String:
    var parts: Array[String] = []
    for question in questions:
        parts.append("%s:%s" % [question.fact_key(), question.choices])
    return "|".join(parts)


func _unique_count(values: Array[int]) -> int:
    var unique: Dictionary = {}
    for value in values:
        unique[value] = true
    return unique.size()
