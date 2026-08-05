extends NumblopTestCase


func test_initial_session_fills_missing_review_slots_from_current_table() -> void:
    var profile := LearningProfile.new()
    var questions := SessionGenerator.generate(profile, 12345)
    equal(questions.size(), 10, "Session length")
    for question in questions:
        equal(question.table_value, 2, "Only the current table is available")
    equal(_unique_fact_count(questions), 10, "Initial session covers all ten facts once")
    _check_no_immediate_duplicates(questions)


func test_session_uses_seven_two_one_mix_when_review_pools_exist() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 80)
    # Only a saturated fact counts as automated: 95 is answered by typing but still needs
    # practice, so it belongs to the weak pool.
    profile.set_mastery(2, 0, 100)
    profile.set_mastery(2, 1, 100)

    var questions := SessionGenerator.generate(profile, 777)
    var counts := _mix_counts(profile, questions, 3)
    equal(questions.size(), 10, "Tables below the sixth keep the ten-question round")
    equal(counts["current"], 7, "Current table quota")
    equal(counts["weak"], 2, "Older weak quota")
    equal(counts["automated"], 1, "Automated review quota")
    equal(_unique_fact_count(questions), 10, "Available review facts remain unique")
    _check_no_immediate_duplicates(questions)


func test_a_fact_short_of_saturation_stays_in_the_weak_pool() -> void:
    # The line between "keep practising this" and "just keep it warm" is saturation, not the
    # 90 at which the question switches to typed input.
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 95)

    var questions := SessionGenerator.generate(profile, 31337)
    var counts := _mix_counts(profile, questions, 3)
    equal(counts["automated"], 0, "Nothing is automated until a fact reaches 100")
    equal(counts["weak"], 2, "Facts at 95 still fill the weak review slots")


func test_the_sixth_table_moves_to_an_eight_three_one_mix() -> void:
    var profile := _profile_learning_the_sixth_table()
    var questions := SessionGenerator.generate(profile, 606)
    var counts := _mix_counts(profile, questions, 6)

    equal(questions.size(), LearningRules.EXTENDED_SESSION_LENGTH, "Round grows to twelve")
    equal(counts["current"], 8, "Current table quota")
    equal(counts["weak"], 3, "Older weak quota")
    equal(counts["automated"], 1, "Automated review quota")
    _check_no_immediate_duplicates(questions)


func test_the_automated_slot_takes_the_longest_waiting_fact() -> void:
    # The whole point of the slot is that saturated facts are cycled rather than sampled, so
    # nothing sits untouched for weeks just because the rng never picked it.
    var profile := _profile_learning_the_sixth_table()
    var stamp := 1_000
    for table_value in [2, 3, 4, 5]:
        for multiplier in LearningRules.MULTIPLIERS:
            profile.mark_practiced(table_value, multiplier, stamp)
            stamp += 1
    profile.mark_practiced(3, 7, 1)

    # Seed-independent: one fact has waited strictly longest, so there is nothing to break.
    for seed in [1, 2, 99, 20260805]:
        var questions := SessionGenerator.generate(profile, seed)
        equal(
            _automated_question_key(profile, questions),
            LearningRules.fact_key(3, 7),
            "The most neglected fact is the one reviewed (seed %d)" % seed
        )


func test_reviewing_a_fact_hands_the_slot_to_the_next_most_neglected() -> void:
    var profile := _profile_learning_the_sixth_table()
    var stamp := 1_000
    for table_value in [2, 3, 4, 5]:
        for multiplier in LearningRules.MULTIPLIERS:
            profile.mark_practiced(table_value, multiplier, stamp)
            stamp += 1
    profile.mark_practiced(3, 7, 1)
    profile.mark_practiced(4, 2, 2)

    equal(
        _automated_question_key(profile, SessionGenerator.generate(profile, 5)),
        LearningRules.fact_key(3, 7),
        "The oldest goes first"
    )
    # Practising it moves it to the back of the queue rather than merely off the front.
    profile.mark_practiced(3, 7, stamp)
    equal(
        _automated_question_key(profile, SessionGenerator.generate(profile, 5)),
        LearningRules.fact_key(4, 2),
        "The next oldest follows"
    )


func test_a_fact_repeats_only_when_its_required_review_pool_is_exhausted() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 80)
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 100)
    profile.set_mastery(2, 9, 80)

    var questions := SessionGenerator.generate(profile, 4242)
    var weak_review_count := 0
    for question in questions:
        if question.fact_key() == LearningRules.fact_key(2, 9):
            weak_review_count += 1

    equal(weak_review_count, 2, "The sole weak review fact fills both required weak slots")
    _check_no_immediate_duplicates(questions)


func test_two_equally_weak_facts_do_not_alternate_for_the_whole_session() -> void:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 0 if multiplier < 2 else 50)

    var questions := SessionGenerator.generate(profile, 20260802)

    equal(_unique_fact_count(questions), 10, "Unused facts win before any fact repeats")
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


## Tables 2 to 5 finished, so the sixth is current, with both review pools stocked: most of
## the history saturated, four facts left short of it to feed the weak slots.
func _profile_learning_the_sixth_table() -> LearningProfile:
    var profile := LearningProfile.new()
    for table_value in [2, 3, 4, 5]:
        for multiplier in LearningRules.MULTIPLIERS:
            profile.set_mastery(table_value, multiplier, 100)
    for multiplier in [3, 4, 5, 6]:
        profile.set_mastery(5, multiplier, 85)
    return profile


func _mix_counts(
    profile: LearningProfile,
    questions: Array[PracticeQuestion],
    current_table: int
) -> Dictionary:
    var counts := {"current": 0, "weak": 0, "automated": 0}
    for question in questions:
        if question.table_value == current_table:
            counts["current"] += 1
        elif (
            profile.get_mastery(question.table_value, question.multiplier)
            >= LearningRules.REVIEW_MASTERY
        ):
            counts["automated"] += 1
        else:
            counts["weak"] += 1
    return counts


func _automated_question_key(
    profile: LearningProfile,
    questions: Array[PracticeQuestion]
) -> String:
    for question in questions:
        if question.table_value == profile.current_table():
            continue
        if (
            profile.get_mastery(question.table_value, question.multiplier)
            >= LearningRules.REVIEW_MASTERY
        ):
            return question.fact_key()
    return ""


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


func _unique_fact_count(questions: Array[PracticeQuestion]) -> int:
    var unique: Dictionary = {}
    for question in questions:
        unique[question.fact_key()] = true
    return unique.size()
