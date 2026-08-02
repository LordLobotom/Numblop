class_name CenteredContentMargin
extends MarginContainer

@export_range(0, 100, 1) var compact_side_margin := 14
@export_range(320, 1200, 1) var max_content_width := 540

var _applied_side_margin := -1
var _applying_side_margins := false


func _ready() -> void:
    resized.connect(_update_side_margins)
    _update_side_margins()


func _update_side_margins() -> void:
    # Overriding the margin constants re-runs this container's layout, which fires
    # `resized` again. Without the re-entry guard and the unchanged-value check the
    # two feed each other until the stack overflows.
    if _applying_side_margins:
        return
    var centered_margin := roundi((size.x - float(max_content_width)) * 0.5)
    var side_margin := maxi(compact_side_margin, centered_margin)
    if side_margin == _applied_side_margin:
        return
    _applying_side_margins = true
    _applied_side_margin = side_margin
    add_theme_constant_override("margin_left", side_margin)
    add_theme_constant_override("margin_right", side_margin)
    _applying_side_margins = false
