class_name SessionResult
extends RefCounted

enum Status {
    ACTIVE,
    COMPLETED,
    ABANDONED,
}

class AnswerRecord:
    extends RefCounted

    var question_index: int
    var fact_key: String
    var table_value: int
    var multiplier: int
    var mode: int
    var submitted_answer: int
    var correct_answer: int
    var correct: bool
    var elapsed_seconds: float
    var mastery_before: int
    var mastery_delta: int
    var mastery_after: int


    func _init(
        p_question_index: int,
        question: PracticeQuestion,
        p_submitted_answer: int,
        p_elapsed_seconds: float,
        p_mastery_before: int
    ) -> void:
        question_index = p_question_index
        fact_key = question.fact_key()
        table_value = question.table_value
        multiplier = question.multiplier
        mode = question.mode
        submitted_answer = p_submitted_answer
        correct_answer = question.answer()
        correct = submitted_answer == correct_answer
        elapsed_seconds = maxf(0.0, p_elapsed_seconds)
        mastery_before = LearningRules.clamp_mastery(p_mastery_before)
        mastery_delta = LearningRules.mastery_delta(correct, elapsed_seconds, mode)
        mastery_after = LearningRules.clamp_mastery(mastery_before + mastery_delta)


    func to_dictionary() -> Dictionary:
        return {
            "question_index": question_index,
            "fact_key": fact_key,
            "table_value": table_value,
            "multiplier": multiplier,
            "mode": mode,
            "submitted_answer": submitted_answer,
            "correct_answer": correct_answer,
            "correct": correct,
            "elapsed_seconds": elapsed_seconds,
            "mastery_before": mastery_before,
            "mastery_delta": mastery_delta,
            "mastery_after": mastery_after,
        }


var questions: Array[PracticeQuestion] = []
var answer_records: Array[AnswerRecord] = []
var status := Status.ACTIVE


func _init(p_questions: Array[PracticeQuestion] = []) -> void:
    questions = p_questions.duplicate()
    assert(
        questions.size() == LearningRules.SESSION_LENGTH,
        "A practice session must contain exactly %d questions" % LearningRules.SESSION_LENGTH
    )


func current_question() -> PracticeQuestion:
    if status != Status.ACTIVE or answer_records.size() >= questions.size():
        return null
    return questions[answer_records.size()]


func record_answer(
    submitted_answer: int,
    elapsed_seconds: float,
    mastery_before: int
) -> AnswerRecord:
    var question := current_question()
    if question == null:
        push_error("Cannot record an answer for an inactive session")
        return null

    var record := AnswerRecord.new(
        answer_records.size(),
        question,
        submitted_answer,
        elapsed_seconds,
        mastery_before
    )
    answer_records.append(record)
    if answer_records.size() == LearningRules.SESSION_LENGTH:
        status = Status.COMPLETED
    return record


func abandon() -> void:
    if status == Status.ACTIVE:
        status = Status.ABANDONED


func answered_count() -> int:
    return answer_records.size()


func correct_count() -> int:
    var count := 0
    for record in answer_records:
        if record.correct:
            count += 1
    return count


## Per-fact mastery movement across the whole session, largest gain first.
##
## A fact answered more than once collapses into a single entry spanning the first value seen
## and the last one recorded, so the summary always matches the real end-of-round state. Facts
## that did not improve are left out.
func mastery_gains() -> Array[Dictionary]:
    var fact_order: Array[String] = []
    var by_fact: Dictionary = {}
    for record in answer_records:
        if by_fact.has(record.fact_key):
            by_fact[record.fact_key]["mastery_after"] = record.mastery_after
            continue
        fact_order.append(record.fact_key)
        by_fact[record.fact_key] = {
            "fact_key": record.fact_key,
            "table_value": record.table_value,
            "multiplier": record.multiplier,
            "mastery_before": record.mastery_before,
            "mastery_after": record.mastery_after,
        }

    var gains: Array[Dictionary] = []
    for fact_key in fact_order:
        var entry: Dictionary = by_fact[fact_key]
        var gained := int(entry["mastery_after"]) - int(entry["mastery_before"])
        if gained <= 0:
            continue
        entry["mastery_gained"] = gained
        gains.append(entry)
    gains.sort_custom(_is_larger_mastery_gain)
    return gains


static func _is_larger_mastery_gain(left: Dictionary, right: Dictionary) -> bool:
    if int(left["mastery_gained"]) != int(right["mastery_gained"]):
        return int(left["mastery_gained"]) > int(right["mastery_gained"])
    if int(left["table_value"]) != int(right["table_value"]):
        return int(left["table_value"]) < int(right["table_value"])
    return int(left["multiplier"]) < int(right["multiplier"])


func total_elapsed_seconds() -> float:
    var total := 0.0
    for record in answer_records:
        total += record.elapsed_seconds
    return total


func is_complete() -> bool:
    return status == Status.COMPLETED


func can_receive_reward() -> bool:
    return is_complete() and answer_records.size() == LearningRules.SESSION_LENGTH
