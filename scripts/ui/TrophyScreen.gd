class_name TrophyScreen
extends Control

signal home_requested
signal map_requested
signal outfit_requested
signal settings_requested

const TROPHY_TEXTURE: Texture2D = preload("res://ui/crests/crest_trophy.png")
const COIN_TEXTURE: Texture2D = preload("res://ui/crests/crest_coin.png")
const BOLD_FONT: Font = preload("res://ui/fonts/Baloo2Bold.tres")

const CARD_HEIGHT := 92.0
const ICON_TILE_SIZE := 64.0
const LOCKED_ICON_MODULATE := Color(1.0, 1.0, 1.0, 0.45)

@onready var title_label: Label = %TitleLabel
@onready var best_label: Label = %BestLabel
@onready var achievement_list: VBoxContainer = %AchievementList
@onready var navigation: NavBar = $SafeArea/Content/Navigation

var _state: Dictionary = {}


func _ready() -> void:
    navigation.outfit_requested.connect(outfit_requested.emit)
    navigation.map_requested.connect(map_requested.emit)
    navigation.home_requested.connect(home_requested.emit)
    navigation.settings_requested.connect(settings_requested.emit)
    EventBus.streak_changed.connect(_on_streak_changed)
    EventBus.achievements_unlocked.connect(_on_achievements_unlocked)
    refresh_from_state()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _rebuild_achievements()


func refresh_from_state() -> void:
    set_presentation_state(AppState.achievements_state())


func set_presentation_state(state: Dictionary) -> void:
    _state = state.duplicate(true)
    if not is_node_ready():
        return
    _refresh_text()
    _rebuild_achievements()


func _refresh_text() -> void:
    title_label.text = tr("TROPHY_TITLE")
    best_label.text = tr("TROPHY_BEST").format({
        "count": int(_state.get("best_streak", 0)),
    })


func _rebuild_achievements() -> void:
    for child in achievement_list.get_children():
        achievement_list.remove_child(child)
        child.queue_free()
    var entries: Variant = _state.get("achievements", [])
    if entries is not Array:
        return
    for entry in entries:
        if entry is Dictionary:
            achievement_list.add_child(_achievement_card(entry))


func _achievement_card(entry: Dictionary) -> PanelContainer:
    var completed := bool(entry.get("completed", false))
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
    card.add_theme_stylebox_override("panel", _card_style(completed))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)
    row.add_child(_icon_tile(completed))

    var details := VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    details.add_theme_constant_override("separation", 2)
    row.add_child(details)

    var format_args: Variant = entry.get("format_args", {})
    var title := Label.new()
    title.add_theme_font_override("font", BOLD_FONT)
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override(
        "font_color",
        Color(0.25, 0.42, 0.19) if completed else Color(0.32, 0.25, 0.08)
    )
    title.text = _translate(String(entry.get("title_key", "")), format_args)
    details.add_child(title)

    var description := Label.new()
    description.add_theme_font_size_override("font_size", 14)
    description.add_theme_color_override("font_color", Color(0.35, 0.43, 0.37))
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.text = _translate(String(entry.get("description_key", "")), format_args)
    details.add_child(description)

    details.add_child(_footer_row(entry, completed))
    return card


func _icon_tile(completed: bool) -> PanelContainer:
    var tile := PanelContainer.new()
    tile.custom_minimum_size = Vector2(ICON_TILE_SIZE, ICON_TILE_SIZE)
    tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    tile.add_theme_stylebox_override("panel", _icon_tile_style(completed))

    # Placeholder art: every achievement shares the trophy crest until dedicated icons exist.
    var icon := TextureRect.new()
    icon.texture = TROPHY_TEXTURE
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.modulate = Color.WHITE if completed else LOCKED_ICON_MODULATE
    tile.add_child(icon)
    return tile


func _footer_row(entry: Dictionary, completed: bool) -> HBoxContainer:
    var target := maxi(1, int(entry.get("target", 1)))
    var progress := clampi(int(entry.get("progress", 0)), 0, target)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 6)

    var progress_label := Label.new()
    progress_label.add_theme_font_override("font", BOLD_FONT)
    progress_label.add_theme_font_size_override("font_size", 14)
    progress_label.add_theme_color_override(
        "font_color",
        Color(0.25, 0.42, 0.19) if completed else Color(0.4, 0.35, 0.2)
    )
    progress_label.text = tr("TROPHY_ACHIEVEMENT_PROGRESS").format({
        "current": progress,
        "target": target,
    })
    footer.add_child(progress_label)

    if target > 1:
        var bar := ProgressBar.new()
        bar.custom_minimum_size = Vector2(0.0, 10.0)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        bar.max_value = target
        bar.value = progress
        bar.show_percentage = false
        bar.add_theme_stylebox_override("background", _bar_style(Color(0.85, 0.85, 0.81)))
        bar.add_theme_stylebox_override(
            "fill",
            _bar_style(Color(0.42, 0.78, 0.18) if completed else Color(0.98, 0.72, 0.22))
        )
        footer.add_child(bar)
    else:
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footer.add_child(spacer)

    var reward_label := Label.new()
    reward_label.add_theme_font_override("font", BOLD_FONT)
    reward_label.add_theme_font_size_override("font_size", 15)
    reward_label.add_theme_color_override("font_color", Color(0.56, 0.35, 0.05))
    reward_label.text = str(int(entry.get("reward_coins", 0)))
    reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    footer.add_child(reward_label)

    var coin := TextureRect.new()
    coin.custom_minimum_size = Vector2(18.0, 18.0)
    coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    coin.texture = COIN_TEXTURE
    coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coin.modulate = Color.WHITE if completed else LOCKED_ICON_MODULATE
    footer.add_child(coin)
    return footer


func _card_style(completed: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.93, 0.99, 0.9, 0.94) if completed else Color(1.0, 1.0, 1.0, 0.84)
    style.border_width_left = 3 if completed else 0
    style.border_width_top = 3 if completed else 0
    style.border_width_right = 3 if completed else 0
    style.border_width_bottom = 3 if completed else 0
    style.border_color = Color(0.43, 0.79, 0.19)
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_right = 18
    style.corner_radius_bottom_left = 18
    style.content_margin_left = 10.0
    style.content_margin_top = 8.0
    style.content_margin_right = 12.0
    style.content_margin_bottom = 8.0
    style.shadow_color = Color(0.12, 0.24, 0.2, 0.16)
    style.shadow_size = 4
    return style


func _icon_tile_style(completed: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 0.95, 0.72, 0.96) if completed else Color(0.9, 0.91, 0.88, 0.9)
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_right = 14
    style.corner_radius_bottom_left = 14
    style.content_margin_left = 6.0
    style.content_margin_top = 6.0
    style.content_margin_right = 6.0
    style.content_margin_bottom = 6.0
    return style


func _bar_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    return style


func _translate(key: String, format_args: Variant) -> String:
    if key.is_empty():
        return ""
    var text := tr(key)
    if format_args is Dictionary and not (format_args as Dictionary).is_empty():
        return text.format(format_args)
    return text


func _on_streak_changed(_current_count: int, _all_time_high: int) -> void:
    refresh_from_state()


func _on_achievements_unlocked(_entries: Array) -> void:
    refresh_from_state()
