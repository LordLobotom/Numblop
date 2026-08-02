class_name CheckmarkIcon
extends Control

const DEFAULT_COLOR := Color(0.12, 0.56, 0.08)

@export var check_color := DEFAULT_COLOR
@export_range(1.0, 10.0, 0.5) var line_width := 3.0
@export_range(0.5, 3.0, 0.1) var scale_factor := 1.0
@export var outline_color := Color.TRANSPARENT
@export_range(0.0, 14.0, 0.5) var outline_width := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var points := check_points(size / 2.0, scale_factor)
    if outline_width > line_width and outline_color.a > 0.0:
        draw_polyline(points, outline_color, outline_width, true)
    draw_polyline(points, check_color, line_width, true)


static func check_points(center: Vector2, scale: float = 1.0) -> PackedVector2Array:
    return PackedVector2Array([
        center + Vector2(-6.0, 0.0) * scale,
        center + Vector2(-1.5, 4.5) * scale,
        center + Vector2(7.5, -6.0) * scale,
    ])
