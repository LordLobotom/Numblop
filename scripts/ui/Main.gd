extends Control

@onready var home_screen: HomeScreen = %HomeScreen
@onready var map_screen: MapScreen = %MapScreen
@onready var settings_screen: SettingsScreen = %SettingsScreen
@onready var cosmetics_screen: CosmeticsScreen = %CosmeticsScreen
@onready var trophy_screen: TrophyScreen = %TrophyScreen
@onready var practice_screen: PracticeScreen = %PracticeScreen
@onready var reward_screen: RewardScreen = %RewardScreen
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var ui_sfx_player: AudioStreamPlayer = %UiSfxPlayer
@onready var answer_sfx_player: AudioStreamPlayer = %AnswerSfxPlayer
@onready var correct_sfx_player: AudioStreamPlayer = %CorrectSfxPlayer
@onready var page_sfx_player: AudioStreamPlayer = %PageSfxPlayer
@onready var milestone_sfx_player: AudioStreamPlayer = %MilestoneSfxPlayer
@onready var coin_sfx_player: AudioStreamPlayer = %CoinSfxPlayer

var _pending_unlocked_table := 0
var _web_audio_unlocked := false


func _ready() -> void:
    home_screen.play_requested.connect(_on_play_requested)
    home_screen.map_requested.connect(_on_map_requested)
    home_screen.outfit_requested.connect(_on_cosmetics_requested)
    home_screen.trophy_requested.connect(_on_trophy_requested)
    home_screen.settings_requested.connect(_on_settings_requested)
    map_screen.return_home_requested.connect(_on_map_return_requested)
    map_screen.outfit_requested.connect(_on_cosmetics_requested)
    map_screen.trophy_requested.connect(_on_trophy_requested)
    map_screen.settings_requested.connect(_on_settings_requested)
    map_screen.fact_detail_opened.connect(_play_confirm_sfx)
    settings_screen.home_requested.connect(_on_settings_home_requested)
    settings_screen.map_requested.connect(_on_settings_map_requested)
    settings_screen.outfit_requested.connect(_on_cosmetics_requested)
    settings_screen.trophy_requested.connect(_on_trophy_requested)
    settings_screen.exit_requested.connect(_on_exit_requested)
    cosmetics_screen.home_requested.connect(_on_cosmetics_home_requested)
    cosmetics_screen.map_requested.connect(_on_cosmetics_map_requested)
    cosmetics_screen.trophy_requested.connect(_on_trophy_requested)
    cosmetics_screen.settings_requested.connect(_on_settings_requested)
    trophy_screen.home_requested.connect(_on_trophy_home_requested)
    trophy_screen.map_requested.connect(_on_map_requested)
    trophy_screen.outfit_requested.connect(_on_cosmetics_requested)
    trophy_screen.settings_requested.connect(_on_settings_requested)
    practice_screen.answer_submitted.connect(_on_answer_submitted)
    practice_screen.exit_requested.connect(_on_practice_exit_requested)
    reward_screen.return_home_requested.connect(_on_reward_return_requested)
    EventBus.session_interrupted.connect(_on_session_interrupted)
    EventBus.table_unlocked.connect(_on_table_unlocked)
    EventBus.back_requested.connect(_on_back_requested)
    music_player.finished.connect(_on_music_finished)
    if not music_player.playing:
        music_player.play()
    if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
        call_deferred("_center_desktop_window")


func _input(event: InputEvent) -> void:
    if OS.has_feature("web"):
        _unlock_web_audio(event)


func _unlock_web_audio(event: InputEvent) -> void:
    if _web_audio_unlocked or not _is_audio_unlock_event(event):
        return
    _web_audio_unlocked = true
    music_player.stop()
    music_player.play()


func _is_audio_unlock_event(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        return event.pressed
    if event is InputEventMouseButton:
        return event.pressed
    if event is InputEventKey:
        return event.pressed and not event.echo
    return false


func _on_play_requested() -> void:
    _play_page_sfx()
    var questions := AppState.begin_session()
    home_screen.visible = false
    trophy_screen.visible = false
    practice_screen.visible = true
    practice_screen.show_question(questions[0], 0, questions.size())


func _on_answer_submitted(value: int, elapsed_seconds: float) -> void:
    answer_sfx_player.play()
    var record := AppState.submit_answer(value, elapsed_seconds)
    var milestone := AppState.consume_answer_milestone()
    if not milestone.is_empty():
        _play_mastery_milestone_sfx()
    elif record.correct:
        correct_sfx_player.play()
    var result := AppState.active_session_result
    var reward: Dictionary = {}
    if result.is_complete():
        reward = AppState.claim_completed_session_reward()
    await practice_screen.show_answer_feedback(record, milestone)
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
    _show_pending_unlock_or_home()


func _on_reward_return_requested() -> void:
    _play_page_sfx()
    reward_screen.visible = false
    if _pending_unlocked_table > 0:
        _show_pending_unlock_or_home()
    else:
        home_screen.visible = true
        home_screen.celebrate_reward()


func _on_session_interrupted() -> void:
    practice_screen.cancel_feedback()
    practice_screen.visible = false
    _show_pending_unlock_or_home()


func _on_table_unlocked(_completed_table: int, new_table: int) -> void:
    _pending_unlocked_table = new_table


func _show_pending_unlock_or_home() -> void:
    if _pending_unlocked_table <= 0:
        home_screen.visible = true
        return
    var unlocked_table := _pending_unlocked_table
    _pending_unlocked_table = 0
    home_screen.visible = false
    map_screen.visible = true
    map_screen.show_table_unlocked(unlocked_table)
    map_screen.set_stage_states(AppState.map_stage_states())


func _on_map_requested() -> void:
    _play_page_sfx()
    map_screen.clear_unlock_announcement()
    map_screen.set_stage_states(AppState.map_stage_states())
    home_screen.visible = false
    cosmetics_screen.visible = false
    settings_screen.visible = false
    trophy_screen.visible = false
    map_screen.visible = true


func _on_map_return_requested() -> void:
    _play_page_sfx()
    map_screen.visible = false
    home_screen.visible = true


func _on_future_feature_requested() -> void:
    _play_confirm_sfx()
    if cosmetics_screen.visible:
        cosmetics_screen.show_future_feature()
    elif map_screen.visible:
        map_screen.show_future_feature()
    else:
        home_screen.show_future_feature()


func _on_back_requested() -> void:
    if trophy_screen.visible:
        _on_trophy_home_requested()
    elif cosmetics_screen.visible:
        _on_cosmetics_home_requested()
    elif settings_screen.visible:
        if not settings_screen.close_exit_confirmation_if_open():
            _on_settings_home_requested()
    elif map_screen.visible:
        if not map_screen.close_detail_if_open():
            _on_map_return_requested()


func _on_settings_requested() -> void:
    _play_page_sfx()
    settings_screen.refresh_from_settings()
    home_screen.visible = false
    map_screen.visible = false
    cosmetics_screen.visible = false
    trophy_screen.visible = false
    settings_screen.visible = true


func _on_settings_home_requested() -> void:
    _play_page_sfx()
    settings_screen.visible = false
    map_screen.visible = false
    trophy_screen.visible = false
    home_screen.visible = true


func _on_settings_map_requested() -> void:
    _play_page_sfx()
    settings_screen.visible = false
    trophy_screen.visible = false
    map_screen.set_stage_states(AppState.map_stage_states())
    map_screen.visible = true


func _on_cosmetics_requested() -> void:
    _play_page_sfx()
    cosmetics_screen.refresh_from_state()
    home_screen.visible = false
    map_screen.visible = false
    settings_screen.visible = false
    trophy_screen.visible = false
    cosmetics_screen.visible = true


func _on_cosmetics_home_requested() -> void:
    _play_page_sfx()
    cosmetics_screen.visible = false
    trophy_screen.visible = false
    home_screen.visible = true


func _on_cosmetics_map_requested() -> void:
    _play_page_sfx()
    cosmetics_screen.visible = false
    trophy_screen.visible = false
    map_screen.clear_unlock_announcement()
    map_screen.set_stage_states(AppState.map_stage_states())
    map_screen.visible = true


func _on_trophy_requested() -> void:
    _play_page_sfx()
    trophy_screen.refresh_from_state()
    home_screen.visible = false
    map_screen.visible = false
    settings_screen.visible = false
    cosmetics_screen.visible = false
    trophy_screen.visible = true


func _on_trophy_home_requested() -> void:
    _play_page_sfx()
    trophy_screen.visible = false
    home_screen.visible = true


func _on_exit_requested() -> void:
    get_tree().quit()


func _on_music_finished() -> void:
    music_player.play()


func _play_confirm_sfx() -> void:
    ui_sfx_player.play()


func _play_page_sfx() -> void:
    page_sfx_player.play()


func _play_mastery_milestone_sfx() -> void:
    milestone_sfx_player.play()
    get_tree().create_timer(0.3).timeout.connect(coin_sfx_player.play)


func _center_desktop_window() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    var window_size := DisplayServer.window_get_size()
    var centered := usable_rect.position + (usable_rect.size - window_size) / 2
    DisplayServer.window_set_position(centered)
