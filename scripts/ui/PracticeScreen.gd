class_name PracticeScreen
extends Control

signal answer_submitted(value: int, elapsed_seconds: float)
signal exit_requested
signal feedback_gate

const CORRECT_FEEDBACK_SECONDS := 0.6
const MILESTONE_FEEDBACK_SECONDS := 3.6
## The correction picture fills in over this long before Continue appears, so the explanation
## cannot be tapped away before it has been seen. After that the child has all the time they want.
const WRONG_DOTS_REVEAL_SECONDS := 1.2
## Every tenth answer in a row gets a flash, and so does the first answer that beats the
## child's own record. The record is only celebrated once per run: `all_time_high` is
## not written until a streak ends, so `current_count > all_time_high` stays true for
## every answer after the record falls, and flashing on each would drain the moment.
const STREAK_FLASH_INTERVAL := 10
const STREAK_FLASH_HOLD_SECONDS := 1.1

@onready var progress_label: Label = %ProgressLabel
@onready var exit_button: Button = %ExitButton
@onready var equation_label: Label = %EquationLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var choice_grid: GridContainer = %ChoiceGrid
@onready var numeric_keypad: NumericKeypad = %NumericKeypad
@onready var feedback_overlay: Control = %FeedbackOverlay
@onready var feedback_title: Label = %FeedbackTitle
@onready var milestone_fact_label: Label = %MilestoneFactLabel
@onready var milestone_status_label: Label = %MilestoneStatusLabel
@onready var milestone_reward_label: Label = %MilestoneRewardLabel
@onready var correct_equation: Label = %CorrectEquation
@onready var dot_fact_visual: DotFactVisual = %DotFactVisual
@onready var dot_hint: Label = %DotHint
@onready var continue_button: Button = %ContinueButton
@onready var milestone_skip_button: Button = %MilestoneSkipButton
@onready var milestone_blob_center: CenterContainer = %MilestoneBlobCenter
@onready var milestone_blob: BlobCharacter = %MilestoneBlob
@onready var streak_flash: CenterContainer = %StreakFlash
@onready var streak_flash_row: HBoxContainer = %StreakFlashRow
@onready var streak_flash_label: Label = %StreakFlashLabel

var _question: PracticeQuestion
var _choice_buttons: Array[Button] = []
var _question_started_msec := 0
var _accepting_input := false
var _feedback_cancelled := false
var _active_milestone: Dictionary = {}
var _celebrated_record_this_run := false
var _streak_flash_tween: Tween


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
    EventBus.streak_changed.connect(_on_streak_changed)
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
        await _wait_for_dot_reveal()
        if _feedback_cancelled:
            return
        continue_button.visible = true
        continue_button.grab_focus()
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
        feedback_title.text = tr(
            "PRACTICE_CORRECT"
            if _active_milestone.is_empty()
            else "PRACTICE_MILESTONE_TITLE"
        )
        feedback_title.modulate = Color(0.24, 0.63, 0.2)
        correct_equation.visible = false
        dot_fact_visual.visible = false
        dot_hint.visible = false
        continue_button.visible = false
    else:
        feedback_title.text = tr("PRACTICE_INCORRECT")
        feedback_title.modulate = Color(0.33, 0.25, 0.5)
        correct_equation.text = format_complete_equation(record)
        correct_equation.visible = true
        # This leaves the finished state on purpose: contract tests and the capture harness call
        # this synchronously, and `show_answer_feedback` rewinds it to animate.
        dot_fact_visual.set_fact(record.table_value, record.multiplier)
        dot_fact_visual.reveal_progress = 1.0
        dot_fact_visual.visible = true
        dot_hint.text = tr(
            "PRACTICE_DOTS_ZERO_HINT" if dot_fact_visual.is_empty_fact() else "PRACTICE_DOTS_HINT"
        )
        dot_hint.visible = true
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
    milestone_fact_label.visible = visible
    milestone_status_label.visible = visible
    milestone_reward_label.visible = visible
    milestone_skip_button.visible = visible
    milestone_blob_center.visible = visible
    # The blob only hops while the milestone is on screen, so the tween is not left
    # looping behind a hidden panel for the rest of the session.
    milestone_blob.set_cheering(visible)
    if not visible:
        return
    # It is the child's own avatar that celebrates, so it wears what they have equipped.
    milestone_blob.apply_cosmetics(AppState.cosmetics_state())
    var table_value := int(_active_milestone.get("table_value", 0))
    var multiplier := int(_active_milestone.get("multiplier", 0))
    var status := StringName(_active_milestone.get("status", &"building"))
    var reward_coins := int(_active_milestone.get("reward_coins", 0))
    feedback_title.text = tr("PRACTICE_MILESTONE_TITLE")
    milestone_fact_label.text = "%d × %d" % [table_value, multiplier]
    milestone_status_label.text = tr(_fact_status_key(status))
    milestone_status_label.modulate = _fact_status_color(status)
    milestone_reward_label.text = tr("PRACTICE_MILESTONE_REWARD").format({
        "coins": reward_coins,
    })


func _on_streak_changed(current_count: int, all_time_high: int) -> void:
    if current_count <= 0:
        # The run ended, so the next record is worth celebrating again.
        _celebrated_record_this_run = false
        return
    if current_count % STREAK_FLASH_INTERVAL == 0:
        _show_streak_flash(current_count)
        return
    if current_count > all_time_high and not _celebrated_record_this_run:
        _celebrated_record_this_run = true
        _show_streak_flash(current_count)


## Pops the flame and the running count over the question for a moment.
##
## Deliberately transient: the streak has no permanent place on this screen, so it
## appears only when it has just been earned and then gets out of the way.
func _show_streak_flash(count: int) -> void:
    streak_flash_label.text = str(count)
    streak_flash.visible = true
    if _streak_flash_tween != null:
        _streak_flash_tween.kill()
    streak_flash_row.pivot_offset = streak_flash_row.size / 2.0
    streak_flash_row.scale = Vector2(0.6, 0.6)
    streak_flash.modulate.a = 0.0
    _streak_flash_tween = create_tween()
    _streak_flash_tween.tween_property(streak_flash_row, "scale", Vector2(1.18, 1.18), 0.18) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _streak_flash_tween.parallel().tween_property(streak_flash, "modulate:a", 1.0, 0.14)
    _streak_flash_tween.tween_property(streak_flash_row, "scale", Vector2.ONE, 0.16) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _streak_flash_tween.tween_interval(STREAK_FLASH_HOLD_SECONDS)
    _streak_flash_tween.tween_property(streak_flash, "modulate:a", 0.0, 0.3)
    _streak_flash_tween.tween_callback(func() -> void: streak_flash.visible = false)


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


## Fills the correction picture in, then releases. Races the tween against `feedback_gate` exactly
## like the milestone wait does: `Tween.kill()` never emits `finished`, so awaiting the tween
## alone would hang this coroutine — and `Main._on_answer_submitted` is awaiting it.
func _wait_for_dot_reveal() -> void:
    continue_button.visible = false
    continue_button.release_focus()
    dot_fact_visual.reveal_progress = 0.0
    var reveal := create_tween()
    reveal.tween_property(
        dot_fact_visual,
        "reveal_progress",
        1.0,
        WRONG_DOTS_REVEAL_SECONDS
    ).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    var finish_reveal := func() -> void:
        feedback_gate.emit()
    reveal.finished.connect(finish_reveal, CONNECT_ONE_SHOT)
    await feedback_gate
    if reveal.finished.is_connected(finish_reveal):
        reveal.finished.disconnect(finish_reveal)
    if reveal.is_valid():
        reveal.kill()
    dot_fact_visual.reveal_progress = 1.0


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
