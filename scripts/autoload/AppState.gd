extends Node

var profile := LearningProfile.new()
var active_session: Array[PracticeQuestion] = []


func _ready() -> void:
    profile = SaveManager.load_profile()


func begin_session(seed: int = -1) -> Array[PracticeQuestion]:
    var actual_seed := seed
    if actual_seed < 0:
        actual_seed = int(Time.get_ticks_usec() & 0x7FFFFFFF)
    active_session = SessionGenerator.generate(profile, actual_seed)
    EventBus.session_started.emit(active_session.size())
    return active_session


func record_answer(question: PracticeQuestion, correct: bool, elapsed_seconds: float) -> int:
    var delta := profile.record_answer(
        question.table_value,
        question.multiplier,
        correct,
        elapsed_seconds
    )
    SaveManager.save_profile(profile)
    EventBus.answer_recorded.emit(
        question.fact_key(),
        correct,
        profile.get_mastery(question.table_value, question.multiplier)
    )
    return delta


func reset_local_profile() -> void:
    profile = LearningProfile.new()
    active_session.clear()
    SaveManager.save_profile(profile)
