class_name PracticeScreen
extends Control

signal answer_submitted(value: int, elapsed_seconds: float)
signal exit_requested
signal feedback_gate

@onready var progress_label: Label = %ProgressLabel
@onready var exit_button: Button = %ExitButton
@onready var equation_label: Label = %EquationLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var choice_grid: GridContainer = %ChoiceGrid
@onready var numeric_keypad: NumericKeypad = %NumericKeypad
@onready var feedback_overlay: Control = %FeedbackOverlay
@onready var feedback_title: Label = %FeedbackTitle
@onready var correct_equation: Label = %CorrectEquation
@onready var continue_button: Button = %ContinueButton

var _question: PracticeQuestion
var _choice_buttons: Array[Button] = []
var _question_started_msec := 0
var _accepting_input := false
var _feedback_cancelled := false


func _ready() -> void:
    _choice_buttons.assign(get_tree().get_nodes_in_group("practice_choice_buttons"))
    _choice_buttons.sort_custom(_sort_buttons_by_name)
    for button in _choice_buttons:
        button.pressed.connect(_on_choice_pressed.bind(button))
    numeric_keypad.value_submitted.connect(_on_numeric_submitted)
    exit_button.pressed.connect(exit_requested.emit)
    continue_button.pressed.connect(_on_continue_feedback_pressed)
    _refresh_text()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func show_question(question: PracticeQuestion, question_index: int, total: int) -> void:
    _question = question
    progress_label.text = tr("PRACTICE_PROGRESS").format({
        "current": question_index + 1,
        "total": total,
    })
    equation_label.text = "%d × %d" % [question.table_value, question.multiplier]
    var choice_mode := question.mode == LearningRules.QuestionMode.CHOICE_FOUR \
        or question.mode == LearningRules.QuestionMode.CHOICE_SIX
    choice_grid.visible = choice_mode
    numeric_keypad.visible = not choice_mode
    if choice_mode:
        _show_choices(question.choices)
    else:
        numeric_keypad.reset()
        numeric_keypad.set_input_enabled(true)
    instruction_label.text = tr(
        "PRACTICE_CHOOSE_ANSWER" if choice_mode else "PRACTICE_ENTER_ANSWER"
    )
    feedback_overlay.visible = false
    _question_started_msec = Time.get_ticks_msec()
    _accepting_input = true


func set_input_enabled(enabled: bool) -> void:
    _accepting_input = enabled
    for button in _choice_buttons:
        button.disabled = not enabled
    numeric_keypad.set_input_enabled(enabled)


func show_answer_feedback(record: SessionResult.AnswerRecord) -> void:
    set_input_enabled(false)
    _feedback_cancelled = false
    feedback_overlay.visible = true
    if record.correct:
        feedback_title.text = tr("PRACTICE_CORRECT")
        feedback_title.modulate = Color(0.24, 0.63, 0.2)
        correct_equation.visible = false
        continue_button.visible = false
        await get_tree().create_timer(0.6).timeout
    else:
        feedback_title.text = tr("PRACTICE_INCORRECT")
        feedback_title.modulate = Color(0.33, 0.25, 0.5)
        correct_equation.text = format_complete_equation(record)
        correct_equation.visible = true
        continue_button.text = tr("PRACTICE_CONTINUE")
        continue_button.visible = true
        continue_button.grab_focus()
        await feedback_gate
    if _feedback_cancelled:
        return
    if is_inside_tree():
        feedback_overlay.visible = false


func cancel_feedback() -> void:
    if not feedback_overlay.visible:
        return
    _feedback_cancelled = true
    feedback_overlay.visible = false
    feedback_gate.emit()


func format_complete_equation(record: SessionResult.AnswerRecord) -> String:
    return "%d × %d = %d" % [record.table_value, record.multiplier, record.correct_answer]


func _show_choices(choices: Array[int]) -> void:
    for index in _choice_buttons.size():
        var button := _choice_buttons[index]
        button.visible = index < choices.size()
        button.disabled = false
        if index < choices.size():
            button.text = str(choices[index])
            button.set_meta("answer_value", choices[index])


func _on_choice_pressed(button: Button) -> void:
    if not _accepting_input:
        return
    set_input_enabled(false)
    var elapsed := float(Time.get_ticks_msec() - _question_started_msec) / 1000.0
    answer_submitted.emit(int(button.get_meta("answer_value")), elapsed)


func _on_numeric_submitted(value: int) -> void:
    if not _accepting_input:
        return
    set_input_enabled(false)
    var elapsed := float(Time.get_ticks_msec() - _question_started_msec) / 1000.0
    answer_submitted.emit(value, elapsed)


func _on_continue_feedback_pressed() -> void:
    if feedback_overlay.visible and continue_button.visible:
        feedback_gate.emit()


func _refresh_text() -> void:
    var numeric_mode := _question != null \
        and _question.mode == LearningRules.QuestionMode.NUMBER_INPUT
    instruction_label.text = tr(
        "PRACTICE_ENTER_ANSWER" if numeric_mode else "PRACTICE_CHOOSE_ANSWER"
    )
    exit_button.text = tr("PRACTICE_EXIT")
    exit_button.tooltip_text = tr("PRACTICE_EXIT_ACCESSIBLE")


func _sort_buttons_by_name(first: Button, second: Button) -> bool:
    return first.name.naturalnocasecmp_to(second.name) < 0
