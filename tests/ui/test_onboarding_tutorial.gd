extends NumblopTestCase

const EXPECTED_SEQUENCE: Array[StringName] = [
    &"play",
    &"correct_answer",
    &"chest",
    &"cosmetics",
    &"buy",
    &"home",
    &"play_again",
    &"map",
    &"island",
]


func test_main_scene_carries_the_tutorial_overlay_above_every_screen() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var tutorial := scene.get_node_or_null("OnboardingTutorial") as OnboardingTutorial
    check(tutorial != null, "Main scene carries the guided tutorial")
    if tutorial == null:
        scene.free()
        return
    equal(
        scene.get_children().back(),
        tutorial,
        "The finger draws over every screen it points at"
    )
    equal(
        tutorial.mouse_filter,
        Control.MOUSE_FILTER_IGNORE,
        "The overlay never swallows the tap it is asking for"
    )
    var finger := tutorial.get_node("Finger") as TextureRect
    check(finger != null, "Overlay owns the finger")
    if finger != null:
        check(not finger.visible, "The finger stays hidden until a step is on screen")
        equal(
            finger.mouse_filter,
            Control.MOUSE_FILTER_IGNORE,
            "The finger never swallows the tap it is asking for"
        )
        equal(
            finger.texture.resource_path,
            "res://ui/misc/onboarding_tutorial_finger.png",
            "Tutorial finger artwork"
        )
    scene.free()


func test_the_guided_sequence_covers_the_whole_loop_in_order() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    var scene := packed.instantiate()
    var tutorial := scene.get_node("OnboardingTutorial") as OnboardingTutorial
    var sequence: Array[StringName] = []
    for step in tutorial._build_steps():
        sequence.append(step["id"])
    equal(sequence, EXPECTED_SEQUENCE, "Tutorial step order")
    scene.free()


func test_every_step_names_a_target_and_a_completion_condition() -> void:
    # A step without either would either point at nothing or never end.
    var packed: PackedScene = load("res://scenes/Main.tscn")
    var scene := packed.instantiate()
    var tutorial := scene.get_node("OnboardingTutorial") as OnboardingTutorial
    for step in tutorial._build_steps():
        var target: Callable = step["target"]
        var is_done: Callable = step["done"]
        check(target.is_valid(), "%s resolves a control" % step["id"])
        check(is_done.is_valid(), "%s ends on a player action" % step["id"])
    scene.free()


func test_screens_expose_the_controls_the_tutorial_points_at() -> void:
    # These are the only reason the tutorial can stay in one file instead of threading
    # itself through five screens, so they are part of the contract.
    var practice: PracticeScreen = load(
        "res://scenes/screens/PracticeScreen.tscn"
    ).instantiate()
    check(practice.has_method("correct_answer_control"), "Practice names the right answer")
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(practice)
    check(
        practice.correct_answer_control() == null,
        "Nothing to point at before a question is on screen"
    )
    var question := PracticeQuestion.new(
        3,
        4,
        LearningRules.QuestionMode.CHOICE_FOUR,
        [8, 12, 14, 15]
    )
    practice.show_question(question, 0, 10)
    var correct_button := practice.correct_answer_control()
    check(correct_button != null, "The finger finds the correct choice")
    if correct_button != null:
        equal(correct_button.text, "12", "It points at the answer, not at a distractor")
    practice.set_input_enabled(false)
    check(
        practice.correct_answer_control() == null,
        "Feedback withdraws the finger instead of pointing at a dead button"
    )
    _release_audio_streams(practice)
    scene_tree.root.remove_child(practice)
    practice.free()

    var cosmetics: CosmeticsScreen = load(
        "res://scenes/screens/CosmeticsScreen.tscn"
    ).instantiate()
    scene_tree.root.add_child(cosmetics)
    check(cosmetics.purchase_button != null, "The finger finds the Buy button")
    if cosmetics.purchase_button != null:
        check(
            cosmetics.purchase_button.visible,
            "Buy is always on screen, so the shop step never points at a hidden control"
        )
    _release_audio_streams(cosmetics)
    scene_tree.root.remove_child(cosmetics)
    cosmetics.free()

    var map: MapScreen = load("res://scenes/screens/MapScreen.tscn").instantiate()
    check(map.has_method("stage_button"), "Map resolves one island crest")
    check(map.stage_button(2) == null, "An unbuilt map has no crest to point at")
    map.free()


func test_a_restored_profile_ends_or_advances_the_sequence() -> void:
    # The reason the tutorial replayed after a reinstall: the overlay read the save once at boot,
    # and the cloud restore arrived seconds later without it noticing.
    var step_count := EXPECTED_SEQUENCE.size()
    equal(
        OnboardingTutorial.restored_step_index(0, 0, true, step_count),
        -1,
        "A restored save that is already onboarded ends the tutorial"
    )
    equal(
        OnboardingTutorial.restored_step_index(6, 2, true, step_count),
        -1,
        "Completion wins over any step, however far the local sequence got"
    )
    equal(
        OnboardingTutorial.restored_step_index(1, 5, false, step_count),
        5,
        "A further saved step moves the finger forward"
    )
    equal(
        OnboardingTutorial.restored_step_index(5, 1, false, step_count),
        5,
        "A restore never walks a child back to a control they already used"
    )
    equal(
        OnboardingTutorial.restored_step_index(0, 99, false, step_count),
        step_count - 1,
        "A step past the end of the sequence lands on its last step"
    )


func test_the_finger_waits_only_for_a_restore_that_could_still_cancel_it() -> void:
    check(
        OnboardingTutorial.waits_for_restore(true, 0, 0),
        "An untouched profile with a restore in flight holds the finger back"
    )
    check(
        not OnboardingTutorial.waits_for_restore(false, 0, 0),
        "Offline, nothing is ever in flight and the finger appears at once"
    )
    check(
        not OnboardingTutorial.waits_for_restore(true, 2, 0),
        "A child already mid-sequence is not left without a finger"
    )
    check(
        not OnboardingTutorial.waits_for_restore(true, 0, 3),
        "A profile that has finished rounds is not waiting to be replaced"
    )


func test_app_state_owns_the_saved_tutorial_position() -> void:
    # The overlay holds no completion state of its own: it reads and writes this, which is
    # what makes a finished tutorial stay finished across a restart.
    check(AppState.has_method("onboarding_state"), "App state publishes tutorial progress")
    check(AppState.has_method("record_onboarding_step"), "A step can be remembered")
    check(AppState.has_method("complete_onboarding"), "Completion can be written")
    var state := AppState.onboarding_state()
    check(state.has("completed"), "Tutorial state carries a completion flag")
    check(state.has("step"), "Tutorial state carries the resumed step")


func _release_audio_streams(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stream = null
    for child in node.get_children():
        _release_audio_streams(child)
