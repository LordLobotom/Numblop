extends NumblopTestCase


func test_session_records_a_complete_per_answer_audit() -> void:
    var session := SessionResult.new(_questions())
    var question := session.current_question()
    var record := session.record_answer(question.answer(), 2.4, 58)

    equal(record.question_index, 0, "Question index")
    equal(record.fact_key, question.fact_key(), "Fact key")
    equal(record.table_value, question.table_value, "Table value")
    equal(record.multiplier, question.multiplier, "Multiplier")
    equal(record.mode, LearningRules.QuestionMode.CHOICE_FOUR, "Presented mode")
    equal(record.submitted_answer, question.answer(), "Submitted answer")
    equal(record.correct_answer, question.answer(), "Correct answer")
    equal(record.correct, true, "Correctness")
    equal(record.elapsed_seconds, 2.4, "Elapsed time")
    equal(record.mastery_before, 58, "Mastery before")
    equal(record.mastery_delta, 5, "Mastery delta")
    equal(record.mastery_after, 63, "Mastery after")


func test_session_advances_in_order_and_uses_the_presented_mode_for_scoring() -> void:
    var questions := _questions()
    questions[0] = PracticeQuestion.new(2, 2, LearningRules.QuestionMode.CHOICE_SIX, [2, 4, 6, 8, 10, 12])
    var session := SessionResult.new(questions)

    var record := session.record_answer(4, 2.75, 59)

    equal(record.mastery_delta, 5, "The six-choice fast limit applies")
    equal(session.current_question().fact_key(), questions[1].fact_key(), "Next question")
    equal(session.answered_count(), 1, "Answered count")


func test_incorrect_answer_is_audited_and_clamped_without_blocking_completion() -> void:
    var session := SessionResult.new(_questions())
    var first := session.record_answer(-1, -0.5, 1)

    equal(first.correct, false, "Incorrect answer")
    equal(first.elapsed_seconds, 0.0, "Negative elapsed time is clamped")
    equal(first.mastery_delta, -2, "Incorrect delta")
    equal(first.mastery_after, 0, "Mastery lower bound")

    for index in range(1, LearningRules.SESSION_LENGTH):
        var question := session.current_question()
        session.record_answer(question.answer(), 10.0, 50)

    equal(session.is_complete(), true, "Ten answers complete the session")
    equal(session.can_receive_reward(), true, "Accuracy does not gate the reward")
    equal(session.answered_count(), 10, "Complete answer count")
    equal(session.correct_count(), 9, "Correct count")
    equal(session.current_question(), null, "No question remains")


func test_abandoned_session_cannot_complete_or_receive_a_reward() -> void:
    var session := SessionResult.new(_questions())
    var question := session.current_question()
    session.record_answer(question.answer(), 1.0, 0)
    session.abandon()

    equal(session.status, SessionResult.Status.ABANDONED, "Abandoned status")
    equal(session.is_complete(), false, "Abandoned session is incomplete")
    equal(session.can_receive_reward(), false, "No interrupted reward")
    equal(session.current_question(), null, "Abandoned session has no current question")
    equal(session.answered_count(), 1, "Processed audit records remain available")


func test_audit_record_has_a_plain_dictionary_projection() -> void:
    var session := SessionResult.new(_questions())
    var record := session.record_answer(session.current_question().answer(), 1.25, 99)
    var data := record.to_dictionary()

    equal(data["fact_key"], record.fact_key, "Dictionary fact key")
    equal(data["mastery_after"], 100, "Mastery upper bound")
    equal(data["correct"], true, "Dictionary correctness")


func _questions() -> Array[PracticeQuestion]:
    var questions: Array[PracticeQuestion] = []
    for multiplier in LearningRules.MULTIPLIERS:
        questions.append(
            PracticeQuestion.new(
                2,
                multiplier,
                LearningRules.QuestionMode.CHOICE_FOUR,
                [multiplier * 2, multiplier * 2 + 1, multiplier * 2 + 2, multiplier * 2 + 3]
            )
        )
    return questions
