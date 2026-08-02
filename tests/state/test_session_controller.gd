extends NumblopTestCase

const TEST_PATH := "user://numblop_session_controller_test.json"


func test_controller_starts_an_exact_seeded_session() -> void:
    var profile := LearningProfile.new()
    var controller := SessionController.new(profile)
    var first := controller.begin_session(2468)
    var first_signature := _signature(first.questions)
    var second := controller.begin_session(2468)

    equal(first.questions.size(), LearningRules.SESSION_LENGTH, "Session length")
    equal(_signature(second.questions), first_signature, "Seeded questions")
    equal(first.status, SessionResult.Status.ABANDONED, "Replaced session is abandoned")
    check(controller.current_question() != null, "Current question")


func test_every_answer_updates_mastery_and_saves_immediately() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    var controller := SessionController.new(profile, _save_test_profile)
    controller.begin_session(1357)
    var question := controller.current_question()
    var record := controller.submit_answer(question.answer(), 1.0)

    equal(record.correct, true, "Correct answer")
    equal(record.mastery_before, 0, "Mastery before")
    equal(record.mastery_delta, 5, "Mastery delta")
    equal(profile.get_mastery(question.table_value, question.multiplier), 5, "Live mastery")
    check(FileAccess.file_exists(TEST_PATH), "Answer should create a save")
    var loaded := SaveManager.load_profile(TEST_PATH)
    equal(loaded.get_mastery(question.table_value, question.multiplier), 5, "Saved mastery")
    _remove_test_file()


func test_answer_event_updates_supplemental_state_before_the_atomic_save() -> void:
    var order := {"event_seen": false, "save_saw_event": false}
    var save_after_event := func(_profile: LearningProfile) -> Error:
        order["save_saw_event"] = bool(order["event_seen"])
        return OK
    var controller := SessionController.new(LearningProfile.new(), save_after_event)
    controller.answer_recorded.connect(
        func(_record: SessionResult.AnswerRecord) -> void:
            order["event_seen"] = true
    )
    controller.begin_session(24601)
    var question := controller.current_question()
    controller.submit_answer(question.answer(), 1.0)

    check(bool(order["save_saw_event"]), "Streak state can join the per-answer mastery save")


func test_answer_crossing_the_mastery_gate_unlocks_the_next_table() -> void:
    var profile := LearningProfile.new()
    var unlock_multiplier := LearningRules.REQUIRED_FACTS_TO_UNLOCK - 1
    var remaining_multiplier: int = LearningRules.MULTIPLIERS.back()
    for multiplier in LearningRules.MULTIPLIERS:
        var mastery := LearningRules.UNLOCK_MASTERY
        if multiplier == unlock_multiplier:
            mastery = 75
        elif multiplier == remaining_multiplier:
            mastery = 79
        profile.set_mastery(2, multiplier, mastery)
    var controller := SessionController.new(profile)
    var unlocks: Array[Vector2i] = []
    controller.table_unlocked.connect(
        func(completed_table: int, new_table: int) -> void:
            unlocks.append(Vector2i(completed_table, new_table))
    )
    controller.begin_session(31415)
    var question := controller.current_question()

    equal(question.table_value, 2, "Current table before unlock")
    equal(question.multiplier, unlock_multiplier, "Lowest-mastery fact is selected")
    controller.submit_answer(question.answer(), 1.0)

    equal(profile.get_mastery(2, unlock_multiplier), 80, "Ninth fact reaches unlock mastery")
    equal(profile.get_mastery(2, remaining_multiplier), 79, "Tenth fact may remain below 80")
    equal(profile.current_table(), 3, "Profile advances using the didactic rule")
    equal(unlocks, [Vector2i(2, 3)], "Unlock event identifies both islands")


func test_interruption_discards_runtime_but_keeps_processed_mastery() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    var controller := SessionController.new(profile, _save_test_profile)
    var result := controller.begin_session(9753)
    var question := controller.current_question()
    controller.submit_answer(question.answer(), 1.0)
    var abandoned := controller.abandon_active_session()

    equal(abandoned, result, "Abandoned result")
    equal(abandoned.status, SessionResult.Status.ABANDONED, "Abandoned status")
    equal(abandoned.can_receive_reward(), false, "Interrupted reward")
    equal(controller.active_result, null, "Runtime session is discarded")
    equal(controller.has_active_question(), false, "No question remains active")
    var loaded := SaveManager.load_profile(TEST_PATH)
    equal(
        loaded.get_mastery(question.table_value, question.multiplier),
        5,
        "Processed mastery remains saved"
    )
    _remove_test_file()


func test_ten_answers_complete_and_preserve_audits_for_reward_flow() -> void:
    var profile := LearningProfile.new()
    var controller := SessionController.new(profile)
    var result := controller.begin_session(8642)
    for index in LearningRules.SESSION_LENGTH:
        var question := controller.current_question()
        var submitted := question.answer() if index % 2 == 0 else -1
        controller.submit_answer(submitted, 5.0)

    equal(result.is_complete(), true, "Completed result")
    equal(result.can_receive_reward(), true, "Guaranteed completion reward")
    equal(result.answer_records.size(), LearningRules.SESSION_LENGTH, "Answer audits")
    equal(result.correct_count(), 5, "Mixed accuracy")
    equal(controller.current_question(), null, "No eleventh question")


func _save_test_profile(profile: LearningProfile) -> Error:
    return SaveManager.save_profile(profile, TEST_PATH)


func _signature(questions: Array[PracticeQuestion]) -> String:
    var parts: Array[String] = []
    for question in questions:
        parts.append(question.fact_key())
    return "|".join(parts)


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
