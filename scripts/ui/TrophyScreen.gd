class_name TrophyScreen
extends Control

signal home_requested
signal map_requested
signal outfit_requested
signal settings_requested

const FLAME_TEXTURE: Texture2D = preload("res://ui/crests/crest_flame.png")
const BOLD_FONT: Font = preload("res://ui/fonts/FredokaBold.tres")

@onready var title_label: Label = %TitleLabel
@onready var current_label: Label = %CurrentLabel
@onready var best_label: Label = %BestLabel
@onready var empty_label: Label = %EmptyLabel
@onready var milestone_list: VBoxContainer = %MilestoneList
@onready var outfit_button: TextureButton = %OutfitButton
@onready var map_button: TextureButton = %MapButton
@onready var home_button: TextureButton = %HomeButton
@onready var trophy_button: TextureButton = %TrophyButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var outfit_label: Label = %OutfitLabel
@onready var map_label: Label = %MapLabel
@onready var home_label: Label = %HomeLabel
@onready var trophy_label: Label = %TrophyLabel
@onready var settings_label: Label = %SettingsLabel

var _state: Dictionary = {}


func _ready() -> void:
    outfit_button.pressed.connect(outfit_requested.emit)
    map_button.pressed.connect(map_requested.emit)
    home_button.pressed.connect(home_requested.emit)
    settings_button.pressed.connect(settings_requested.emit)
    EventBus.streak_changed.connect(_on_streak_changed)
    refresh_from_state()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _rebuild_milestones()


func refresh_from_state() -> void:
    set_presentation_state(AppState.streak_state())


func set_presentation_state(state: Dictionary) -> void:
    _state = state.duplicate(true)
    if not is_node_ready():
        return
    _refresh_text()
    _rebuild_milestones()


func _refresh_text() -> void:
    title_label.text = tr("TROPHY_TITLE")
    current_label.text = tr("TROPHY_CURRENT").format({
        "count": int(_state.get("current_count", 0)),
    })
    best_label.text = tr("TROPHY_BEST").format({
        "count": int(_state.get("all_time_high", 0)),
    })
    empty_label.text = tr("TROPHY_EMPTY")
    outfit_label.text = tr("NAV_OUTFIT")
    map_label.text = tr("NAV_MAP")
    home_label.text = tr("NAV_HOME")
    trophy_label.text = tr("NAV_TROPHY")
    settings_label.text = tr("NAV_SETTINGS")
    outfit_button.tooltip_text = tr("NAV_OUTFIT")
    map_button.tooltip_text = tr("NAV_MAP")
    home_button.tooltip_text = tr("NAV_HOME")
    trophy_button.tooltip_text = tr("NAV_TROPHY")
    settings_button.tooltip_text = tr("NAV_SETTINGS")


func _rebuild_milestones() -> void:
    for child in milestone_list.get_children():
        if child == empty_label:
            continue
        milestone_list.remove_child(child)
        child.queue_free()
    var milestones: Array = _state.get("milestones", [])
    empty_label.visible = milestones.is_empty()
    for index in range(milestones.size() - 1, -1, -1):
        milestone_list.add_child(_milestone_row(milestones[index]))


func _milestone_row(milestone: Dictionary) -> PanelContainer:
    var row := PanelContainer.new()
    row.custom_minimum_size = Vector2(0.0, 64.0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 0.84)
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_left = 18
    style.corner_radius_bottom_right = 18
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    row.add_theme_stylebox_override("panel", style)

    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 7)
    row.add_child(content)

    var flame := TextureRect.new()
    flame.custom_minimum_size = Vector2(38.0, 38.0)
    flame.texture = FLAME_TEXTURE
    flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(flame)

    var count_label := Label.new()
    count_label.custom_minimum_size = Vector2(54.0, 0.0)
    count_label.add_theme_font_override("font", BOLD_FONT)
    count_label.add_theme_font_size_override("font_size", 23)
    count_label.add_theme_color_override("font_color", Color(0.82, 0.25, 0.06))
    count_label.text = str(int(milestone.get("count", 0)))
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    content.add_child(count_label)

    var date_label := Label.new()
    date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    date_label.add_theme_font_size_override("font_size", 15)
    date_label.add_theme_color_override("font_color", Color(0.28, 0.4, 0.32))
    date_label.text = _format_milestone_time(milestone)
    date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    content.add_child(date_label)
    return row


func _format_milestone_time(milestone: Dictionary) -> String:
    var unix_time := maxi(0, int(milestone.get("ended_at_unix", 0)))
    var offset_seconds := int(milestone.get("utc_offset_minutes", 0)) * 60
    var date_time := Time.get_datetime_dict_from_unix_time(unix_time + offset_seconds)
    return tr("TROPHY_DATE_TIME").format({
        "year": int(date_time["year"]),
        "month": _two_digits(int(date_time["month"])),
        "day": _two_digits(int(date_time["day"])),
        "hour": _two_digits(int(date_time["hour"])),
        "minute": _two_digits(int(date_time["minute"])),
    })


func _two_digits(value: int) -> String:
    return "%02d" % value


func _on_streak_changed(_current_count: int, _all_time_high: int) -> void:
    refresh_from_state()
