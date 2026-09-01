class_name HomeScreen
extends Control

signal play_requested
signal map_requested
signal outfit_requested
signal trophy_requested
signal settings_requested

@onready var coins_label: Label = %CoinsLabel
@onready var xp_label: Label = %XpLabel
@onready var level_label: Label = %LevelLabel
@onready var streak_label: Label = %StreakLabel
@onready var pet_hint: Label = %PetHint
@onready var play_button: PlayButton = %PlayButton
@onready var play_label: Label = %PlayLabel
@onready var blob: BlobCharacter = %BlobCharacter
@onready var name_button: Button = %NameButton
@onready var name_dialog: Control = %NameDialog
@onready var name_scrim: ColorRect = %NameScrim
@onready var name_dialog_title: Label = %NameDialogTitle
@onready var name_input: LineEdit = %NameInput
@onready var name_save_button: Button = %NameSaveButton
@onready var name_cancel_button: Button = %NameCancelButton
@onready var navigation: NavBar = $SafeArea/Content/Navigation

var _coins := 0
var _experience := 0
var _level := 1
var _streak := 0
var _nickname_override: Variant = null
var _free_practice_available := false


func _ready() -> void:
    play_button.pressed.connect(play_requested.emit)
    navigation.map_requested.connect(map_requested.emit)
    navigation.outfit_requested.connect(outfit_requested.emit)
    navigation.trophy_requested.connect(trophy_requested.emit)
    navigation.settings_requested.connect(settings_requested.emit)
    blob.petted.connect(_on_blob_petted)
    name_button.pressed.connect(show_name_dialog)
    name_save_button.pressed.connect(_save_nickname)
    name_cancel_button.pressed.connect(hide_name_dialog)
    name_scrim.gui_input.connect(_on_name_scrim_input)
    name_input.text_submitted.connect(func(_text: String) -> void: _save_nickname())
    EventBus.nickname_changed.connect(_on_nickname_changed)
    var totals: Dictionary = AppState.progress_totals()
    set_progress_totals(
        int(totals["coins"]),
        int(totals["experience"]),
        int(totals["level"])
    )
    EventBus.progress_changed.connect(_on_progress_changed)
    EventBus.streak_changed.connect(_on_streak_changed)
    EventBus.cosmetics_changed.connect(_on_cosmetics_changed)
    EventBus.session_ended.connect(refresh_primary_action)
    EventBus.profile_reloaded.connect(refresh_primary_action)
    set_streak(int(AppState.streak_state().get("current_count", 0)))
    _on_cosmetics_changed(AppState.cosmetics_state())
    _refresh_text()
    refresh_primary_action()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func set_progress_totals(coins: int, experience: int, level: int) -> void:
    _coins = maxi(0, coins)
    _experience = maxi(0, experience)
    _level = maxi(1, level)
    if is_node_ready():
        _refresh_progress_text()


func set_streak(count: int) -> void:
    _streak = maxi(0, count)
    if is_node_ready():
        _refresh_progress_text()


func show_session_ready(question_count: int) -> void:
    pet_hint.text = tr("HOME_STATUS_SESSION").format({"count": question_count})


func celebrate_reward() -> void:
    pet_hint.text = tr("HOME_REWARD_REACTION")
    blob.react_to_pet()


func refresh_primary_action() -> void:
    _free_practice_available = bool(
        AppState.practice_setup_state().get("final_table_completed", false)
    )
    if is_node_ready():
        var action_key := "HOME_PRACTICE" if _free_practice_available else "HOME_PLAY"
        play_label.text = tr(action_key)
        play_button.tooltip_text = tr(action_key)


func show_future_feature() -> void:
    pet_hint.text = tr("HOME_FEATURE_LATER")


func present_nickname(nickname: String) -> void:
    _nickname_override = nickname
    if is_node_ready():
        _refresh_name_text()


func show_name_dialog() -> void:
    name_input.text = AppState.nickname()
    name_dialog.visible = true
    name_input.grab_focus()


func hide_name_dialog() -> void:
    name_dialog.visible = false
    name_button.grab_focus()


func close_name_dialog_if_open() -> bool:
    if not name_dialog.visible:
        return false
    hide_name_dialog()
    return true


func _save_nickname() -> void:
    AppState.set_nickname(name_input.text)
    hide_name_dialog()


func _on_name_scrim_input(event: InputEvent) -> void:
    if (
        event is InputEventMouseButton
        and event.button_index == MOUSE_BUTTON_LEFT
        and event.pressed
    ):
        hide_name_dialog()
        name_scrim.accept_event()


func _on_nickname_changed(_nickname: String) -> void:
    _refresh_name_text()


func _refresh_name_text() -> void:
    var nickname: String = (
        _nickname_override if _nickname_override is String else AppState.nickname()
    )
    name_button.text = nickname if not nickname.is_empty() else tr("HOME_PROFILE")
    name_button.tooltip_text = tr("HOME_NAME_EDIT_HINT")
    name_dialog_title.text = tr("NAME_DIALOG_TITLE")
    name_input.placeholder_text = tr("NAME_DIALOG_PLACEHOLDER")
    name_save_button.text = tr("NAME_SAVE")
    name_cancel_button.text = tr("NAME_CANCEL")


func _refresh_text() -> void:
    pet_hint.text = tr("HOME_PET_HINT")
    refresh_primary_action()
    blob.tooltip_text = tr("HOME_PET_ACCESSIBLE")
    _refresh_name_text()
    _refresh_progress_text()


func _refresh_progress_text() -> void:
    coins_label.text = str(_coins)
    xp_label.text = str(_experience)
    level_label.text = tr("HOME_LEVEL").format({"level": _level})
    streak_label.text = str(_streak)
    coins_label.tooltip_text = tr("HOME_COINS").format({"count": _coins})
    xp_label.tooltip_text = tr("HOME_XP").format({"count": _experience})
    streak_label.tooltip_text = tr("HOME_STREAK").format({"count": _streak})


func _on_blob_petted() -> void:
    pet_hint.text = tr("HOME_PET_REACTION")


func _on_progress_changed(coins: int, experience: int, level: int) -> void:
    set_progress_totals(coins, experience, level)


func _on_streak_changed(current_count: int, _all_time_high: int) -> void:
    set_streak(current_count)


func _on_cosmetics_changed(state: Dictionary) -> void:
    blob.apply_cosmetics(state)
