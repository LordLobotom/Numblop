class_name CosmeticItemCard
extends Button

const LOCK_TEXTURE: Texture2D = preload("res://ui/icon/icon_lock.png")
const DEFAULT_CARD_SIZE := 58.0
const LOCKED_ART_MODULATE := Color(1.0, 1.0, 1.0, 0.62)
const PREVIEW_RING_COLOR := Color(0.31, 0.77, 0.12, 1.0)

var card_size := DEFAULT_CARD_SIZE
var item_id := ""
var item_texture: Texture2D
var display_region := Rect2()
var locked := false
var selected := false
var previewed := false


func _ready() -> void:
    flat = true
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(card_size, card_size)


func configure(item: Dictionary, is_locked: bool, is_selected: bool) -> void:
    item_id = String(item["id"])
    var texture_path := String(item.get("texture_path", ""))
    item_texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
    display_region = item.get("display_region", Rect2()) as Rect2
    locked = is_locked
    selected = is_selected
    queue_redraw()


func set_previewed(is_previewed: bool) -> void:
    if previewed == is_previewed:
        return
    previewed = is_previewed
    queue_redraw()


func _draw() -> void:
    var card_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
    var corner_radius := int(maxf(12.0, card_rect.size.x * 0.16))
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.94, 0.98, 0.92, 0.96)
    card_style.corner_radius_top_left = corner_radius
    card_style.corner_radius_top_right = corner_radius
    card_style.corner_radius_bottom_left = corner_radius
    card_style.corner_radius_bottom_right = corner_radius
    draw_style_box(card_style, card_rect)

    if item_texture != null and display_region.size.length_squared() > 0.0:
        var art_inset := card_rect.size.x * 0.09
        var content_rect := _fit_region(display_region.size, card_rect.grow(-art_inset))
        draw_texture_rect_region(
            item_texture,
            content_rect,
            display_region,
            LOCKED_ART_MODULATE if locked else Color.WHITE
        )
    else:
        _draw_none_mark(card_rect.get_center())

    if previewed:
        _draw_preview_ring(card_rect, corner_radius)

    var badge_inset := maxf(13.0, card_rect.size.x * 0.15)
    if selected:
        _draw_check(card_rect.end - Vector2(badge_inset, badge_inset))
    elif locked:
        _draw_lock_badge(Vector2(
            card_rect.end.x - badge_inset,
            card_rect.position.y + badge_inset
        ))


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


func _draw_lock_badge(center: Vector2) -> void:
    var badge_radius := maxf(10.0, card_size * 0.125)
    var icon_size := Vector2.ONE * badge_radius * 1.25
    draw_circle(center, badge_radius, Color(0.22, 0.28, 0.24, 0.88))
    draw_texture_rect(
        LOCK_TEXTURE,
        Rect2(center - icon_size / 2.0, icon_size),
        false,
        Color(1.0, 1.0, 1.0, 0.95)
    )


func _draw_preview_ring(card_rect: Rect2, corner_radius: int) -> void:
    var ring_style := StyleBoxFlat.new()
    ring_style.draw_center = false
    ring_style.border_color = PREVIEW_RING_COLOR
    ring_style.set_border_width_all(3)
    ring_style.corner_radius_top_left = corner_radius
    ring_style.corner_radius_top_right = corner_radius
    ring_style.corner_radius_bottom_left = corner_radius
    ring_style.corner_radius_bottom_right = corner_radius
    draw_style_box(ring_style, card_rect)


func _draw_check(center: Vector2) -> void:
    draw_polyline(
        CheckmarkIcon.check_points(center),
        CheckmarkIcon.DEFAULT_COLOR,
        3.5,
        true
    )
