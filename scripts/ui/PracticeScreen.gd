class_name PracticeScreen
extends Control

signal answer_submitted(value: int, elapsed_seconds: float)
signal exit_requested
signal feedback_gate

const CORRECT_FEEDBACK_SECONDS := 0.6
const MILESTONE_FEEDBACK_SECONDS := 3.6

@onready var progress_label: Label = %ProgressLabel
@onready var exit_button: Button = %ExitButton
@onready var equation_label: Label = %EquationLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var choice_grid: GridContainer = %ChoiceGrid
@onready var numeric_keypad: NumericKeypad = %NumericKeypad
@onready var feedback_overlay: Control = %FeedbackOverlay
@onready var feedback_title: Label = %FeedbackTitle
@onready var milestone_label: Label = %MilestoneLabel
@onready var milestone_reward_label: Label = %MilestoneRewardLabel
@onready var correct_equation: Label = %CorrectEquation
@onready var continue_button: Button = %ContinueButton
@onready var milestone_skip_button: Button = %MilestoneSkipButton

var _question: PracticeQuestion
var _choice_buttons: Array[Button] = []
var _question_started_msec := 0
var _accepting_input := false
var _feedback_cancelled := false
var _active_milestone: Dictionary = {}


func _ready() -> void:
    _choice_buttons.assign(get_tree().get_nodes_in_group("practice_choice_buttons"))
    _choice_buttons.sort_custom(_sort_buttons_by_name)
    for button in _choice_buttons:
        button.pressed.connect(_on_choice_pressed.bind(button))
    _configure_choice_hover(DisplayServer.is_touchscreen_available())
    numeric_keypad.value_submitted.connect(_on_numeric_submitted)
    exit_button.pressed.connect(exit_requested.emit)
    continue_button.pressed.connect(_on_continue_feedback_pressed)
    milestone_skip_button.pressed.connect(_on_milestone_skip_pressed)
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
    _active_milestone.clear()
    _refresh_mastery_milestone_feedback()
    feedback_overlay.visible = false
    _question_started_msec = Time.get_ticks_msec()
    _accepting_input = true


func set_input_enabled(enabled: bool) -> void:
    _accepting_input = enabled
    for button in _choice_buttons:
        button.disabled = not enabled
    numeric_keypad.set_input_enabled(enabled)


func show_answer_feedback(
    record: SessionResult.AnswerRecord,
    milestone: Dictionary = {}
) -> void:
    _present_answer_feedback(record, milestone)
    if record.correct:
        if _active_milestone.is_empty():
            await get_tree().create_timer(CORRECT_FEEDBACK_SECONDS).timeout
        else:
            await _wait_for_milestone_feedback()
    else:
        await feedback_gate
    if _feedback_cancelled:
        return
    if is_inside_tree():
        feedback_overlay.visible = false


func _present_answer_feedback(
    record: SessionResult.AnswerRecord,
    milestone: Dictionary = {}
) -> void:
    set_input_enabled(false)
    _feedback_cancelled = false
    _active_milestone = milestone.duplicate(true) if record.correct else {}
    _refresh_mastery_milestone_feedback()
    feedback_overlay.visible = true
    if record.correct:
        feedback_title.text = tr("PRACTICE_CORRECT")
        feedback_title.modulate = Color(0.24, 0.63, 0.2)
        correct_equation.visible = false
        continue_button.visible = false
    else:
        feedback_title.text = tr("PRACTICE_INCORRECT")
        feedback_title.modulate = Color(0.33, 0.25, 0.5)
        correct_equation.text = format_complete_equation(record)
        correct_equation.visible = true
        continue_button.text = tr("PRACTICE_CONTINUE")
        continue_button.visible = true
        continue_button.grab_focus()


func cancel_feedback() -> void:
    if not feedback_overlay.visible:
        return
    _feedback_cancelled = true
    feedback_overlay.visible = false
    feedback_gate.emit()


func format_complete_equation(record: SessionResult.AnswerRecord) -> String:
    return "%d × %d = %d" % [record.table_value, record.multiplier, record.correct_answer]


func _refresh_mastery_milestone_feedback() -> void:
    var visible := not _active_milestone.is_empty()
    milestone_label.visible = visible
    milestone_reward_label.visible = visible
    milestone_skip_button.visible = visible
    if not visible:
        return
    var table_value := int(_active_milestone.get("table_value", 0))
    var multiplier := int(_active_milestone.get("multiplier", 0))
    var status := StringName(_active_milestone.get("status", &"building"))
    var reward_coins := int(_active_milestone.get("reward_coins", 0))
    milestone_label.text = tr("PRACTICE_MILESTONE_REACHED").format({
        "fact": "%d × %d" % [table_value, multiplier],
        "status": tr(_fact_status_key(status)),
    })
    milestone_label.modulate = _fact_status_color(status)
    milestone_reward_label.text = tr("PRACTICE_MILESTONE_REWARD").format({
        "coins": reward_coins,
    })


func _fact_status_key(status: StringName) -> StringName:
    match status:
        &"practicing":
            return &"MAP_FACT_PRACTICING"
        &"mastered":
            return &"MAP_FACT_MASTERED"
        &"automated":
            return &"MAP_FACT_AUTOMATED"
        _:
            return &"MAP_FACT_BUILDING"


func _fact_status_color(status: StringName) -> Color:
    match status:
        &"practicing":
            return Color(0.58, 0.37, 0.78)
        &"mastered":
            return Color(0.95, 0.55, 0.08)
        &"automated":
            return Color(0.27, 0.7, 0.2)
        _:
            return Color(0.9, 0.25, 0.2)


func _show_choices(choices: Array[int]) -> void:
    for index in _choice_buttons.size():
        var button := _choice_buttons[index]
        button.release_focus()
        button.visible = index < choices.size()
        button.disabled = false
        if index < choices.size():
            button.text = str(choices[index])
            button.set_meta("answer_value", choices[index])


func _configure_choice_hover(touchscreen_available: bool) -> void:
    for button in _choice_buttons:
        if touchscreen_available:
            button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
            button.add_theme_color_override(
                "font_hover_color",
                button.get_theme_color("font_color")
            )
        else:
            button.remove_theme_stylebox_override("hover")
            button.remove_theme_color_override("font_hover_color")


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


func _on_milestone_skip_pressed() -> void:
    if feedback_overlay.visible and not _active_milestone.is_empty():
        feedback_gate.emit()


func _wait_for_milestone_feedback() -> void:
    var timer := get_tree().create_timer(MILESTONE_FEEDBACK_SECONDS)
    var finish_feedback := func() -> void:
        feedback_gate.emit()
    timer.timeout.connect(finish_feedback, CONNECT_ONE_SHOT)
    await feedback_gate
    if timer.timeout.is_connected(finish_feedback):
        timer.timeout.disconnect(finish_feedback)


func _refresh_text() -> void:
    var numeric_mode := _question != null \
        and _question.mode == LearningRules.QuestionMode.NUMBER_INPUT
    instruction_label.text = tr(
        "PRACTICE_ENTER_ANSWER" if numeric_mode else "PRACTICE_CHOOSE_ANSWER"
    )
    exit_button.text = tr("PRACTICE_EXIT")
    exit_button.tooltip_text = tr("PRACTICE_EXIT_ACCESSIBLE")
    milestone_skip_button.tooltip_text = tr("PRACTICE_MILESTONE_SKIP_ACCESSIBLE")
    _refresh_mastery_milestone_feedback()


func _sort_buttons_by_name(first: Button, second: Button) -> bool:
    return first.name.naturalnocasecmp_to(second.name) < 0
