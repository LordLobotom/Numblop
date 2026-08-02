class_name DotFactVisual
extends Control

## Draws the wrong-answer correction picture: one domino card per group, filled group by group.
##
## Card frames appear together and only the pips fade in, so the reveal reads as a calm "here is
## what it means" rather than an alarm. Geometry comes from `DotVisualization`; this script owns
## nothing but colour and drawing.

const CARD_CORNER_RADIUS := 10
const CARD_BORDER_WIDTH := 2
const DIVIDER_WIDTH := 2.0
const DIVIDER_INSET := 0.12

@export var pip_color := Color(0.33, 0.25, 0.5)
@export var card_color := Color(1.0, 1.0, 1.0, 0.96)
@export var border_color := Color(0.33, 0.25, 0.5, 0.35)

var reveal_progress := 1.0: set = set_reveal_progress

var _groups := 0
var _pips := 0
var _card_style: StyleBoxFlat


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_fact(table_value: int, multiplier: int) -> void:
    _groups = DotVisualization.group_count(table_value, multiplier)
    _pips = DotVisualization.pips_per_group(table_value, multiplier)
    custom_minimum_size.y = DotVisualization.preferred_height(_groups, _pips)
    queue_redraw()


func card_count() -> int:
    return maxi(_groups, 1)


func is_empty_fact() -> bool:
    return _groups <= 0


func set_reveal_progress(value: float) -> void:
    reveal_progress = clampf(value, 0.0, 1.0)
    queue_redraw()


func _draw() -> void:
    var plan := DotVisualization.layout(_groups, _pips, size)
    var cards: Array[Rect2] = plan["cards"]
    var empty := bool(plan["empty"])
    var split := bool(plan["split"])
    var pip_radius := float(plan["pip_radius"])
    var faces := DotVisualization.face_split(_pips)

    for index in cards.size():
        var card: Rect2 = cards[index]
        draw_style_box(_style(), card)
        if empty:
            continue
        var alpha := clampf(
            reveal_progress * float(cards.size()) - float(index),
            0.0,
            1.0
        )
        if alpha <= 0.0:
            continue
        var fill := Color(pip_color, pip_color.a * alpha)
        if not split:
            _draw_face(card, faces[0], pip_radius, fill)
            continue

        var half_size := Vector2(card.size.x * 0.5, card.size.y)
        _draw_face(Rect2(card.position, half_size), faces[0], pip_radius, fill)
        _draw_face(
            Rect2(card.position + Vector2(half_size.x, 0.0), half_size),
            faces[1],
            pip_radius,
            fill
        )
        var divider_x := card.position.x + half_size.x
        draw_line(
            Vector2(divider_x, card.position.y + card.size.y * DIVIDER_INSET),
            Vector2(divider_x, card.position.y + card.size.y * (1.0 - DIVIDER_INSET)),
            Color(border_color, border_color.a * alpha),
            DIVIDER_WIDTH,
            true
        )


func _draw_face(face: Rect2, pips: int, pip_radius: float, color: Color) -> void:
    for offset in DotVisualization.face_pip_offsets(pips):
        draw_circle(
            face.position + Vector2(face.size.x * offset.x, face.size.y * offset.y),
            pip_radius,
            color
        )


func _style() -> StyleBoxFlat:
    if _card_style != null:
        return _card_style
    _card_style = StyleBoxFlat.new()
    _card_style.bg_color = card_color
    _card_style.border_color = border_color
    _card_style.set_border_width_all(CARD_BORDER_WIDTH)
    _card_style.corner_radius_top_left = CARD_CORNER_RADIUS
    _card_style.corner_radius_top_right = CARD_CORNER_RADIUS
    _card_style.corner_radius_bottom_right = CARD_CORNER_RADIUS
    _card_style.corner_radius_bottom_left = CARD_CORNER_RADIUS
    return _card_style
