class_name PlayButton
extends Button

## The home screen's primary action, drawn rather than blitted.
##
## It used to be a 512x256 PNG. The canvas carried 53 px of transparent padding above and
## below the pill, and the node scaled the whole canvas into a 340x104 slot, so the artwork
## was squeezed to 61% of its authored proportions and the visible pill filled only 60 of the
## button's 104 pixels. Drawing it removes that mismatch by construction -- there is no canvas
## to mismatch -- and it stays sharp at every device scale instead of resampling one bitmap.
##
## Every colour here is sampled from the artwork it replaces, so the button is the same green.

const OUTLINE_COLOR := Color("fcfdf9")
const FACE_TOP_COLOR := Color("a7d83d")
const FACE_BOTTOM_COLOR := Color("6fbc32")
## The band under the face that reads as thickness rather than as shadow.
const LIP_COLOR := Color("3c9225")
const GLYPH_COLOR := Color("51a32c")

const OUTLINE_WIDTH := 5.0
const LIP_HEIGHT := 8.0
## Pressing sinks the face into the lip instead of moving the whole button.
const PRESSED_LIP_HEIGHT := 2.0
const HOVER_LIGHTEN := 0.06

const GLYPH_RIGHT_MARGIN := 24.0
const GLYPH_HEIGHT_RATIO := 0.30
const GLYPH_ASPECT := 0.86

## Segments per end cap. Twenty-four is smooth at every size this button is drawn at.
const CAP_SEGMENTS := 24


func _ready() -> void:
    # The whole face is drawn below, so none of Button's own chrome may show through.
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        add_theme_stylebox_override(state, StyleBoxEmpty.new())
    text = ""
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button_down.connect(queue_redraw)
    button_up.connect(queue_redraw)
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)


func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    var mode := get_draw_mode()
    var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
    var lit := mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED

    var rect := Rect2(Vector2.ZERO, size)
    draw_colored_polygon(_capsule(rect), OUTLINE_COLOR)

    var body := rect.grow(-OUTLINE_WIDTH)
    if body.size.x <= 0.0 or body.size.y <= 0.0:
        return
    draw_colored_polygon(_capsule(body), LIP_COLOR)

    var lip: float = PRESSED_LIP_HEIGHT if sunk else LIP_HEIGHT
    var face := Rect2(
        body.position,
        Vector2(body.size.x, maxf(1.0, body.size.y - lip))
    )
    var top := FACE_TOP_COLOR.lightened(HOVER_LIGHTEN) if lit else FACE_TOP_COLOR
    var bottom := FACE_BOTTOM_COLOR.lightened(HOVER_LIGHTEN) if lit else FACE_BOTTOM_COLOR
    var points := _capsule(face)
    draw_polygon(points, _vertical_gradient(points, face, top, bottom))
    _draw_glyph(face)


## The "go" arrow, sized from the face so it tracks any button dimensions.
func _draw_glyph(face: Rect2) -> void:
    var height := face.size.y * GLYPH_HEIGHT_RATIO
    var width := height * GLYPH_ASPECT
    var tip_x := face.end.x - GLYPH_RIGHT_MARGIN
    if tip_x - width <= face.position.x:
        return
    var middle_y := face.position.y + face.size.y * 0.5
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(tip_x - width, middle_y - height * 0.5),
            Vector2(tip_x, middle_y),
            Vector2(tip_x - width, middle_y + height * 0.5),
        ]),
        GLYPH_COLOR
    )


## A pill: two semicircular caps joined by straight edges, traced clockwise from the top of
## the right cap. Convex, so `draw_polygon` triangulates it without artefacts.
static func _capsule(rect: Rect2) -> PackedVector2Array:
    var radius := minf(rect.size.y, rect.size.x) * 0.5
    var middle_y := rect.position.y + rect.size.y * 0.5
    var right := Vector2(rect.end.x - radius, middle_y)
    var left := Vector2(rect.position.x + radius, middle_y)
    var points := PackedVector2Array()
    for step in CAP_SEGMENTS + 1:
        var angle := -PI * 0.5 + PI * float(step) / float(CAP_SEGMENTS)
        points.append(right + Vector2(cos(angle), sin(angle)) * radius)
    for step in CAP_SEGMENTS + 1:
        var angle := PI * 0.5 + PI * float(step) / float(CAP_SEGMENTS)
        points.append(left + Vector2(cos(angle), sin(angle)) * radius)
    return points


## Per-vertex colours keyed to height, which is what turns the flat polygon into a gradient.
static func _vertical_gradient(
    points: PackedVector2Array,
    rect: Rect2,
    top: Color,
    bottom: Color
) -> PackedColorArray:
    var colors := PackedColorArray()
    var height := maxf(1.0, rect.size.y)
    for point in points:
        colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / height, 0.0, 1.0)))
    return colors
