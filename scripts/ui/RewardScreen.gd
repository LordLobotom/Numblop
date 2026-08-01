class_name RewardScreen
extends Control

signal return_home_requested

const REQUIRED_TAPS := 1
const AUTO_RETURN_DELAY_SECONDS := 1.25

enum Phase {
    TAPPING,
    OPENING,
    COUNTING,
    READY_TO_RETURN,
}

@onready var title_label: Label = %TitleLabel
@onready var tap_hint: Label = %TapHint
@onready var chest_button: TextureButton = %ChestButton
@onready var opened_chest: TextureRect = %OpenedChest
@onready var reward_panel: Control = %RewardPanel
@onready var coins_earned: Label = %CoinsEarned
@onready var xp_earned: Label = %XpEarned
@onready var coins_total: Label = %CoinsTotal
@onready var xp_total: Label = %XpTotal
@onready var level_total: Label = %LevelTotal
@onready var fanfare_player: AudioStreamPlayer = %FanfarePlayer
@onready var reward_player: AudioStreamPlayer = %RewardPlayer
@onready var xp_player: AudioStreamPlayer = %XpPlayer
@onready var chest_tap_player: AudioStreamPlayer = %ChestTapPlayer
@onready var coin_player: AudioStreamPlayer = %CoinPlayer

var phase := Phase.TAPPING
var accepted_taps := 0
var _reward: Dictionary = {}
var _tap_locked := false


func _ready() -> void:
    chest_button.pressed.connect(_on_chest_pressed)
    _refresh_text()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func start_reward(reward: Dictionary) -> void:
    _reward = reward.duplicate(true)
    phase = Phase.TAPPING
    accepted_taps = 0
    _tap_locked = false
    chest_button.visible = true
    chest_button.disabled = false
    chest_button.rotation = 0.0
    chest_button.scale = Vector2.ONE
    opened_chest.visible = false
    reward_panel.visible = false
    title_label.text = tr("REWARD_TITLE")
    _update_tap_hint()
    if not fanfare_player.playing:
        fanfare_player.play()


func _on_chest_pressed() -> void:
    if phase != Phase.TAPPING or _tap_locked:
        return
    _tap_locked = true
    accepted_taps += 1
    chest_tap_player.play()
    Input.vibrate_handheld(35)
    _update_tap_hint()
    await _shake_chest()
    if accepted_taps == REQUIRED_TAPS:
        await _open_and_count()
    else:
        _tap_locked = false


func _shake_chest() -> void:
    chest_button.pivot_offset = chest_button.size / 2.0
    var direction := -1.0 if accepted_taps % 2 == 0 else 1.0
    var shake := create_tween()
    shake.tween_property(chest_button, "rotation", 0.07 * direction, 0.06)
    shake.tween_property(chest_button, "rotation", -0.07 * direction, 0.08)
    shake.tween_property(chest_button, "rotation", 0.0, 0.06)
    await shake.finished


func _open_and_count() -> void:
    phase = Phase.OPENING
    chest_button.disabled = true
    reward_player.play()
    var squash := create_tween()
    squash.tween_property(chest_button, "scale", Vector2(1.08, 0.9), 0.12)
    squash.tween_property(chest_button, "scale", Vector2.ONE, 0.16) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await squash.finished
    chest_button.visible = false
    opened_chest.visible = true
    opened_chest.pivot_offset = opened_chest.size / 2.0
    opened_chest.scale = Vector2(0.72, 0.72)
    var reveal := create_tween()
    reveal.tween_property(opened_chest, "scale", Vector2.ONE, 0.3) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await reveal.finished
    await _count_rewards()


func _count_rewards() -> void:
    phase = Phase.COUNTING
    title_label.text = tr("REWARD_OPENED")
    tap_hint.visible = false
    reward_panel.visible = true
    coins_earned.text = "+0"
    xp_earned.text = "+0"
    coins_total.text = tr("REWARD_COINS_TOTAL").format({"count": _previous_total("coins")})
    xp_total.text = tr("REWARD_XP_TOTAL").format({"count": _previous_total("experience")})
    level_total.text = tr("HOME_LEVEL").format({"level": int(_reward.get("level", 1))})
    xp_player.play()
    coin_player.play()
    var count_up := create_tween().set_parallel(true)
    count_up.tween_method(_set_coin_count, 0, int(_reward.get("coins", 0)), 0.8)
    count_up.tween_method(_set_xp_count, 0, int(_reward.get("experience", 0)), 0.8)
    await count_up.finished
    coins_total.text = tr("REWARD_COINS_TOTAL").format({
        "count": int(_reward.get("total_coins", 0)),
    })
    xp_total.text = tr("REWARD_XP_TOTAL").format({
        "count": int(_reward.get("total_experience", 0)),
    })
    phase = Phase.READY_TO_RETURN
    await get_tree().create_timer(AUTO_RETURN_DELAY_SECONDS).timeout
    if phase == Phase.READY_TO_RETURN:
        return_home_requested.emit()


func _set_coin_count(value: int) -> void:
    coins_earned.text = "+%d" % value


func _set_xp_count(value: int) -> void:
    xp_earned.text = "+%d" % value


func _previous_total(kind: String) -> int:
    var total_key := "total_coins" if kind == "coins" else "total_experience"
    return maxi(0, int(_reward.get(total_key, 0)) - int(_reward.get(kind, 0)))


func _update_tap_hint() -> void:
    tap_hint.visible = true
    tap_hint.text = tr("REWARD_TAP_PROGRESS")


func _refresh_text() -> void:
    title_label.text = tr("REWARD_TITLE") if phase == Phase.TAPPING else title_label.text
    chest_button.tooltip_text = tr("REWARD_CHEST_ACCESSIBLE")
    if phase == Phase.TAPPING:
        _update_tap_hint()
