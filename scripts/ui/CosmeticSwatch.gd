class_name CosmeticSwatch
extends Button

const LOCK_TEXTURE: Texture2D = preload("res://ui/icon/icon_lock.png")

var color_id := ""
var swatch_color := Color.WHITE
var locked := false
var selected := false


func _ready() -> void:
    flat = true
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(54.0, 54.0)


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


func _draw() -> void:
    var center := size / 2.0
    var radius := minf(size.x, size.y) / 2.0 - 5.0
    draw_circle(center, radius, swatch_color)
    if selected:
        _draw_check(center)
    elif locked:
        _draw_lock(center)


func _draw_check(center: Vector2) -> void:
    var points := PackedVector2Array([
        center + Vector2(-6.0, 0.0),
        center + Vector2(-1.5, 4.5),
        center + Vector2(7.5, -6.0),
    ])
    draw_polyline(points, Color(0.12, 0.56, 0.08), 3.0, true)


func _draw_lock(center: Vector2) -> void:
    var lock_size := Vector2(23.0, 23.0)
    draw_texture_rect(LOCK_TEXTURE, Rect2(center - lock_size / 2.0, lock_size), false)
