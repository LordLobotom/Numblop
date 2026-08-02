class_name BackspaceIcon
extends Control

@export var arrow_color := Color(0.25, 0.17, 0.34)
@export_range(1.0, 10.0, 0.5) var line_width := 4.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var center := size / 2.0
    var tip := center + Vector2(-11.0, 0.0)
    var tail := center + Vector2(11.0, 0.0)
    draw_line(tip, tail, arrow_color, line_width, true)
    draw_line(tip, center + Vector2(-2.0, -9.0), arrow_color, line_width, true)
    draw_line(tip, center + Vector2(-2.0, 9.0), arrow_color, line_width, true)
