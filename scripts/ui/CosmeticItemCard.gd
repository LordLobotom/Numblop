class_name CosmeticItemCard
extends Button

const LOCK_TEXTURE: Texture2D = preload("res://ui/icon/icon_lock.png")

var item_id := ""
var item_texture: Texture2D
var display_region := Rect2()
var locked := false
var selected := false


func _ready() -> void:
    flat = true
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(58.0, 58.0)


func configure(item: Dictionary, is_locked: bool, is_selected: bool) -> void:
    item_id = String(item["id"])
    var texture_path := String(item.get("texture_path", ""))
    item_texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
    display_region = item.get("display_region", Rect2()) as Rect2
    locked = is_locked
    selected = is_selected
    queue_redraw()


func _draw() -> void:
    var card_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.94, 0.98, 0.92, 0.96)
    card_style.corner_radius_top_left = 15
    card_style.corner_radius_top_right = 15
    card_style.corner_radius_bottom_left = 15
    card_style.corner_radius_bottom_right = 15
    draw_style_box(card_style, card_rect)

    if item_texture != null and display_region.size.length_squared() > 0.0:
        var content_rect := _fit_region(display_region.size, card_rect.grow(-7.0))
        draw_texture_rect_region(item_texture, content_rect, display_region)
    else:
        _draw_none_mark(card_rect.get_center())

    if selected:
        _draw_check(card_rect.end - Vector2(13.0, 13.0))
    elif locked:
        var lock_size := Vector2(23.0, 23.0)
        draw_texture_rect(
            LOCK_TEXTURE,
            Rect2(card_rect.get_center() - lock_size / 2.0, lock_size),
            false
        )


func _fit_region(source_size: Vector2, bounds: Rect2) -> Rect2:
    var scale_factor := minf(
        bounds.size.x / source_size.x,
        bounds.size.y / source_size.y
    )
    var fitted_size := source_size * scale_factor
    return Rect2(bounds.get_center() - fitted_size / 2.0, fitted_size)


func _draw_none_mark(center: Vector2) -> void:
    var mark_color := Color(0.42, 0.52, 0.45, 0.72)
    draw_line(center + Vector2(-10.0, -10.0), center + Vector2(10.0, 10.0), mark_color, 3.0, true)
    draw_line(center + Vector2(10.0, -10.0), center + Vector2(-10.0, 10.0), mark_color, 3.0, true)


func _draw_check(center: Vector2) -> void:
    draw_polyline(
        CheckmarkIcon.check_points(center),
        CheckmarkIcon.DEFAULT_COLOR,
        3.5,
        true
    )
