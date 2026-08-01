class_name PracticeQuestion
extends RefCounted

var table_value: int
var multiplier: int
var mode: int
var choices: Array[int]


func _init(
    p_table_value: int = 2,
    p_multiplier: int = 0,
    p_mode: int = LearningRules.QuestionMode.CHOICE_FOUR,
    p_choices: Array[int] = []
) -> void:
    table_value = p_table_value
    multiplier = p_multiplier
    mode = p_mode
    choices = p_choices.duplicate()


func fact_key() -> String:
    return LearningRules.fact_key(table_value, multiplier)


func answer() -> int:
    return table_value * multiplier
