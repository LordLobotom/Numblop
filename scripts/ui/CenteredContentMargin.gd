class_name CenteredContentMargin
extends MarginContainer

@export_range(0, 100, 1) var compact_side_margin := 14
@export_range(320, 1200, 1) var max_content_width := 540


func _ready() -> void:
    resized.connect(_update_side_margins)
    _update_side_margins()


func _update_side_margins() -> void:
    var centered_margin := roundi((size.x - float(max_content_width)) * 0.5)
    var side_margin := maxi(compact_side_margin, centered_margin)
    add_theme_constant_override("margin_left", side_margin)
    add_theme_constant_override("margin_right", side_margin)
