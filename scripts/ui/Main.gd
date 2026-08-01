extends Control

@onready var home_screen: HomeScreen = %HomeScreen
@onready var map_screen: MapScreen = %MapScreen
@onready var settings_screen: SettingsScreen = %SettingsScreen
@onready var practice_screen: PracticeScreen = %PracticeScreen
@onready var reward_screen: RewardScreen = %RewardScreen
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var ui_sfx_player: AudioStreamPlayer = %UiSfxPlayer
@onready var answer_sfx_player: AudioStreamPlayer = %AnswerSfxPlayer
@onready var correct_sfx_player: AudioStreamPlayer = %CorrectSfxPlayer
@onready var page_sfx_player: AudioStreamPlayer = %PageSfxPlayer

func _ready() -> void:
    home_screen.play_requested.connect(_on_play_requested)
    home_screen.map_requested.connect(_on_map_requested)
    home_screen.outfit_requested.connect(_on_future_feature_requested)
    home_screen.trophy_requested.connect(_on_future_feature_requested)
    home_screen.settings_requested.connect(_on_settings_requested)
    map_screen.return_home_requested.connect(_on_map_return_requested)
    map_screen.outfit_requested.connect(_on_future_feature_requested)
    map_screen.trophy_requested.connect(_on_future_feature_requested)
    map_screen.settings_requested.connect(_on_settings_requested)
    settings_screen.home_requested.connect(_on_settings_home_requested)
    settings_screen.map_requested.connect(_on_settings_map_requested)
    settings_screen.outfit_requested.connect(_on_settings_future_feature_requested)
    settings_screen.trophy_requested.connect(_on_settings_future_feature_requested)
    settings_screen.exit_requested.connect(_on_exit_requested)
    practice_screen.answer_submitted.connect(_on_answer_submitted)
    practice_screen.exit_requested.connect(_on_practice_exit_requested)
    reward_screen.return_home_requested.connect(_on_reward_return_requested)
    EventBus.session_interrupted.connect(_on_session_interrupted)
    EventBus.back_requested.connect(_on_back_requested)
    music_player.finished.connect(_on_music_finished)
    if not music_player.playing:
        music_player.play()
    if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
        call_deferred("_center_desktop_window")


func _on_play_requested() -> void:
    _play_page_sfx()
    var questions := AppState.begin_session()
    home_screen.visible = false
    practice_screen.visible = true
    practice_screen.show_question(questions[0], 0, questions.size())


func _on_answer_submitted(value: int, elapsed_seconds: float) -> void:
    answer_sfx_player.play()
    var record := AppState.submit_answer(value, elapsed_seconds)
    if record.correct:
        correct_sfx_player.play()
    var result := AppState.active_session_result
    var reward: Dictionary = {}
    if result.is_complete():
        reward = AppState.claim_completed_session_reward()
    await practice_screen.show_answer_feedback(record)
    if result.is_complete():
        practice_screen.visible = false
        reward_screen.visible = true
        reward_screen.start_reward(reward)
        return
    if AppState.active_session_result != result:
        return
    var question_index := result.answered_count()
    practice_screen.show_question(
        result.current_question(),
        question_index,
        result.questions.size()
    )


func _on_practice_exit_requested() -> void:
    _play_page_sfx()
    AppState.abandon_session()
    practice_screen.visible = false
    home_screen.visible = true


func _on_reward_return_requested() -> void:
    _play_page_sfx()
    reward_screen.visible = false
    home_screen.visible = true
    home_screen.celebrate_reward()


func _on_session_interrupted() -> void:
    practice_screen.cancel_feedback()
    practice_screen.visible = false
    home_screen.visible = true


func _on_map_requested() -> void:
    _play_page_sfx()
    map_screen.set_stage_states(AppState.map_stage_states())
    home_screen.visible = false
    map_screen.visible = true


func _on_map_return_requested() -> void:
    _play_page_sfx()
    map_screen.visible = false
    home_screen.visible = true


func _on_future_feature_requested() -> void:
    _play_confirm_sfx()
    if map_screen.visible:
        map_screen.show_future_feature()
    else:
        home_screen.show_future_feature()


func _on_back_requested() -> void:
    if settings_screen.visible:
        _on_settings_home_requested()
    elif map_screen.visible:
        _on_map_return_requested()


func _on_settings_requested() -> void:
    _play_page_sfx()
    settings_screen.refresh_from_settings()
    home_screen.visible = false
    map_screen.visible = false
    settings_screen.visible = true


func _on_settings_home_requested() -> void:
    _play_page_sfx()
    settings_screen.visible = false
    map_screen.visible = false
    home_screen.visible = true


func _on_settings_map_requested() -> void:
    _play_page_sfx()
    settings_screen.visible = false
    map_screen.set_stage_states(AppState.map_stage_states())
    map_screen.visible = true


func _on_settings_future_feature_requested() -> void:
    _play_confirm_sfx()
    settings_screen.show_future_feature()


func _on_exit_requested() -> void:
    get_tree().quit()


func _on_music_finished() -> void:
    music_player.play()


func _play_confirm_sfx() -> void:
    ui_sfx_player.play()


func _play_page_sfx() -> void:
    page_sfx_player.play()


func _center_desktop_window() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    var window_size := DisplayServer.window_get_size()
    var centered := usable_rect.position + (usable_rect.size - window_size) / 2
    DisplayServer.window_set_position(centered)
