class_name SessionController
extends RefCounted

signal session_started(question_count: int)
signal answer_recorded(record: SessionResult.AnswerRecord)
signal table_unlocked(completed_table: int, new_table: int)
signal session_completed(result: SessionResult)
signal session_abandoned

var profile: LearningProfile
var active_result: SessionResult

var _save_profile: Callable
var _clock: Callable


func _init(
    p_profile: LearningProfile,
    p_save_profile: Callable = Callable(),
    p_clock: Callable = Callable()
) -> void:
    profile = p_profile
    _save_profile = p_save_profile
    _clock = p_clock


## Supplies the "last practised" stamps that the automated review slot orders by.
## `scripts/core/` may not read a clock, so the time is read here and passed down; tests
## inject their own so the ordering stays checkable without waiting on real seconds.
func _now() -> int:
    if _clock.is_valid():
        return int(_clock.call())
    return int(Time.get_unix_time_from_system())


func begin_session(seed: int) -> SessionResult:
    abandon_active_session()
    active_result = SessionResult.new(SessionGenerator.generate(profile, seed))
    session_started.emit(active_result.questions.size())
    return active_result


func current_question() -> PracticeQuestion:
    if active_result == null:
        return null
    return active_result.current_question()


func submit_answer(
    submitted_answer: int,
    elapsed_seconds: float
) -> SessionResult.AnswerRecord:
    var question := current_question()
    if question == null:
        push_error("Cannot submit an answer without an active question")
        return null

    var mastery_before := profile.get_mastery(question.table_value, question.multiplier)
    var unlocked_index_before := profile.highest_unlocked_index
    var record := active_result.record_answer(
        submitted_answer,
        elapsed_seconds,
        mastery_before
    )
    profile.set_mastery(question.table_value, question.multiplier, record.mastery_after)
    profile.mark_practiced(question.table_value, question.multiplier, _now())
    answer_recorded.emit(record)
    _save_after_answer()
    for unlocked_index in range(
        unlocked_index_before + 1,
        profile.highest_unlocked_index + 1
    ):
        table_unlocked.emit(
            LearningRules.TABLES[unlocked_index - 1],
            LearningRules.TABLES[unlocked_index]
        )
    if active_result.is_complete():
        session_completed.emit(active_result)
    return record


func abandon_active_session() -> SessionResult:
    if active_result == null or active_result.is_complete():
        return null
    var abandoned := active_result
    abandoned.abandon()
    active_result = null
    session_abandoned.emit()
    return abandoned


func clear_completed_session() -> void:
    if active_result != null and active_result.is_complete():
        active_result = null


func has_active_question() -> bool:
    return current_question() != null


func _save_after_answer() -> void:
    if not _save_profile.is_valid():
        return
    var result: Variant = _save_profile.call(profile)
    if result is int and int(result) != OK:
        push_error("Could not save mastery after an answer")
