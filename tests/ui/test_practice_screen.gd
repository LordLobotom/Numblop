extends NumblopTestCase


func test_practice_screen_has_four_and_six_choice_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/PracticeScreen.tscn")
    check(packed != null, "Practice scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_signal("answer_submitted"), "Answer signal")
    check(scene.has_signal("exit_requested"), "Exit signal")
    check(scene.has_method("show_question"), "Question presentation method")
    check(scene.get_node("%ChoiceGrid").columns == 2, "Two-column choice layout")
    for index in range(1, 7):
        var button: Button = scene.get_node("%%Choice%d" % index)
        check(button.custom_minimum_size.y >= 48.0, "Choice %d touch target" % index)
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

    var question := PracticeQuestion.new(7, 4, LearningRules.QuestionMode.CHOICE_FOUR, [21, 28, 32, 35])
    var session := SessionResult.new(_ten_copies(question))
    var record := session.record_answer(21, 1.0, 0)
    equal(scene.format_complete_equation(record), "7 × 4 = 28", "Complete correction")
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
