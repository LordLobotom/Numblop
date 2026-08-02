class_name DotVisualization
extends RefCounted

## Deterministic domino-style layout for the wrong-answer correction picture.
##
## A fact is shown as `min(table, multiplier)` cards holding `max(table, multiplier)` pips each,
## so 3x4 reads as three groups of four and 7x4 as four groups of seven. Counts above six are
## split into the familiar 5 + remainder domino faces.
##
## The solver lives in core so the "every fact fits the feedback panel" guarantee is a headless
## unit test rather than something only a real layout pass could catch. It is pure arithmetic and
## touches no scene, autoload, file, clock, locale, or platform API.

const REFERENCE_WIDTH := 288.0
const REFERENCE_HEIGHT := 200.0
const MAX_CARD_HEIGHT := 64.0
const CARD_GAP := 8.0
const SPLIT_THRESHOLD := 6
const SPLIT_BASE := 5
const MAX_PIPS := 9
const PIP_RADIUS_RATIO := 0.095
const MIN_PIP_RADIUS := 3.0
const SPLIT_ASPECT := 2.0
const SQUARE_ASPECT := 1.0

## Thirds of a die face; the classic three-by-three pip grid.
const PIP_AXIS: Array[float] = [0.26, 0.5, 0.74]

## Never more than three columns, so wide cards keep a single readable size. Index is the card
## count: 4 cards read better as 2x2 than as 3+1.
const COLUMNS_BY_CARDS: Array[int] = [1, 1, 2, 3, 2, 3, 3, 3, 3, 3]


static func group_count(table_value: int, multiplier: int) -> int:
    return clampi(mini(table_value, multiplier), 0, MAX_PIPS)


static func pips_per_group(table_value: int, multiplier: int) -> int:
    return clampi(maxi(table_value, multiplier), 0, MAX_PIPS)


## Domino decomposition: 6 stays whole, 7 becomes 5 + 2, 8 becomes 5 + 3, 9 becomes 5 + 4.
static func face_split(pips: int) -> Array[int]:
    var total := clampi(pips, 0, MAX_PIPS)
    if total <= SPLIT_THRESHOLD:
        return [total]
    return [SPLIT_BASE, total - SPLIT_BASE]


static func is_split(pips: int) -> bool:
    return clampi(pips, 0, MAX_PIPS) > SPLIT_THRESHOLD


static func card_aspect(pips: int) -> float:
    return SPLIT_ASPECT if is_split(pips) else SQUARE_ASPECT


## Pip centres for one die face, in unit coordinates inside the face square.
static func face_pip_offsets(pips: int) -> PackedVector2Array:
    var low: float = PIP_AXIS[0]
    var mid: float = PIP_AXIS[1]
    var high: float = PIP_AXIS[2]
    match clampi(pips, 0, SPLIT_THRESHOLD):
        1:
            return PackedVector2Array([Vector2(mid, mid)])
        2:
            return PackedVector2Array([Vector2(low, low), Vector2(high, high)])
        3:
            return PackedVector2Array([
                Vector2(low, low), Vector2(mid, mid), Vector2(high, high),
            ])
        4:
            return PackedVector2Array([
                Vector2(low, low), Vector2(high, low),
                Vector2(low, high), Vector2(high, high),
            ])
        5:
            return PackedVector2Array([
                Vector2(low, low), Vector2(high, low), Vector2(mid, mid),
                Vector2(low, high), Vector2(high, high),
            ])
        6:
            return PackedVector2Array([
                Vector2(low, low), Vector2(low, mid), Vector2(low, high),
                Vector2(high, low), Vector2(high, mid), Vector2(high, high),
            ])
    return PackedVector2Array()


static func columns_for(card_total: int) -> int:
    return COLUMNS_BY_CARDS[clampi(card_total, 0, MAX_PIPS)]


## Places every card inside `available`, centred, and reports the pip radius to draw with.
##
## Returns `cards`, `card_size`, `columns`, `rows`, `pip_radius`, `split`, and `empty`.
static func layout(groups: int, pips: int, available: Vector2) -> Dictionary:
    var empty := groups <= 0
    # A zero fact still draws one empty frame, so the reveal always has something to time against.
    var card_total := maxi(groups, 1)
    var columns := columns_for(card_total)
    var rows := ceili(float(card_total) / float(columns))
    var aspect := SQUARE_ASPECT if empty else card_aspect(pips)

    var usable := Vector2(maxf(available.x, 1.0), maxf(available.y, 1.0))
    var height_from_width := (
        (usable.x - float(columns - 1) * CARD_GAP) / float(columns) / aspect
    )
    var height_from_height := (usable.y - float(rows - 1) * CARD_GAP) / float(rows)
    var card_height := maxf(
        minf(minf(height_from_width, height_from_height), MAX_CARD_HEIGHT),
        1.0
    )
    var card_size := Vector2(card_height * aspect, card_height)

    var grid_size := Vector2(
        float(columns) * card_size.x + float(columns - 1) * CARD_GAP,
        float(rows) * card_size.y + float(rows - 1) * CARD_GAP
    )
    var origin := (usable - grid_size) * 0.5

    var cards: Array[Rect2] = []
    for index in card_total:
        var row := index / columns
        var column := index % columns
        # Centre a ragged last row instead of leaving it left-aligned.
        var cards_in_row := mini(columns, card_total - row * columns)
        var row_width := (
            float(cards_in_row) * card_size.x + float(cards_in_row - 1) * CARD_GAP
        )
        cards.append(Rect2(
            Vector2(
                origin.x + (grid_size.x - row_width) * 0.5
                    + float(column) * (card_size.x + CARD_GAP),
                origin.y + float(row) * (card_size.y + CARD_GAP)
            ),
            card_size
        ))

    # A split card is two face squares side by side, so a face is always one card tall.
    return {
        "cards": cards,
        "card_size": card_size,
        "columns": columns,
        "rows": rows,
        "pip_radius": maxf(card_height * PIP_RADIUS_RATIO, MIN_PIP_RADIUS),
        "split": not empty and is_split(pips),
        "empty": empty,
    }


## Height the picture wants for a given width, ignoring any vertical limit, so a Control can
## reserve space before it knows its own height.
static func preferred_height(groups: int, pips: int, width := REFERENCE_WIDTH) -> float:
    var card_total := maxi(groups, 1)
    var columns := columns_for(card_total)
    var rows := ceili(float(card_total) / float(columns))
    var aspect := SQUARE_ASPECT if groups <= 0 else card_aspect(pips)
    var card_height := maxf(
        minf(
            (maxf(width, 1.0) - float(columns - 1) * CARD_GAP) / float(columns) / aspect,
            MAX_CARD_HEIGHT
        ),
        1.0
    )
    return float(rows) * card_height + float(rows - 1) * CARD_GAP
