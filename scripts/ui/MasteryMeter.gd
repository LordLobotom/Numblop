class_name MasteryMeter
extends Control

## Shows one fact's mastery as a row of dots, and how much of it this round earned.
##
## A child cannot read "45 -> 53", but they can see a dot fill up. Mastery is a 0-100 score,
## so ten dots divide it evenly and the two thresholds that matter land on dot boundaries:
## dot 8 is `LearningRules.UNLOCK_MASTERY`, dot 9 is `LearningRules.AUTOMATED_MASTERY`.
##
## The dot on the boundary fills proportionally rather than snapping, so a small gain still
## moves something visible -- an eight-point gain inside one dot would otherwise show nothing.

const DOT_COUNT := 10
const POINTS_PER_DOT := 100.0 / float(DOT_COUNT)
const DOT_DIAMETER := 13.0
const DOT_GAP := 3.0
const OUTLINE_WIDTH := 1.5

@export var earned_color := Color(0.25, 0.55, 0.16)
@export var gained_color := Color(0.55, 0.85, 0.3)
@export var empty_color := Color(0.35, 0.43, 0.37, 0.35)

var _before := 0.0
var _after := 0.0


func _ready() -> void:
    # PASS rather than IGNORE: the exact scores live in this control's tooltip, and an
    # ignored control is never hovered, so IGNORE would throw them away. The reward screen
    # takes its tap anywhere, and PASS still lets the event through to it.
    mouse_filter = Control.MOUSE_FILTER_PASS
    custom_minimum_size = Vector2(
        DOT_COUNT * DOT_DIAMETER + (DOT_COUNT - 1) * DOT_GAP,
        DOT_DIAMETER
    )


## `before` and `after` are raw 0-100 mastery scores; `after` never reads below `before`.
func set_progress(before: int, after: int) -> void:
    _before = clampf(float(before), 0.0, 100.0)
    _after = clampf(float(after), _before, 100.0)
    queue_redraw()


func _draw() -> void:
    var radius := DOT_DIAMETER * 0.5
    var row_width := DOT_COUNT * DOT_DIAMETER + (DOT_COUNT - 1) * DOT_GAP
    # Centred in whatever width the row hands out, so the meters line up across cards.
    var origin_x := maxf(0.0, (size.x - row_width) * 0.5)
    var center_y := size.y * 0.5

    for index in DOT_COUNT:
        var center := Vector2(
            origin_x + float(index) * (DOT_DIAMETER + DOT_GAP) + radius,
            center_y
        )
        var earned := _fill_of_dot(index, _before)
        var reached := _fill_of_dot(index, _after)
        draw_circle(center, radius, empty_color, false, OUTLINE_WIDTH, true)
        if reached > 0.0:
            _draw_partial_dot(center, radius, reached, gained_color)
        if earned > 0.0:
            _draw_partial_dot(center, radius, earned, earned_color)


## How much of the dot at `index` a score covers, as 0..1.
func _fill_of_dot(index: int, score: float) -> float:
    return clampf((score - float(index) * POINTS_PER_DOT) / POINTS_PER_DOT, 0.0, 1.0)


## Fills a dot from the left up to a vertical waterline, so a part-filled dot reads as a dot
## that is still filling rather than as a smaller dot.
##
## Drawn as the circular segment left of the waterline: sample the arc whose points fall on
## that side and let the closing edge form the chord.
func _draw_partial_dot(center: Vector2, radius: float, fill: float, color: Color) -> void:
    if fill >= 1.0:
        draw_circle(center, radius, color, true, -1.0, true)
        return
    # Waterline as a cosine, so `half_angle` is exactly where the circle crosses it.
    var half_angle := acos(clampf(2.0 * fill - 1.0, -1.0, 1.0))
    var steps := 24
    var points := PackedVector2Array()
    for step in steps + 1:
        var angle := half_angle + (TAU - 2.0 * half_angle) * (float(step) / float(steps))
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(points, color)
