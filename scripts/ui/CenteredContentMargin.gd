class_name CenteredContentMargin
extends MarginContainer

## Keeps a screen's content off the physical edges of the display.
##
## Horizontally it pins the content to a readable column, centred once the viewport is
## wider than [member max_content_width]. Vertically it applies the authored base inset
## plus whatever the platform reserves for a notch, camera cutout or gesture bar, so no
## screen has to hardcode device-specific padding.

@export_range(0, 100, 1) var compact_side_margin := 16
@export_range(320, 1200, 1) var max_content_width := 540
@export_range(0, 100, 1) var base_top_margin := 20
@export_range(0, 100, 1) var base_bottom_margin := 16

var _applied_margins := Vector4i(-1, -1, -1, -1)
var _applying_margins := false


func _ready() -> void:
    resized.connect(_update_margins)
    _update_margins()


## Android reports its cutout and gesture-bar insets after the first frames, and reports them
## again after a rotation or a resume from the recents switcher. Neither of those resizes this
## container, so `resized` alone leaves the first-frame value in place and the content sits a
## pixel or two off the safe area for the rest of the session.
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_RESUMED, \
        NOTIFICATION_WM_SIZE_CHANGED, \
        NOTIFICATION_VISIBILITY_CHANGED:
            if is_node_ready():
                _update_margins()


func _update_margins() -> void:
    # Overriding the margin constants re-runs this container's layout, which fires
    # `resized` again. Without the re-entry guard and the unchanged-value check the
    # two feed each other until the stack overflows.
    if _applying_margins:
        return
    var centered_margin := roundi((size.x - float(max_content_width)) * 0.5)
    var side_margin := maxi(compact_side_margin, centered_margin)
    var safe_insets := _safe_area_insets()
    var margins := Vector4i(
        side_margin,
        base_top_margin + safe_insets.x,
        side_margin,
        base_bottom_margin + safe_insets.y
    )
    if margins == _applied_margins:
        return
    _applying_margins = true
    _applied_margins = margins
    add_theme_constant_override("margin_left", margins.x)
    add_theme_constant_override("margin_top", margins.y)
    add_theme_constant_override("margin_right", margins.z)
    add_theme_constant_override("margin_bottom", margins.w)
    _applying_margins = false


## Top and bottom insets the platform reserves, expressed in viewport units.
##
## Returns zero off-device so headless captures and the desktop build stay deterministic.
func _safe_area_insets() -> Vector2i:
    if not OS.has_feature("mobile"):
        return Vector2i.ZERO
    var window_height := DisplayServer.window_get_size().y
    if window_height <= 0:
        return Vector2i.ZERO
    var safe_area := DisplayServer.get_display_safe_area()
    if safe_area.size.y <= 0:
        return Vector2i.ZERO
    # The safe area is reported in native screen pixels; the canvas_items stretch mode
    # means the viewport is a scaled copy of the window, so convert before adding.
    var viewport_scale := get_viewport_rect().size.y / float(window_height)
    var top_pixels := maxi(0, safe_area.position.y)
    var bottom_pixels := maxi(0, window_height - (safe_area.position.y + safe_area.size.y))
    return Vector2i(
        roundi(top_pixels * viewport_scale),
        roundi(bottom_pixels * viewport_scale)
    )
