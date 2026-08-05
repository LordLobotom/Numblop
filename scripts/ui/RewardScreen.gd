class_name RewardScreen
extends Control

signal return_home_requested

const REQUIRED_TAPS := 1
## The finished summary stays up long enough to read; a tap anywhere skips the rest of the wait.
const AUTO_RETURN_DELAY_SECONDS := 8.0
## Rows beyond this stay in the list but need a scroll, so the panel never crowds the chest.
const VISIBLE_MASTERY_ROWS := 3
const MASTERY_ROW_HEIGHT := 30.0
const MASTERY_ROW_DELAY_SECONDS := 0.12

const BREAKDOWN_ROW_HEIGHT := 26.0
const BREAKDOWN_ROW_DELAY_SECONDS := 0.14
## Keeps the coin payout off the same frame as the experience sound.
const PAYOUT_SFX_DELAY_SECONDS := 0.18

const BOLD_FONT: Font = preload("res://ui/fonts/Baloo2Bold.tres")
const COIN_TEXTURE: Texture2D = preload("res://ui/crests/crest_coin.png")
const TROPHY_TEXTURE: Texture2D = preload("res://ui/crests/crest_trophy.png")

enum Phase {
    TAPPING,
    OPENING,
    COUNTING,
    READY_TO_RETURN,
}

@onready var title_label: Label = %TitleLabel
@onready var tap_hint: Label = %TapHint
@onready var chest_button: TextureButton = %ChestButton
@onready var skip_button: Button = %SkipButton
@onready var opened_chest: TextureRect = %OpenedChest
@onready var reward_panel: Control = %RewardPanel
@onready var mastery_panel: PanelContainer = %MasteryPanel
@onready var mastery_title: Label = %MasteryTitle
@onready var mastery_list: VBoxContainer = %MasteryList
@onready var breakdown_list: VBoxContainer = %BreakdownList
@onready var breakdown_separator: HSeparator = %BreakdownSeparator
@onready var total_reward_label: Label = %TotalRewardLabel
@onready var xp_reward_label: Label = %XpRewardLabel
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
@onready var payout_player: AudioStreamPlayer = %PayoutPlayer

var phase := Phase.TAPPING
var accepted_taps := 0
var _reward: Dictionary = {}
var _tap_locked := false
var _returned := false


func _ready() -> void:
    chest_button.pressed.connect(_on_chest_pressed)
    skip_button.pressed.connect(_on_skip_pressed)
    _refresh_text()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func start_reward(reward: Dictionary) -> void:
    _reward = reward.duplicate(true)
    phase = Phase.TAPPING
    accepted_taps = 0
    _tap_locked = false
    _returned = false
    skip_button.visible = false
    chest_button.visible = true
    chest_button.disabled = false
    chest_button.rotation = 0.0
    chest_button.scale = Vector2.ONE
    opened_chest.visible = false
    reward_panel.visible = false
    mastery_panel.visible = false
    _clear_mastery_list()
    _clear_breakdown_list()
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
    SettingsManager.play_haptic(SettingsManager.HAPTIC_TAP)
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
    # The payoff of the whole round, and the strongest buzz in the game.
    SettingsManager.play_haptic(SettingsManager.HAPTIC_CELEBRATION)
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
    await _reveal_mastery_gains()
    await _count_rewards()


## Pops one row per improved fact into the space above the chest, largest gain first.
func _reveal_mastery_gains() -> void:
    if not _build_mastery_list():
        return
    for row in mastery_list.get_children():
        row.modulate = Color(1.0, 1.0, 1.0, 0.0)
    for row in mastery_list.get_children():
        create_tween().tween_property(row, "modulate", Color.WHITE, 0.2) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        await get_tree().create_timer(MASTERY_ROW_DELAY_SECONDS).timeout


## Fills the summary panel and reports whether there was anything to show.
func _build_mastery_list() -> bool:
    _clear_mastery_list()
    var gains: Variant = _reward.get("mastery_gains", [])
    if gains is not Array or (gains as Array).is_empty():
        mastery_panel.visible = false
        return false

    mastery_title.text = tr("REWARD_MASTERY_TITLE")
    mastery_panel.visible = true
    # The panel holds a few rows at a time; anything beyond that stays reachable by scrolling.
    var visible_rows := mini((gains as Array).size(), VISIBLE_MASTERY_ROWS)
    # Panel chrome (margins, title, separations) plus one row height and gap per visible row.
    mastery_panel.custom_minimum_size.y = 56.0 + (MASTERY_ROW_HEIGHT + 4.0) * float(visible_rows)
    for raw_gain in gains:
        if raw_gain is Dictionary:
            mastery_list.add_child(_mastery_row(raw_gain))
    return true


## Deterministic opened state for captures: no tweens, no timers, no auto-return.
func preview_opened_state(reward: Dictionary) -> void:
    start_reward(reward)
    phase = Phase.READY_TO_RETURN
    _returned = false
    skip_button.visible = true
    chest_button.visible = false
    chest_button.disabled = true
    opened_chest.visible = true
    tap_hint.visible = true
    tap_hint.text = tr("REWARD_TAP_CONTINUE")
    title_label.text = tr("REWARD_OPENED")
    _build_mastery_list()
    reward_panel.visible = true
    _refresh_reward_labels()
    _build_breakdown_list()
    coins_earned.text = "+%d" % _total_reward_coins()
    xp_earned.text = "+%d" % int(_reward.get("experience", 0))
    coins_total.text = tr("REWARD_COINS_TOTAL").format({
        "count": int(_reward.get("total_coins", 0)),
    })
    xp_total.text = tr("REWARD_XP_TOTAL").format({
        "count": int(_reward.get("total_experience", 0)),
    })
    level_total.text = tr("HOME_LEVEL").format({"level": int(_reward.get("level", 1))})


func _mastery_row(gain: Dictionary) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0.0, MASTERY_ROW_HEIGHT)
    row.add_theme_constant_override("separation", 8)

    var fact := Label.new()
    fact.custom_minimum_size = Vector2(72.0, 0.0)
    fact.add_theme_font_override("font", BOLD_FONT)
    fact.add_theme_font_size_override("font_size", 17)
    fact.add_theme_color_override("font_color", Color(0.32, 0.25, 0.08))
    fact.text = tr("REWARD_MASTERY_FACT").format({
        "table": int(gain.get("table_value", 0)),
        "multiplier": int(gain.get("multiplier", 0)),
    })
    fact.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(fact)

    # A dot scale rather than "45 -> 53": the numbers mean nothing to a child, but a dot
    # filling up does. They stay reachable as the tooltip for anyone who wants them.
    var before := int(gain.get("mastery_before", 0))
    var after := int(gain.get("mastery_after", 0))
    var meter := MasteryMeter.new()
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.tooltip_text = tr("REWARD_MASTERY_CHANGE").format({
        "before": before,
        "after": after,
    })
    meter.set_progress(before, after)
    row.add_child(meter)

    var gained := Label.new()
    gained.add_theme_font_override("font", BOLD_FONT)
    gained.add_theme_font_size_override("font_size", 17)
    gained.add_theme_color_override("font_color", Color(0.25, 0.55, 0.16))
    gained.text = tr("REWARD_MASTERY_GAIN").format({
        "gained": int(gain.get("mastery_gained", 0)),
    })
    gained.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    gained.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(gained)
    return row


func _clear_mastery_list() -> void:
    for child in mastery_list.get_children():
        mastery_list.remove_child(child)
        child.queue_free()


## Names every coin earning of the round: the round reward, the mastery bonus, and one line per
## achievement unlocked by this round. The total row below sums exactly these lines.
func _build_breakdown_list() -> void:
    _clear_breakdown_list()
    breakdown_list.add_child(_breakdown_row(
        COIN_TEXTURE,
        tr("REWARD_ROUND"),
        int(_reward.get("coins", 0)),
        Color(0.56, 0.35, 0.05)
    ))

    var bonus_coins := int(_reward.get("bonus_coins", 0))
    if bonus_coins > 0:
        breakdown_list.add_child(_breakdown_row(
            COIN_TEXTURE,
            tr("REWARD_MASTERY_BONUS"),
            bonus_coins,
            Color(0.25, 0.55, 0.16)
        ))

    var achievements: Variant = _reward.get("achievements", [])
    if achievements is Array:
        for entry in achievements:
            if entry is not Dictionary:
                continue
            breakdown_list.add_child(_breakdown_row(
                TROPHY_TEXTURE,
                _achievement_title(entry),
                int(entry.get("reward_coins", 0)),
                Color(0.25, 0.42, 0.19)
            ))

    breakdown_separator.visible = breakdown_list.get_child_count() > 0


func _breakdown_row(
    icon_texture: Texture2D,
    label_text: String,
    coins: int,
    accent: Color
) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0.0, BREAKDOWN_ROW_HEIGHT)
    row.add_theme_constant_override("separation", 8)

    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(20.0, 20.0)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.texture = icon_texture
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)

    var name_label := Label.new()
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", 16)
    name_label.add_theme_color_override("font_color", Color(0.34, 0.31, 0.22))
    name_label.text = label_text
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(name_label)

    var coins_label := Label.new()
    coins_label.add_theme_font_override("font", BOLD_FONT)
    coins_label.add_theme_font_size_override("font_size", 17)
    coins_label.add_theme_color_override("font_color", accent)
    coins_label.text = tr("REWARD_COINS_GAIN").format({"count": coins})
    coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(coins_label)
    return row


func _achievement_title(entry: Dictionary) -> String:
    var key := String(entry.get("title_key", ""))
    if key.is_empty():
        return tr("REWARD_ACHIEVEMENT_BONUS")
    var text := tr(key)
    var format_args: Variant = entry.get("format_args", {})
    if format_args is Dictionary and not (format_args as Dictionary).is_empty():
        return text.format(format_args)
    return text


## Total coins the round actually paid out; falls back to the round reward on older payloads.
func _total_reward_coins() -> int:
    if _reward.has("total_reward_coins"):
        return maxi(0, int(_reward["total_reward_coins"]))
    return int(_reward.get("coins", 0))


func _play_payout_after(delay_seconds: float) -> void:
    if delay_seconds <= 0.0:
        payout_player.play()
        return
    get_tree().create_timer(delay_seconds).timeout.connect(payout_player.play)


func _clear_breakdown_list() -> void:
    breakdown_separator.visible = false
    for child in breakdown_list.get_children():
        breakdown_list.remove_child(child)
        child.queue_free()


func _refresh_reward_labels() -> void:
    total_reward_label.text = tr("REWARD_TOTAL")
    xp_reward_label.text = tr("REWARD_XP_EARNED")


func _count_rewards() -> void:
    phase = Phase.COUNTING
    title_label.text = tr("REWARD_OPENED")
    tap_hint.visible = false
    reward_panel.visible = true
    _refresh_reward_labels()
    coins_earned.text = "+0"
    xp_earned.text = "+0"
    coins_total.text = tr("REWARD_COINS_TOTAL").format({"count": _previous_total("coins")})
    xp_total.text = tr("REWARD_XP_TOTAL").format({"count": _previous_total("experience")})
    level_total.text = tr("HOME_LEVEL").format({"level": int(_reward.get("level", 1))})

    # Each earning is named on its own line before the running total lands on the sum.
    _build_breakdown_list()
    for row in breakdown_list.get_children():
        row.modulate = Color(1.0, 1.0, 1.0, 0.0)
    for row in breakdown_list.get_children():
        coin_player.play()
        create_tween().tween_property(row, "modulate", Color.WHITE, 0.2) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        await get_tree().create_timer(BREAKDOWN_ROW_DELAY_SECONDS).timeout

    # The whole round's coins land here, so this gets the fuller payout sound rather
    # than the single-coin tick used for the breakdown lines above. Offset from the XP
    # sound, which used to start on the very same frame.
    xp_player.play()
    _play_payout_after(PAYOUT_SFX_DELAY_SECONDS)
    var count_up := create_tween().set_parallel(true)
    count_up.tween_method(_set_coin_count, 0, _total_reward_coins(), 0.8)
    count_up.tween_method(_set_xp_count, 0, int(_reward.get("experience", 0)), 0.8)
    await count_up.finished
    coins_total.text = tr("REWARD_COINS_TOTAL").format({
        "count": int(_reward.get("total_coins", 0)),
    })
    xp_total.text = tr("REWARD_XP_TOTAL").format({
        "count": int(_reward.get("total_experience", 0)),
    })
    phase = Phase.READY_TO_RETURN
    # Everything is revealed: hold the finished page, and let a tap anywhere cut the wait short.
    skip_button.visible = true
    tap_hint.visible = true
    tap_hint.text = tr("REWARD_TAP_CONTINUE")
    await get_tree().create_timer(AUTO_RETURN_DELAY_SECONDS).timeout
    _return_home()


func _on_skip_pressed() -> void:
    if phase != Phase.READY_TO_RETURN:
        return
    chest_tap_player.play()
    _return_home()


func _return_home() -> void:
    if _returned or phase != Phase.READY_TO_RETURN:
        return
    _returned = true
    skip_button.visible = false
    return_home_requested.emit()


func _set_coin_count(value: int) -> void:
    coins_earned.text = "+%d" % value


func _set_xp_count(value: int) -> void:
    xp_earned.text = "+%d" % value


## The wallet before this round: bonus and achievement coins were already banked as they were
## earned, so the coin total has to walk back the full payout rather than the round reward alone.
func _previous_total(kind: String) -> int:
    if kind == "coins":
        return maxi(0, int(_reward.get("total_coins", 0)) - _total_reward_coins())
    return maxi(0, int(_reward.get("total_experience", 0)) - int(_reward.get("experience", 0)))


func _update_tap_hint() -> void:
    tap_hint.visible = true
    tap_hint.text = tr("REWARD_TAP_PROGRESS")


func _refresh_text() -> void:
    title_label.text = tr("REWARD_TITLE") if phase == Phase.TAPPING else title_label.text
    chest_button.tooltip_text = tr("REWARD_CHEST_ACCESSIBLE")
    skip_button.tooltip_text = tr("REWARD_TAP_CONTINUE")
    if phase == Phase.TAPPING:
        _update_tap_hint()
    elif phase == Phase.READY_TO_RETURN:
        tap_hint.text = tr("REWARD_TAP_CONTINUE")
