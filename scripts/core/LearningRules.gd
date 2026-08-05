class_name LearningRules
extends RefCounted

enum QuestionMode {
    CHOICE_FOUR,
    CHOICE_SIX,
    NUMBER_INPUT,
}

const TABLES: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9]
const MULTIPLIERS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const UNLOCK_MASTERY := 80
const REQUIRED_FACTS_TO_UNLOCK := 9
const AUTOMATED_MASTERY := 90

## A fact leaves the review pool only once it saturates, and it is the saturated ones that
## the single automated slot cycles through. Deliberately distinct from AUTOMATED_MASTERY,
## which decides how a question is *asked* rather than how often it comes back: a fact at 95
## is already answered by typing, but it still counts as something to keep practising.
const REVIEW_MASTERY := 100

## The later tables carry more history behind them, so from the 6x table on a round is two
## questions longer and spends both extra slots on review rather than on new material.
const EXTENDED_MIX_TABLE := 6
const SESSION_LENGTH := 10
const EXTENDED_SESSION_LENGTH := 12


static func uses_extended_mix(table_value: int) -> bool:
    return table_value >= EXTENDED_MIX_TABLE


static func session_length(table_value: int) -> int:
    return EXTENDED_SESSION_LENGTH if uses_extended_mix(table_value) else SESSION_LENGTH


static func fact_key(table_value: int, multiplier: int) -> String:
    assert(TABLES.has(table_value), "Unsupported multiplication table")
    assert(MULTIPLIERS.has(multiplier), "Unsupported multiplier")
    return "%d_x_%d" % [table_value, multiplier]


static func clamp_mastery(value: int) -> int:
    return clampi(value, 0, 100)


static func mode_for_mastery(value: int) -> int:
    var mastery := clamp_mastery(value)
    if mastery < 60:
        return QuestionMode.CHOICE_FOUR
    if mastery < AUTOMATED_MASTERY:
        return QuestionMode.CHOICE_SIX
    return QuestionMode.NUMBER_INPUT


static func fast_limit_seconds(mode: int) -> float:
    match mode:
        QuestionMode.CHOICE_FOUR:
            return 2.5
        QuestionMode.CHOICE_SIX:
            return 3.0
        QuestionMode.NUMBER_INPUT:
            return 4.0
        _:
            push_error("Unknown question mode: %s" % mode)
            return 0.0


static func mastery_delta(correct: bool, elapsed_seconds: float, mode: int) -> int:
    if not correct:
        return -2
    if elapsed_seconds <= fast_limit_seconds(mode):
        return 5
    return 3
