class_name CosmeticSwatch
extends Button

const LOCK_TEXTURE: Texture2D = preload("res://ui/icon/icon_lock.png")
const PREVIEW_RING_COLOR := Color(0.31, 0.77, 0.12, 1.0)

var color_id := ""
var swatch_color := Color.WHITE
var locked := false
var selected := false
var previewed := false


func _ready() -> void:
    flat = true
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(48.0, 48.0)


func configure(
    new_color_id: String,
    new_color: Color,
    is_locked: bool,
    is_selected: bool
) -> void:
    color_id = new_color_id
    swatch_color = new_color
    locked = is_locked
    selected = is_selected
    queue_redraw()


func set_previewed(is_previewed: bool) -> void:
    if previewed == is_previewed:
        return
    previewed = is_previewed
    queue_redraw()


func _draw() -> void:
    var center := size / 2.0
    var radius := minf(size.x, size.y) / 2.0 - 5.0
    draw_circle(center, radius, swatch_color)
    if previewed:
        draw_arc(center, radius + 2.0, 0.0, TAU, 32, PREVIEW_RING_COLOR, 3.0, true)
    if selected:
        _draw_check(center)
    elif locked:
        _draw_lock_badge(center + Vector2.ONE * radius * 0.62)


func _draw_check(center: Vector2) -> void:
    draw_polyline(
        CheckmarkIcon.check_points(center),
        CheckmarkIcon.DEFAULT_COLOR,
        3.0,
        true
    )


func _draw_lock_badge(center: Vector2) -> void:
    var badge_radius := 9.0
    var icon_size := Vector2(12.0, 12.0)
    draw_circle(center, badge_radius, Color(0.22, 0.28, 0.24, 0.88))
    draw_texture_rect(
        LOCK_TEXTURE,
        Rect2(center - icon_size / 2.0, icon_size),
        false,
        Color(1.0, 1.0, 1.0, 0.95)
    )
