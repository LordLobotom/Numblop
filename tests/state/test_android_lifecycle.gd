extends NumblopTestCase


func test_pause_discards_only_the_unfinished_runtime_session() -> void:
    var state := _new_state()
    var result: SessionResult
    state.begin_session(111)
    result = state.active_session_result

    equal(state.handle_application_paused(), true, "Pause handles active practice")
    equal(result.status, SessionResult.Status.ABANDONED, "Paused session is abandoned")
    equal(result.can_receive_reward(), false, "Paused session reward")
    equal(state.active_session_result, null, "Runtime result cleared")
    equal(state.active_session, [], "Runtime questions cleared")
    state.free()


func test_resume_does_not_restore_an_interrupted_question_list() -> void:
    var state := _new_state()
    state.begin_session(222)
    state.handle_application_paused()
    state.handle_application_resumed()

    equal(state.active_session, [], "No restored questions")
    equal(state.active_session_result, null, "No restored result")
    var replacement: Array[PracticeQuestion] = state.begin_session(333)
    equal(replacement.size(), LearningRules.SESSION_LENGTH, "Fresh session after resume")
    equal(state.active_session_result.answered_count(), 0, "Fresh answer count")
    state.free()


func test_android_back_abandons_practice_before_requesting_app_exit() -> void:
    var state := _new_state()
    state.begin_session(444)
    equal(state.handle_go_back_request(), true, "Back is consumed during practice")
    equal(state.active_session_result, null, "Back discards practice")
    equal(state.handle_go_back_request(), false, "Back can propagate from home")
    state.free()


func test_pause_without_practice_leaves_local_state_untouched() -> void:
    var state := _new_state()
    var profile: LearningProfile = state.profile
    var progress: LocalProgress = state.progress
    equal(state.handle_application_paused(), false, "No active practice")
    equal(state.profile, profile, "Profile remains loaded")
    equal(state.progress, progress, "Progress remains loaded")
    state.free()


func _new_state() -> Node:
    var state: Node = load("res://scripts/autoload/AppState.gd").new()
    state.profile = LearningProfile.new()
    state.progress = LocalProgress.new()
    state._create_session_controller()
    return state
