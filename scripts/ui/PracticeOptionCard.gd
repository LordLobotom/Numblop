class_name PracticeOptionCard
extends Button

const LOCK_TEXTURE: Texture2D = preload("res://ui/icon/icon_lock.png")
const SELECTED_COLOR := Color(0.31, 0.77, 0.12, 1.0)
const IDLE_COLOR := Color(0.92, 0.97, 0.9, 1.0)
const LOCKED_COLOR := Color(0.84, 0.87, 0.82, 0.92)

var option_value := 0
var selected := false
var locked := false


func _ready() -> void:
    flat = false
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(
        maxf(custom_minimum_size.x, 58.0),
        maxf(custom_minimum_size.y, 58.0)
    )
    add_theme_font_override("font", preload("res://ui/fonts/Baloo2Bold.tres"))
    add_theme_font_size_override("font_size", 20)
    add_theme_color_override("font_color", Color(0.2, 0.34, 0.23))
    add_theme_color_override("font_hover_color", Color(0.2, 0.34, 0.23))
    add_theme_color_override("font_pressed_color", Color(0.2, 0.34, 0.23))
    add_theme_color_override("font_hover_pressed_color", Color(0.2, 0.34, 0.23))
    add_theme_color_override("font_focus_color", Color(0.2, 0.34, 0.23))
    add_theme_color_override("font_disabled_color", Color(0.42, 0.47, 0.43))
    _refresh_style()


func configure(label: String, value: int, is_selected: bool, is_locked: bool) -> void:
    text = label
    option_value = value
    locked = is_locked
    disabled = locked
    set_selected(is_selected)
    mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
    _refresh_style()
    queue_redraw()


func set_selected(is_selected: bool) -> void:
    selected = is_selected and not locked
    _refresh_style()
    queue_redraw()


func _draw() -> void:
    var card_rect := Rect2(Vector2.ZERO, size)
    var badge_center := card_rect.end - Vector2(12.0, 12.0)
    if selected:
        draw_polyline(
            CheckmarkIcon.check_points(badge_center, 0.72),
            CheckmarkIcon.DEFAULT_COLOR,
            3.0,
            true
        )
    elif locked:
        var icon_size := Vector2(15.0, 15.0)
        draw_texture_rect(
            LOCK_TEXTURE,
            Rect2(badge_center - icon_size / 2.0, icon_size),
            false,
            Color(0.24, 0.3, 0.25, 0.78)
        )


func _refresh_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = LOCKED_COLOR if locked else IDLE_COLOR
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    if selected:
        style.border_color = SELECTED_COLOR
        style.set_border_width_all(3)
    for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
        add_theme_stylebox_override(state_name, style)
