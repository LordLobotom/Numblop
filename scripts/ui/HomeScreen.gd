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
@onready var play_button: TextureButton = %PlayButton
@onready var play_label: Label = %PlayLabel
@onready var map_button: TextureButton = %MapButton
@onready var home_button: TextureButton = %HomeButton
@onready var outfit_button: TextureButton = %OutfitButton
@onready var trophy_button: TextureButton = %TrophyButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var map_label: Label = %MapLabel
@onready var home_label: Label = %HomeLabel
@onready var outfit_label: Label = %OutfitLabel
@onready var trophy_label: Label = %TrophyLabel
@onready var settings_label: Label = %SettingsLabel
@onready var blob: BlobCharacter = %BlobCharacter

var _coins := 0
var _experience := 0
var _level := 1
var _streak := 0


func _ready() -> void:
    play_button.pressed.connect(play_requested.emit)
    map_button.pressed.connect(map_requested.emit)
    outfit_button.pressed.connect(outfit_requested.emit)
    trophy_button.pressed.connect(trophy_requested.emit)
    settings_button.pressed.connect(settings_requested.emit)
    blob.petted.connect(_on_blob_petted)
    var totals: Dictionary = AppState.progress_totals()
    set_progress_totals(
        int(totals["coins"]),
        int(totals["experience"]),
        int(totals["level"])
    )
    EventBus.progress_changed.connect(_on_progress_changed)
    EventBus.streak_changed.connect(_on_streak_changed)
    EventBus.cosmetics_changed.connect(_on_cosmetics_changed)
    set_streak(int(AppState.streak_state().get("current_count", 0)))
    _on_cosmetics_changed(AppState.cosmetics_state())
    _refresh_text()


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


func show_future_feature() -> void:
    pet_hint.text = tr("HOME_FEATURE_LATER")


func _refresh_text() -> void:
    play_label.text = tr("HOME_PLAY")
    pet_hint.text = tr("HOME_PET_HINT")
    outfit_label.text = tr("NAV_OUTFIT")
    map_label.text = tr("NAV_MAP")
    home_label.text = tr("NAV_HOME")
    trophy_label.text = tr("NAV_TROPHY")
    settings_label.text = tr("NAV_SETTINGS")
    play_button.tooltip_text = tr("HOME_PLAY")
    outfit_button.tooltip_text = tr("NAV_OUTFIT")
    map_button.tooltip_text = tr("NAV_MAP")
    home_button.tooltip_text = tr("NAV_HOME")
    trophy_button.tooltip_text = tr("NAV_TROPHY")
    settings_button.tooltip_text = tr("NAV_SETTINGS")
    blob.tooltip_text = tr("HOME_PET_ACCESSIBLE")
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
