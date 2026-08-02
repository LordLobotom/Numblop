class_name MapScreen
extends Control

signal return_home_requested
signal outfit_requested
signal trophy_requested
signal settings_requested
signal fact_detail_opened

const OPEN_STAGE_TEXTURE: Texture2D = preload(
    "res://ui/crests/crest_map_island_open.png"
)
const CLOSED_STAGE_TEXTURE: Texture2D = preload(
    "res://ui/crests/crest_map_islan_closed.png"
)
const BOLD_FONT: Font = preload("res://ui/fonts/FredokaBold.tres")
const STAGE_SIZE := Vector2(132.0, 132.0)
const STAGE_STEP := 145.0
const MAP_CONTENT_WIDTH := 350.0
const FACT_BUILDING_COLOR := Color(0.9, 0.25, 0.2)
const FACT_PRACTICING_COLOR := Color(0.58, 0.37, 0.78)
const FACT_MASTERED_COLOR := Color(0.95, 0.55, 0.08)
const FACT_AUTOMATED_COLOR := Color(0.27, 0.7, 0.2)

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var scroll: ScrollContainer = %Scroll
@onready var map_canvas: MapPath = %MapCanvas
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
@onready var feature_hint: Label = %FeatureHint
@onready var fact_detail_overlay: Control = %FactDetailOverlay
@onready var dismiss_button: Button = %DismissButton
@onready var fact_detail_close: Button = %FactDetailClose
@onready var fact_detail_title: Label = %FactDetailTitle
@onready var fact_detail_overall: Label = %FactDetailOverall
@onready var fact_grid: GridContainer = %FactGrid
@onready var legend_grid: GridContainer = %LegendGrid

var _stage_states: Array[Dictionary] = []
var _unlocked_table_announcement := 0
var _selected_stage_state: Dictionary = {}


func _ready() -> void:
    home_button.pressed.connect(return_home_requested.emit)
    outfit_button.pressed.connect(outfit_requested.emit)
    trophy_button.pressed.connect(trophy_requested.emit)
    settings_button.pressed.connect(settings_requested.emit)
    dismiss_button.pressed.connect(hide_table_details)
    fact_detail_close.pressed.connect(hide_table_details)
    _refresh_text()
    _rebuild_stages()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _rebuild_stages()


func set_stage_states(stage_states: Array[Dictionary]) -> void:
    hide_table_details()
    _stage_states.clear()
    for stage_state in stage_states:
        _stage_states.append(stage_state.duplicate(true))
    if is_node_ready():
        _rebuild_stages()


func show_table_unlocked(table_value: int) -> void:
    _unlocked_table_announcement = table_value
    if is_node_ready():
        _refresh_text()
        _rebuild_stages()


func clear_unlock_announcement() -> void:
    _unlocked_table_announcement = 0
    if is_node_ready():
        _refresh_text()


func show_future_feature() -> void:
    feature_hint.text = tr("HOME_FEATURE_LATER")


func _refresh_text() -> void:
    title_label.text = tr("MAP_TITLE")
    subtitle_label.text = tr("MAP_SUBTITLE")
    outfit_label.text = tr("NAV_OUTFIT")
    map_label.text = tr("NAV_MAP")
    home_label.text = tr("NAV_HOME")
    trophy_label.text = tr("NAV_TROPHY")
    settings_label.text = tr("NAV_SETTINGS")
    if _unlocked_table_announcement > 0:
        feature_hint.text = tr("MAP_STAGE_UNLOCKED").format({
            "table": _unlocked_table_announcement,
        })
    else:
        feature_hint.text = tr("MAP_HINT")
    outfit_button.tooltip_text = tr("NAV_OUTFIT")
    map_button.tooltip_text = tr("NAV_MAP")
    home_button.tooltip_text = tr("NAV_HOME")
    trophy_button.tooltip_text = tr("NAV_TROPHY")
    settings_button.tooltip_text = tr("NAV_SETTINGS")
    fact_detail_close.tooltip_text = tr("MAP_FACT_DETAIL_CLOSE")
    if fact_detail_overlay.visible and not _selected_stage_state.is_empty():
        _refresh_fact_detail()


func _rebuild_stages() -> void:
    for child in map_canvas.get_children():
        map_canvas.remove_child(child)
        child.queue_free()
    if _stage_states.is_empty():
        map_canvas.set_stage_centers(PackedVector2Array())
        return

    var canvas_width := MAP_CONTENT_WIDTH
    map_canvas.custom_minimum_size.x = MAP_CONTENT_WIDTH
    map_canvas.custom_minimum_size.y = STAGE_STEP * _stage_states.size() + 20.0
    var stage_centers := PackedVector2Array()
    for index in _stage_states.size():
        var stage_state := _stage_states[index]
        var stage_x := 8.0 if index % 2 == 0 else canvas_width - STAGE_SIZE.x - 8.0
        var stage_y := 6.0 + index * STAGE_STEP
        _add_stage(stage_state, Vector2(stage_x, stage_y), index % 2 == 0)
        stage_centers.append(Vector2(stage_x, stage_y) + Vector2(66.0, 72.0))
    map_canvas.set_stage_centers(stage_centers)
    if _unlocked_table_announcement > 0:
        _scroll_to_table.call_deferred(_unlocked_table_announcement)


func _add_stage(stage_state: Dictionary, stage_position: Vector2, stage_on_left: bool) -> void:
    var unlocked := bool(stage_state.get("unlocked", false))
    var completed := bool(stage_state.get("completed", false))
    var current := bool(stage_state.get("current", false))

    var crest := TextureButton.new()
    crest.name = "Stage%d" % int(stage_state.get("table", 0))
    crest.position = stage_position
    crest.size = STAGE_SIZE
    crest.custom_minimum_size = STAGE_SIZE
    crest.focus_mode = Control.FOCUS_ALL
    crest.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    crest.texture_normal = OPEN_STAGE_TEXTURE if unlocked else CLOSED_STAGE_TEXTURE
    crest.texture_disabled = CLOSED_STAGE_TEXTURE
    crest.ignore_texture_size = true
    crest.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    crest.disabled = not unlocked
    var table_value := int(stage_state.get("table", 0))
    if unlocked:
        crest.tooltip_text = tr("MAP_STAGE_OPEN_DETAIL").format({"table": table_value})
        crest.pressed.connect(show_table_details.bind(table_value))
    map_canvas.add_child(crest)

    var table_label := Label.new()
    table_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    table_label.offset_bottom = -16.0
    table_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table_label.add_theme_font_override("font", BOLD_FONT)
    table_label.add_theme_font_size_override("font_size", 32)
    table_label.add_theme_color_override(
        "font_color",
        Color(0.28, 0.53, 0.08) if unlocked else Color(0.38, 0.38, 0.38)
    )
    table_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
    table_label.add_theme_constant_override("outline_size", 4)
    table_label.text = tr("MAP_TABLE").format({"table": int(stage_state["table"])})
    table_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    table_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crest.add_child(table_label)

    var card := PanelContainer.new()
    card.position = Vector2(
        150.0 if stage_on_left else 8.0,
        stage_position.y + 25.0
    )
    card.size = Vector2(158.0, 84.0)
    card.add_theme_stylebox_override("panel", _stage_card_style(current))
    map_canvas.add_child(card)

    var card_content := VBoxContainer.new()
    card_content.alignment = BoxContainer.ALIGNMENT_CENTER
    card_content.add_theme_constant_override("separation", 4)
    card.add_child(card_content)

    var status := Label.new()
    status.add_theme_font_override("font", BOLD_FONT)
    status.add_theme_font_size_override("font_size", 17)
    status.add_theme_color_override("font_color", Color(0.22, 0.33, 0.25))
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if completed:
        status.text = tr("MAP_STAGE_COMPLETE")
    elif current:
        status.text = tr("MAP_STAGE_CURRENT")
    else:
        status.text = tr("MAP_STAGE_LOCKED")
    card_content.add_child(status)

    var progress := ProgressBar.new()
    progress.custom_minimum_size = Vector2(0.0, 18.0)
    progress.max_value = int(stage_state.get("progress_max", 1))
    progress.value = int(stage_state.get("progress_points", 0))
    progress.show_percentage = false
    progress.add_theme_stylebox_override("background", _progress_style(Color(0.84, 0.84, 0.8)))
    progress.add_theme_stylebox_override(
        "fill",
        _progress_style(Color(0.42, 0.78, 0.18) if unlocked else Color(0.64, 0.64, 0.62))
    )
    card_content.add_child(progress)

    var progress_label := Label.new()
    progress_label.add_theme_font_size_override("font_size", 13)
    progress_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.31))
    progress_label.text = tr("MAP_STAGE_PROGRESS").format({
        "percent": int(stage_state.get("progress_percent", 0)),
    })
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card_content.add_child(progress_label)

    if int(stage_state.get("table", 0)) == _unlocked_table_announcement:
        crest.pivot_offset = crest.size / 2.0
        crest.scale = Vector2(0.72, 0.72)
        crest.modulate = Color(1.0, 1.0, 1.0, 0.45)
        var reveal := create_tween().set_parallel(true)
        reveal.tween_property(crest, "scale", Vector2.ONE, 0.55) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        reveal.tween_property(crest, "modulate", Color.WHITE, 0.3)


func show_table_details(table_value: int) -> void:
    for stage_state in _stage_states:
        if (
            int(stage_state.get("table", 0)) == table_value
            and bool(stage_state.get("unlocked", false))
        ):
            _selected_stage_state = stage_state.duplicate(true)
            fact_detail_overlay.visible = true
            _refresh_fact_detail()
            fact_detail_close.grab_focus()
            fact_detail_opened.emit()
            return


func hide_table_details() -> void:
    fact_detail_overlay.visible = false
    _selected_stage_state.clear()


func close_detail_if_open() -> bool:
    if not fact_detail_overlay.visible:
        return false
    hide_table_details()
    return true


func _refresh_fact_detail() -> void:
    var table_value := int(_selected_stage_state.get("table", 0))
    var progress_percent := int(_selected_stage_state.get("progress_percent", 0))
    fact_detail_title.text = tr("MAP_FACT_DETAIL_TITLE").format({"table": table_value})
    fact_detail_overall.text = tr("MAP_FACT_DETAIL_OVERALL").format({
        "percent": progress_percent,
    })
    _clear_container(fact_grid)
    var raw_facts: Variant = _selected_stage_state.get("facts", [])
    if raw_facts is Array:
        for raw_fact in raw_facts:
            if raw_fact is Dictionary:
                _add_fact_card(table_value, raw_fact)
    _rebuild_legend()


func _add_fact_card(table_value: int, fact: Dictionary) -> void:
    var multiplier := int(fact.get("multiplier", 0))
    var mastery := clampi(int(fact.get("mastery", 0)), 0, 100)
    var status := StringName(fact.get("status", &"building"))
    var color := _fact_status_color(status)

    var card := PanelContainer.new()
    card.name = "Fact%d" % multiplier
    card.custom_minimum_size = Vector2(150.0, 70.0)
    card.add_theme_stylebox_override("panel", _fact_card_style(color))
    card.tooltip_text = "%d × %d — %s" % [
        table_value,
        multiplier,
        tr(_fact_status_key(status)),
    ]
    fact_grid.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    card.add_child(content)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 4)
    content.add_child(header)

    var equation := Label.new()
    equation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    equation.add_theme_font_override("font", BOLD_FONT)
    equation.add_theme_font_size_override("font_size", 18)
    equation.add_theme_color_override("font_color", Color(0.2, 0.3, 0.23))
    equation.text = "%d × %d" % [table_value, multiplier]
    header.add_child(equation)

    var percent := Label.new()
    percent.add_theme_font_override("font", BOLD_FONT)
    percent.add_theme_font_size_override("font_size", 14)
    percent.add_theme_color_override("font_color", color.darkened(0.18))
    percent.text = tr("MAP_FACT_PERCENT").format({"percent": mastery})
    header.add_child(percent)

    var progress := ProgressBar.new()
    progress.custom_minimum_size = Vector2(0.0, 14.0)
    progress.max_value = 100.0
    progress.value = mastery
    progress.show_percentage = false
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress.add_theme_stylebox_override(
        "background",
        _progress_style(Color(0.82, 0.86, 0.82, 0.75))
    )
    progress.add_theme_stylebox_override("fill", _progress_style(color))
    content.add_child(progress)


func _rebuild_legend() -> void:
    _clear_container(legend_grid)
    for status in [&"building", &"practicing", &"mastered", &"automated"]:
        var item := HBoxContainer.new()
        item.custom_minimum_size = Vector2(150.0, 22.0)
        item.add_theme_constant_override("separation", 5)
        legend_grid.add_child(item)

        var dot := Label.new()
        dot.add_theme_font_size_override("font_size", 16)
        dot.add_theme_color_override("font_color", _fact_status_color(status))
        dot.text = "●"
        item.add_child(dot)

        var label := Label.new()
        label.add_theme_font_size_override("font_size", 12)
        label.add_theme_color_override("font_color", Color(0.31, 0.4, 0.33))
        label.text = tr(_fact_status_key(status))
        item.add_child(label)


func _clear_container(container: Container) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _fact_status_key(status: StringName) -> StringName:
    match status:
        &"practicing":
            return &"MAP_FACT_PRACTICING"
        &"mastered":
            return &"MAP_FACT_MASTERED"
        &"automated":
            return &"MAP_FACT_AUTOMATED"
        _:
            return &"MAP_FACT_BUILDING"


func _fact_status_color(status: StringName) -> Color:
    match status:
        &"practicing":
            return FACT_PRACTICING_COLOR
        &"mastered":
            return FACT_MASTERED_COLOR
        &"automated":
            return FACT_AUTOMATED_COLOR
        _:
            return FACT_BUILDING_COLOR


func _fact_card_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color.lightened(0.84)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = color.lightened(0.18)
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_right = 14
    style.corner_radius_bottom_left = 14
    style.content_margin_left = 8.0
    style.content_margin_top = 6.0
    style.content_margin_right = 8.0
    style.content_margin_bottom = 6.0
    return style


func _scroll_to_table(table_value: int) -> void:
    await get_tree().process_frame
    var stage_index := -1
    for index in _stage_states.size():
        if int(_stage_states[index].get("table", 0)) == table_value:
            stage_index = index
            break
    if stage_index < 0:
        return
    var visible_center_offset := maxf(0.0, (scroll.size.y - STAGE_SIZE.y) / 2.0)
    var target := int(maxf(0.0, stage_index * STAGE_STEP - visible_center_offset))
    var scroll_tween := create_tween()
    scroll_tween.tween_property(scroll, "scroll_vertical", target, 0.5) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stage_card_style(current: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 1.0, 1.0, 0.94)
    style.border_width_left = 3 if current else 0
    style.border_width_top = 3 if current else 0
    style.border_width_right = 3 if current else 0
    style.border_width_bottom = 3 if current else 0
    style.border_color = Color(0.43, 0.79, 0.19)
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_right = 18
    style.corner_radius_bottom_left = 18
    style.content_margin_left = 10.0
    style.content_margin_top = 8.0
    style.content_margin_right = 10.0
    style.content_margin_bottom = 8.0
    style.shadow_color = Color(0.12, 0.24, 0.2, 0.18)
    style.shadow_size = 5
    return style


func _progress_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_right = 8
    style.corner_radius_bottom_left = 8
    return style
