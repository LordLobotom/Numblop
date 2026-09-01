extends Control

const WEB_AUDIO_CONTEXT_STATE_SCRIPT := (
    "typeof GodotAudio !== 'undefined' && GodotAudio.ctx"
    + " ? GodotAudio.ctx.state : 'unavailable'"
)
const WEB_AUDIO_RESUME_SCRIPT := """
(() => {
    if (typeof GodotAudio === 'undefined' || !GodotAudio.ctx) {
        return 'unavailable';
    }
    if (GodotAudio.ctx.state !== 'running') {
        GodotAudio.ctx.resume().catch(() => {});
    }
    return GodotAudio.ctx.state;
})()
"""
const WEB_AUDIO_UNLOCK_VERIFY_DELAY := 0.25

## Offsets that keep celebration sounds from all starting on the same frame. Measured
## from the answer click, which plays the instant an answer is submitted.
const CORRECT_SFX_DELAY_SECONDS := 0.12
const MILESTONE_CHIME_DELAY_SECONDS := 0.18
const MILESTONE_CHEER_DELAY_SECONDS := 0.62
const MILESTONE_COIN_DELAY_SECONDS := 1.24

@onready var home_screen: HomeScreen = %HomeScreen
@onready var map_screen: MapScreen = %MapScreen
@onready var settings_screen: SettingsScreen = %SettingsScreen
@onready var cosmetics_screen: CosmeticsScreen = %CosmeticsScreen
@onready var trophy_screen: TrophyScreen = %TrophyScreen
@onready var practice_setup_screen: PracticeSetupScreen = %PracticeSetupScreen
@onready var practice_screen: PracticeScreen = %PracticeScreen
@onready var reward_screen: RewardScreen = %RewardScreen
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var ui_sfx_player: AudioStreamPlayer = %UiSfxPlayer
@onready var answer_sfx_player: AudioStreamPlayer = %AnswerSfxPlayer
@onready var correct_sfx_player: AudioStreamPlayer = %CorrectSfxPlayer
@onready var page_sfx_player: AudioStreamPlayer = %PageSfxPlayer
@onready var milestone_sfx_player: AudioStreamPlayer = %MilestoneSfxPlayer
@onready var cheer_sfx_player: AudioStreamPlayer = %CheerSfxPlayer
@onready var coin_sfx_player: AudioStreamPlayer = %CoinSfxPlayer

var _pending_unlocked_table := 0
var _web_audio_unlocked := false
var _web_audio_unlock_pending := false
var _practice_setup_from_table := 0


func _ready() -> void:
    _neutralize_pointer_states(DisplayServer.is_touchscreen_available())
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
    map_screen.practice_requested.connect(_on_table_practice_requested)
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
    practice_setup_screen.start_requested.connect(_on_free_practice_start_requested)
    practice_setup_screen.question_count_changed.connect(_on_free_practice_question_count_changed)
    practice_setup_screen.back_requested.connect(_on_practice_setup_back_requested)
    practice_setup_screen.outfit_requested.connect(_on_cosmetics_requested)
    practice_setup_screen.map_requested.connect(_on_map_requested)
    practice_setup_screen.home_requested.connect(_on_practice_setup_home_requested)
    practice_setup_screen.trophy_requested.connect(_on_trophy_requested)
    practice_setup_screen.settings_requested.connect(_on_settings_requested)
    practice_screen.answer_submitted.connect(_on_answer_submitted)
    practice_screen.exit_requested.connect(_on_practice_exit_requested)
    reward_screen.return_home_requested.connect(_on_reward_return_requested)
    EventBus.session_interrupted.connect(_on_session_interrupted)
    EventBus.table_unlocked.connect(_on_table_unlocked)
    EventBus.back_requested.connect(_on_back_requested)
    music_player.finished.connect(_on_music_finished)
    if not OS.has_feature("web") and not music_player.playing:
        music_player.play()
    if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
        call_deferred("_center_desktop_window")


## Android emulates a mouse from touch, and that emulated pointer never leaves: when the
## finger lifts it stays parked on the widget it last tapped, which keeps drawing its hover
## face. The button also keeps focus, and this theme draws focus with the hover box, so the
## highlight outlives the tap twice over -- a child taps a keypad key or a settings tile and
## it stays lit as if still held. A touchscreen has no pointer worth tracking, so hover and
## focus resolve to the resting look there. The theme lives on this node, so patching it
## here reaches every Button that inherits these slots instead of overriding them.
func _neutralize_pointer_states(touchscreen_available: bool) -> void:
    if not touchscreen_available or theme == null:
        return
    # `ui/theme.tres` is a shared cached resource: patching it in place would follow the app
    # into anything else that loads it, so the touch look is a copy this node owns.
    var touch_theme: Theme = theme.duplicate()
    if touch_theme.has_stylebox("normal", "Button"):
        var normal := touch_theme.get_stylebox("normal", "Button")
        touch_theme.set_stylebox("hover", "Button", normal)
        touch_theme.set_stylebox("focus", "Button", normal)
    if touch_theme.has_stylebox("pressed", "Button"):
        touch_theme.set_stylebox(
            "hover_pressed",
            "Button",
            touch_theme.get_stylebox("pressed", "Button")
        )
    theme = touch_theme


func _input(event: InputEvent) -> void:
    if OS.has_feature("web") and _is_audio_unlock_event(event):
        _try_unlock_web_audio()


func _try_unlock_web_audio() -> void:
    if _web_audio_unlock_pending:
        return

    if _web_audio_unlocked:
        if _web_audio_context_state() == "running":
            return
        _web_audio_unlocked = false

    var initial_state := _web_audio_context_state(true)
    if initial_state == "running":
        _finish_web_audio_unlock()
        return

    _web_audio_unlock_pending = true
    music_player.stop()
    music_player.play()
    get_tree().create_timer(WEB_AUDIO_UNLOCK_VERIFY_DELAY).timeout.connect(
        _verify_web_audio_unlock
    )


func _verify_web_audio_unlock() -> void:
    _web_audio_unlock_pending = false
    if _web_audio_context_state() == "running":
        _finish_web_audio_unlock()
        return

    _web_audio_unlocked = false
    music_player.stop()


func _finish_web_audio_unlock() -> void:
    _web_audio_unlocked = true
    if not music_player.playing:
        music_player.play()


func _web_audio_context_state(request_resume := false) -> String:
    var script := WEB_AUDIO_RESUME_SCRIPT if request_resume else WEB_AUDIO_CONTEXT_STATE_SCRIPT
    var state: Variant = JavaScriptBridge.eval(script, false)
    return str(state)


func _is_audio_unlock_event(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        return not event.pressed
    if event is InputEventMouseButton:
        return not event.pressed
    if event is InputEventKey:
        return event.pressed and not event.echo
    return false


func _on_play_requested() -> void:
    _play_page_sfx()
    if bool(AppState.practice_setup_state().get("final_table_completed", false)):
        _open_practice_setup()
        return
    var questions := AppState.begin_session()
    home_screen.visible = false
    trophy_screen.visible = false
    practice_screen.visible = true
    practice_screen.show_question(questions[0], 0, questions.size())


func _on_table_practice_requested(table_value: int) -> void:
    _play_page_sfx()
    _open_practice_setup(table_value)


func _open_practice_setup(origin_table: int = 0) -> void:
    _practice_setup_from_table = origin_table
    practice_setup_screen.present(AppState.practice_setup_state())
    home_screen.visible = false
    map_screen.visible = false
    practice_setup_screen.visible = true


func _on_free_practice_start_requested(
    question_count: int,
    selected_tables: Array[int]
) -> void:
    _play_page_sfx()
    var questions := AppState.begin_free_practice(question_count, selected_tables)
    if questions.is_empty():
        return
    _close_practice_setup()
    practice_screen.visible = true
    practice_screen.show_question(questions[0], 0, questions.size())


func _on_free_practice_question_count_changed(question_count: int) -> void:
    # This is a device preference, not profile progress. A failed settings write must never block
    # navigation or an otherwise valid offline round.
    SettingsManager.set_practice_question_count(question_count)


func _on_practice_setup_back_requested() -> void:
    _play_page_sfx()
    var table_value := _practice_setup_from_table
    _close_practice_setup()
    if table_value > 0:
        map_screen.set_stage_states(AppState.map_stage_states())
        map_screen.visible = true
        map_screen.show_table_details(table_value)
        return
    home_screen.visible = true


func _on_practice_setup_home_requested() -> void:
    _play_page_sfx()
    _close_practice_setup()
    home_screen.visible = true


func _close_practice_setup() -> void:
    practice_setup_screen.visible = false
    _practice_setup_from_table = 0


func _on_answer_submitted(value: int, elapsed_seconds: float) -> void:
    answer_sfx_player.play()
    var record := AppState.submit_answer(value, elapsed_seconds)
    var milestone := AppState.consume_answer_milestone()
    if not milestone.is_empty():
        _play_mastery_milestone_sfx()
    elif record.correct:
        # Offset from the answer click above, which fires on the same frame.
        _play_delayed(correct_sfx_player, CORRECT_SFX_DELAY_SECONDS)
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
    _close_practice_setup()
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
    if practice_setup_screen.visible:
        _on_practice_setup_back_requested()
    elif trophy_screen.visible:
        _on_trophy_home_requested()
    elif cosmetics_screen.visible:
        _on_cosmetics_home_requested()
    elif settings_screen.visible:
        if not settings_screen.close_exit_confirmation_if_open():
            _on_settings_home_requested()
    elif map_screen.visible:
        if not map_screen.close_detail_if_open():
            _on_map_return_requested()
    elif home_screen.visible:
        home_screen.close_name_dialog_if_open()


func _on_settings_requested() -> void:
    _play_page_sfx()
    _close_practice_setup()
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
    _close_practice_setup()
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
    _close_practice_setup()
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


## Spaces the milestone sounds out so they read as one celebration, not one noise.
##
## Submitting an answer already plays its own click, so nothing else starts on the same
## frame: the chime lands just after it, the blob cheers once its popup is on screen,
## and the coins arrive last. The tails still overlap, which is what makes it feel like
## a single moment rather than four separate beeps.
func _play_mastery_milestone_sfx() -> void:
    _play_delayed(milestone_sfx_player, MILESTONE_CHIME_DELAY_SECONDS)
    _play_delayed(cheer_sfx_player, MILESTONE_CHEER_DELAY_SECONDS)
    _play_delayed(coin_sfx_player, MILESTONE_COIN_DELAY_SECONDS)


func _play_delayed(player: AudioStreamPlayer, delay_seconds: float) -> void:
    if delay_seconds <= 0.0:
        player.play()
        return
    get_tree().create_timer(delay_seconds).timeout.connect(player.play)


func _center_desktop_window() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable_rect := DisplayServer.screen_get_usable_rect(screen)
    var window_size := DisplayServer.window_get_size()
    var centered := usable_rect.position + (usable_rect.size - window_size) / 2
    DisplayServer.window_set_position(centered)
