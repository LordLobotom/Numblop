extends NumblopTestCase

const EXPECTED_SEQUENCE: Array[StringName] = [
    &"play",
    &"correct_answer",
    &"chest",
    &"cosmetics",
    &"hats_tab",
    &"first_hat",
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
    check(cosmetics.has_method("item_card"), "Cosmetics resolves a live catalog card")
    check(cosmetics.has_method("previewed_item"), "Cosmetics names what Buy would act on")
    _release_audio_streams(cosmetics)
    cosmetics.free()

    var map: MapScreen = load("res://scenes/screens/MapScreen.tscn").instantiate()
    check(map.has_method("stage_button"), "Map resolves one island crest")
    check(map.stage_button(2) == null, "An unbuilt map has no crest to point at")
    map.free()


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
