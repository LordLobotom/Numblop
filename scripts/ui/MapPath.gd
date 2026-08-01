class_name MapPath
extends Control

var _stage_centers := PackedVector2Array()


func set_stage_centers(stage_centers: PackedVector2Array) -> void:
    _stage_centers = stage_centers
    queue_redraw()


func _draw() -> void:
    if _stage_centers.size() < 2:
        return
    var curve := Curve2D.new()
    curve.bake_interval = 8.0
    for center in _stage_centers:
        curve.add_point(center, Vector2(0.0, -46.0), Vector2(0.0, 46.0))
    var trail := curve.get_baked_points()
    draw_polyline(trail, Color(1.0, 0.98, 0.78, 0.92), 22.0, true)
    draw_polyline(trail, Color(0.94, 0.72, 0.22, 0.72), 7.0, true)
