extends NumblopTestCase


func test_practice_screen_has_four_and_six_choice_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    check(packed != null, "Practice scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    check(scene.has_signal("answer_submitted"), "Answer signal")
    check(scene.has_signal("exit_requested"), "Exit signal")
    check(scene.has_method("show_question"), "Question presentation method")
    check(scene.get_node("%ChoiceGrid").columns == 2, "Two-column choice layout")
    for index in range(1, 7):
        var button: Button = scene.get_node("%%Choice%d" % index)
        check(button.custom_minimum_size.y >= 48.0, "Choice %d touch target" % index)
        check(
            not button.has_theme_stylebox_override("hover"),
            "Choice %d retains desktop hover styling" % index
        )
    scene._configure_choice_hover(true)
    for index in range(1, 7):
        var touch_button: Button = scene.get_node("%%Choice%d" % index)
        check(
            touch_button.get_theme_stylebox("hover")
                == touch_button.get_theme_stylebox("normal"),
            "Choice %d ignores sticky touch hover styling" % index
        )
        equal(
            touch_button.get_theme_color("font_hover_color"),
            touch_button.get_theme_color("font_color"),
            "Choice %d keeps readable touch-hover text" % index
        )
    scene._configure_choice_hover(false)
    for index in range(1, 7):
        var desktop_button: Button = scene.get_node("%%Choice%d" % index)
        check(
            not desktop_button.has_theme_stylebox_override("hover"),
            "Choice %d restores desktop hover styling" % index
        )
    var focused_button: Button = scene.get_node("%Choice1")
    focused_button.grab_focus()
    check(focused_button.has_focus(), "Choice can receive keyboard focus")
    var replacement_choices: Array[int] = [6, 8, 10, 12]
    scene._show_choices(replacement_choices)
    check(not focused_button.has_focus(), "A new question clears retained answer focus")
    var exit_button: Button = scene.get_node("%ExitButton")
    check(exit_button.custom_minimum_size.y >= 48.0, "Exit touch target")
    scene.free()


func test_practice_screen_has_no_visible_countdown() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene := packed.instantiate()
    check(not scene.has_node("Countdown"), "No countdown node")
    check(not scene.has_node("TimerLabel"), "No visible timer label")
    scene.free()


func test_numeric_keypad_uses_large_in_game_touch_targets() -> void:
    var packed: PackedScene = load("res://scenes/components/NumericKeypad.tscn")
    check(packed != null, "Numeric keypad must load")
    if packed == null:
        return
    var keypad := packed.instantiate()
    check(keypad.has_signal("value_submitted"), "Numeric submit signal")
    check(not _contains_line_edit(keypad), "Keypad must not open the platform keyboard")
    var grid: GridContainer = keypad.get_node("%ButtonGrid")
    equal(grid.columns, 3, "Keypad columns")
    equal(grid.get_child_count(), 12, "Ten digits plus delete and submit")
    equal(
        keypad.get_node("%KeySfxPlayer").stream.resource_path,
        "res://audio/sfx/button.mp3",
        "Numeric key sound"
    )
    equal(keypad.get_node("%SubmitButton").text, "", "Submit avoids unsupported font glyphs")
    check(keypad.get_node("%SubmitCheck") is CheckmarkIcon, "Submit uses a drawn checkmark")
    equal(keypad.get_node("%DeleteButton").text, "", "Delete avoids unsupported font glyphs")
    check(keypad.get_node("%DeleteArrow") is BackspaceIcon, "Delete uses a drawn arrow")
    check(
        grid.theme.get_color("font_color", "Button").get_luminance() < 0.5,
        "Digits must remain readable on white keys"
    )
    for child in grid.get_children():
        if child is Button:
            check(child.custom_minimum_size.y >= 48.0, "Keypad touch target")
    keypad.free()


func test_wrong_feedback_has_complete_equation_and_tap_gate() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene := packed.instantiate()
    check(scene.has_method("show_answer_feedback"), "Feedback presentation method")
    check(scene.has_method("cancel_feedback"), "Lifecycle feedback cancellation")
    var continue_button: Button = scene.get_node("%ContinueButton")
    check(continue_button.custom_minimum_size.y >= 48.0, "Continue touch target")
    check(scene.get_node("%CorrectEquation") is Label, "Complete equation label")
    check(scene.get_node("%DotFactVisual") is DotFactVisual, "Drawn correction picture")
    check(scene.get_node("%DotHint") is Label, "Correction hint label")
    equal(scene.WRONG_DOTS_REVEAL_SECONDS, 1.2, "The correction fills in before Continue appears")

    var question := PracticeQuestion.new(7, 4, LearningRules.QuestionMode.CHOICE_FOUR, [21, 28, 32, 35])
    var session := SessionResult.new(_ten_copies(question))
    var record := session.record_answer(21, 1.0, 0)
    equal(scene.format_complete_equation(record), "7 × 4 = 28", "Complete correction")
    scene.free()


func test_a_wrong_answer_explains_the_fact_with_domino_dots() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene: PracticeScreen = packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    var visual: DotFactVisual = scene.get_node("%DotFactVisual")
    var hint: Label = scene.get_node("%DotHint")

    scene._present_answer_feedback(_wrong_record(3, 4))
    check(visual.visible, "Wrong answers show the correction picture")
    check(hint.visible, "Wrong answers explain what to count")
    equal(visual.card_count(), 3, "3x4 draws three groups")
    equal(visual.reveal_progress, 1.0, "The synchronous state is fully revealed for captures")
    check(scene.get_node("%ContinueButton").visible, "The synchronous state can be continued")

    scene._present_answer_feedback(_wrong_record(7, 4))
    equal(visual.card_count(), 4, "7x4 draws four groups of seven")

    var previous_locale := TranslationServer.get_locale()
    TranslationServer.set_locale("cs")
    scene._present_answer_feedback(_wrong_record(3, 4))
    equal(hint.text, "Spočítej tečky.", "Czech correction hint")
    scene._present_answer_feedback(_wrong_record(7, 0))
    check(visual.is_empty_fact(), "Times zero has no groups to draw")
    equal(hint.text, "Nula skupin. Není co počítat.", "Czech zero-group hint")
    TranslationServer.set_locale(previous_locale)

    scene._present_answer_feedback(_correct_record(3, 4))
    check(not visual.visible, "A correct answer needs no correction picture")
    check(not hint.visible, "A correct answer needs no correction hint")
    scene_tree.root.remove_child(scene)
    scene.free()


func test_the_reveal_withholds_continue_and_survives_an_interrupted_session() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene: PracticeScreen = packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    var visual: DotFactVisual = scene.get_node("%DotFactVisual")
    var continue_button: Button = scene.get_node("%ContinueButton")

    scene._present_answer_feedback(_wrong_record(3, 4))
    # Runs synchronously up to its own `await feedback_gate`.
    scene._wait_for_dot_reveal()
    check(not continue_button.visible, "Continue is withheld while the picture fills in")
    equal(visual.reveal_progress, 0.0, "The reveal rewinds the finished state and replays it")

    # Leaving mid-reveal must release the wait; a killed tween never emits `finished`, so this is
    # the path that would otherwise hang Main._on_answer_submitted forever.
    scene.cancel_feedback()
    check(scene._feedback_cancelled, "Interrupting marks the feedback cancelled")
    equal(visual.reveal_progress, 1.0, "The interrupted reveal leaves a clean state behind")
    check(not scene.get_node("%FeedbackOverlay").visible, "Interrupting hides the overlay")
    scene_tree.root.remove_child(scene)
    scene.free()


func _wrong_record(table_value: int, multiplier: int) -> SessionResult.AnswerRecord:
    var question := PracticeQuestion.new(
        table_value,
        multiplier,
        LearningRules.QuestionMode.CHOICE_FOUR,
        [table_value * multiplier, table_value * multiplier + 1]
    )
    return SessionResult.AnswerRecord.new(0, question, table_value * multiplier + 1, 1.0, 20)


func _correct_record(table_value: int, multiplier: int) -> SessionResult.AnswerRecord:
    var question := PracticeQuestion.new(
        table_value,
        multiplier,
        LearningRules.QuestionMode.CHOICE_FOUR,
        [table_value * multiplier, table_value * multiplier + 1]
    )
    return SessionResult.AnswerRecord.new(0, question, table_value * multiplier, 1.0, 20)


func test_the_streak_flash_fires_on_every_tenth_and_once_per_new_record() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene := packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    var flash: CenterContainer = scene.get_node("%StreakFlash")
    var label: Label = scene.get_node("%StreakFlashLabel")
    check(not flash.visible, "Nothing is celebrated before a streak builds")

    # An ordinary answer inside a modest run says nothing.
    scene._on_streak_changed(3, 20)
    check(not flash.visible, "A short run does not interrupt the question")

    # Every tenth answer in a row earns the flash.
    scene._on_streak_changed(10, 20)
    check(flash.visible, "The tenth answer in a row is celebrated")
    equal(label.text, "10", "The flash shows the running count")

    flash.visible = false
    scene._on_streak_changed(11, 20)
    check(not flash.visible, "The eleventh answer is not a milestone")

    # Beating the child's own record is celebrated once, not on every answer after it.
    # `all_time_high` is only written when a run ends, so without the guard every
    # further correct answer would still read as a new record.
    scene._on_streak_changed(21, 20)
    check(flash.visible, "Passing the old record is celebrated")
    equal(label.text, "21", "The record flash shows the new count")

    flash.visible = false
    scene._on_streak_changed(22, 20)
    check(not flash.visible, "The record is not re-celebrated on the next answer")
    scene._on_streak_changed(23, 20)
    check(not flash.visible, "Nor on the one after that")

    # A dropped streak arms the next record celebration again.
    scene._on_streak_changed(0, 23)
    scene._on_streak_changed(24, 23)
    check(flash.visible, "A fresh run can beat the record again")

    scene_tree.root.remove_child(scene)
    scene.free()


func test_the_milestone_popup_shows_a_cheering_avatar_that_stops_when_it_closes() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene := packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)

    var blob: BlobCharacter = scene.get_node("%MilestoneBlob")
    var blob_center: CenterContainer = scene.get_node("%MilestoneBlobCenter")
    check(not blob_center.visible, "No avatar before a milestone lands")
    check(blob.preview_mode, "The celebrating avatar is not pettable")

    scene._active_milestone = {
        "table_value": 7,
        "multiplier": 4,
        "status": &"mastered",
        "reward_coins": 5,
    }
    scene._refresh_mastery_milestone_feedback()
    check(blob_center.visible, "The avatar celebrates the milestone")
    check(blob.get_node("%LeftHandWave").visible, "Left hand goes up")
    check(blob.get_node("%RightHandWave").visible, "Right hand goes up")
    check(not blob.get_node("%RightHand").visible, "Idle right hand steps aside")
    check(not blob.get_node("%LeftHandIdle").visible, "Idle left hand steps aside")
    check(blob.get_node("%SmileOpen").visible, "Cheering blob is grinning")

    # A hop tween left looping behind a hidden panel would run for the whole session.
    scene._active_milestone.clear()
    scene._refresh_mastery_milestone_feedback()
    check(not blob_center.visible, "The avatar leaves with the popup")
    check(not blob.get_node("%RightHandWave").visible, "Hands come back down")
    check(blob.get_node("%RightHand").visible, "Idle right hand returns")
    equal(blob.get_node("%Visual").position.y, 0.0, "The hop is reset, not left mid-air")

    scene_tree.root.remove_child(scene)
    scene.free()


func test_petting_the_blob_still_raises_only_one_hand() -> void:
    # The milestone cheer has to stay distinguishable from an everyday pet.
    var packed: PackedScene = load("res://scenes/components/BlobCharacter.tscn")
    var blob: BlobCharacter = packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(blob)
    blob.react_to_pet()
    check(blob.get_node("%LeftHandWave").visible, "Pet raises the left hand")
    check(not blob.get_node("%RightHandWave").visible, "Pet leaves the right hand down")
    scene_tree.root.remove_child(blob)
    blob.free()


func test_mastery_milestone_feedback_names_fact_band_and_coin_bonus_in_czech() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    var scene := packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    var previous_locale := TranslationServer.get_locale()
    TranslationServer.set_locale("cs")
    scene._active_milestone = {
        "table_value": 7,
        "multiplier": 4,
        "status": &"mastered",
        "reward_coins": 5,
    }
    scene._refresh_mastery_milestone_feedback()

    var feedback_title: Label = scene.get_node("%FeedbackTitle")
    var fact_label: Label = scene.get_node("%MilestoneFactLabel")
    var status_label: Label = scene.get_node("%MilestoneStatusLabel")
    var reward_label: Label = scene.get_node("%MilestoneRewardLabel")
    var skip_button: Button = scene.get_node("%MilestoneSkipButton")
    check(fact_label.visible, "Milestone fact is visible")
    check(status_label.visible, "Milestone status is visible")
    check(reward_label.visible, "Milestone reward is visible")
    check(skip_button.visible, "Milestone feedback can be skipped by tapping anywhere")
    equal(scene.MILESTONE_FEEDBACK_SECONDS, 3.6, "Milestone feedback stays twice as long")
    equal(feedback_title.text, "Úspěch", "Czech milestone title")
    equal(fact_label.text, "7 × 4", "Milestone shows only the fact")
    equal(status_label.text, "Upevňuji", "Milestone shows only the new fact status")
    equal(reward_label.text, "+5 mincí", "Czech coin bonus message")
    equal(status_label.modulate, Color(0.95, 0.55, 0.08), "Orange milestone color")
    equal(
        fact_label.get_theme_font_size("font_size"),
        roundi(float(feedback_title.get_theme_font_size("font_size")) * 1.5),
        "Milestone fact is one and a half times the title size"
    )
    equal(
        fact_label.get_theme_font("font").resource_path,
        "res://ui/fonts/Baloo2Bold.tres",
        "Milestone fact uses the bold Baloo 2 font"
    )
    var skip_audit := {"emitted": false}
    scene.feedback_gate.connect(func() -> void: skip_audit["emitted"] = true)
    scene.get_node("%FeedbackOverlay").visible = true
    skip_button.pressed.emit()
    check(bool(skip_audit["emitted"]), "Milestone tap releases the feedback wait")
    TranslationServer.set_locale(previous_locale)
    scene.free()


func _contains_line_edit(node: Node) -> bool:
    if node is LineEdit:
        return true
    for child in node.get_children():
        if _contains_line_edit(child):
            return true
    return false


func _ten_copies(question: PracticeQuestion) -> Array[PracticeQuestion]:
    var questions: Array[PracticeQuestion] = []
    for index in LearningRules.SESSION_LENGTH:
        questions.append(question)
    return questions
