extends Node

var profile := LearningProfile.new()
var active_session: Array[PracticeQuestion] = []
var active_session_result: SessionResult
var session_controller: SessionController
var progress := LocalProgress.new()


func _ready() -> void:
    profile = SaveManager.load_profile()
    progress = LocalProgress.new(SaveManager.load_progress())
    _create_session_controller()


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            handle_application_paused()
        NOTIFICATION_APPLICATION_RESUMED:
            handle_application_resumed()
        NOTIFICATION_WM_GO_BACK_REQUEST:
            handle_go_back_request()


func begin_session(seed: int = -1) -> Array[PracticeQuestion]:
    var actual_seed := seed
    if actual_seed < 0:
        actual_seed = int(Time.get_ticks_usec() & 0x7FFFFFFF)
    active_session_result = session_controller.begin_session(actual_seed)
    active_session = active_session_result.questions.duplicate()
    return active_session


func submit_answer(
    submitted_answer: int,
    elapsed_seconds: float
) -> SessionResult.AnswerRecord:
    return session_controller.submit_answer(submitted_answer, elapsed_seconds)


func record_answer(question: PracticeQuestion, correct: bool, elapsed_seconds: float) -> int:
    assert(question == session_controller.current_question(), "Answers must be submitted in order")
    var submitted_answer := question.answer() if correct else question.answer() + 1
    var record := submit_answer(submitted_answer, elapsed_seconds)
    return record.mastery_delta


func abandon_session() -> void:
    session_controller.abandon_active_session()
    active_session_result = null
    active_session.clear()


func handle_application_paused() -> bool:
    return _interrupt_unfinished_session()


func handle_application_resumed() -> void:
    EventBus.application_resumed.emit()


func handle_go_back_request() -> bool:
    if _interrupt_unfinished_session():
        return true
    EventBus.back_requested.emit()
    return false


func claim_completed_session_reward() -> Dictionary:
    var reward := progress.apply_completed_session(
        active_session_result,
        profile,
        SaveManager.save_game_state
    )
    if reward.is_empty():
        return {}
    EventBus.reward_applied.emit(int(reward["coins"]), int(reward["experience"]))
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())
    session_controller.clear_completed_session()
    active_session_result = null
    active_session.clear()
    return reward


func progress_totals() -> Dictionary:
    return progress.totals()


func map_stage_states() -> Array[Dictionary]:
    var stage_states: Array[Dictionary] = []
    for index in LearningRules.TABLES.size():
        var table_value: int = LearningRules.TABLES[index]
        var mastered_facts := 0
        for multiplier in LearningRules.MULTIPLIERS:
            if profile.get_mastery(table_value, multiplier) >= LearningRules.UNLOCK_MASTERY:
                mastered_facts += 1
        var final_stage_complete := (
            index == LearningRules.TABLES.size() - 1
            and mastered_facts == LearningRules.MULTIPLIERS.size()
        )
        var completed := index < profile.highest_unlocked_index or final_stage_complete
        stage_states.append({
            "table": table_value,
            "unlocked": index <= profile.highest_unlocked_index,
            "current": index == profile.highest_unlocked_index and not completed,
            "completed": completed,
            "mastered_facts": mastered_facts,
        })
    return stage_states


func reset_local_profile() -> void:
    abandon_session()
    profile = LearningProfile.new()
    progress = LocalProgress.new()
    SaveManager.save_game_state(profile, progress.coins, progress.experience)
    _create_session_controller()


func _create_session_controller() -> void:
    session_controller = SessionController.new(profile, SaveManager.save_profile)
    session_controller.session_started.connect(_on_session_started)
    session_controller.answer_recorded.connect(_on_answer_recorded)


func _on_session_started(question_count: int) -> void:
    EventBus.session_started.emit(question_count)


func _on_answer_recorded(record: SessionResult.AnswerRecord) -> void:
    EventBus.answer_recorded.emit(record.fact_key, record.correct, record.mastery_after)


func _interrupt_unfinished_session() -> bool:
    if session_controller == null or not session_controller.has_active_question():
        return false
    abandon_session()
    EventBus.session_interrupted.emit()
    return true
