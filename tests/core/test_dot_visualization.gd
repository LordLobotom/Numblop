extends NumblopTestCase


func test_the_smaller_factor_becomes_the_group_count() -> void:
    equal(DotVisualization.group_count(3, 4), 3, "3x4 is three groups")
    equal(DotVisualization.pips_per_group(3, 4), 4, "3x4 groups hold four")
    equal(DotVisualization.group_count(7, 4), 4, "7x4 is four groups")
    equal(DotVisualization.pips_per_group(7, 4), 7, "7x4 groups hold seven")
    equal(DotVisualization.group_count(9, 9), 9, "9x9 is nine groups")
    equal(DotVisualization.group_count(5, 1), 1, "Times one is a single group")
    equal(DotVisualization.pips_per_group(5, 1), 5, "Times one holds the whole table value")
    equal(DotVisualization.group_count(7, 0), 0, "Times zero has no groups")


func test_counts_above_six_split_into_domino_faces() -> void:
    equal(DotVisualization.face_split(6), [6], "Six stays a whole die face")
    equal(DotVisualization.face_split(7), [5, 2], "Seven is five and two")
    equal(DotVisualization.face_split(8), [5, 3], "Eight is five and three")
    equal(DotVisualization.face_split(9), [5, 4], "Nine is five and four")
    check(not DotVisualization.is_split(6), "Six needs no split")
    check(DotVisualization.is_split(7), "Seven splits")
    equal(DotVisualization.card_aspect(9), 2.0, "Split cards are wide dominoes")
    equal(DotVisualization.card_aspect(4), 1.0, "Whole faces are square")


func test_die_faces_place_the_expected_pips_inside_the_face() -> void:
    for pips in range(1, DotVisualization.SPLIT_THRESHOLD + 1):
        var offsets := DotVisualization.face_pip_offsets(pips)
        equal(offsets.size(), pips, "Face %d pip count" % pips)
        for offset in offsets:
            check(
                offset.x >= 0.0 and offset.x <= 1.0 and offset.y >= 0.0 and offset.y <= 1.0,
                "Face %d keeps every pip inside the face" % pips
            )
    var center := Vector2(DotVisualization.PIP_AXIS[1], DotVisualization.PIP_AXIS[1])
    check(DotVisualization.face_pip_offsets(3).has(center), "Odd face three has a centre pip")
    check(DotVisualization.face_pip_offsets(5).has(center), "Odd face five has a centre pip")
    check(not DotVisualization.face_pip_offsets(4).has(center), "Even face four has no centre pip")


func test_the_heaviest_fact_still_fits_the_feedback_panel() -> void:
    var plan := DotVisualization.layout(9, 9, Vector2(288.0, 200.0))
    var cards: Array[Rect2] = plan["cards"]
    equal(cards.size(), 9, "Nine groups draw nine cards")
    equal(int(plan["columns"]), 3, "Nine cards use three columns")
    equal(int(plan["rows"]), 3, "Nine cards use three rows")
    check(bool(plan["split"]), "Nine pips draw as a domino split")
    var card_size: Vector2 = plan["card_size"]
    check(absf(card_size.x - 90.667) < 0.1, "Widest readable card width")
    check(absf(card_size.y - 45.333) < 0.1, "Matching card height")
    check(float(plan["pip_radius"]) >= DotVisualization.MIN_PIP_RADIUS, "Pips stay visible")
    var bounds := _bounding_box(cards)
    check(absf(bounds.size.x - 288.0) < 0.1, "The grid uses the full width")
    check(bounds.size.y <= 200.0, "The grid stays inside the height budget")


func test_every_fact_fits_without_overlapping() -> void:
    var box := Rect2(Vector2.ZERO, Vector2(
        DotVisualization.REFERENCE_WIDTH,
        DotVisualization.REFERENCE_HEIGHT
    ))
    for table_value in LearningRules.TABLES:
        for multiplier in LearningRules.MULTIPLIERS:
            var groups := DotVisualization.group_count(table_value, multiplier)
            var pips := DotVisualization.pips_per_group(table_value, multiplier)
            var plan := DotVisualization.layout(groups, pips, box.size)
            var cards: Array[Rect2] = plan["cards"]
            var label := "%dx%d" % [table_value, multiplier]
            equal(cards.size(), maxi(groups, 1), "%s card count" % label)
            for index in cards.size():
                check(box.encloses(cards[index]), "%s card %d stays on screen" % [label, index])
                for other in range(index + 1, cards.size()):
                    check(
                        not cards[index].grow(-1.0).intersects(cards[other].grow(-1.0)),
                        "%s cards %d and %d do not overlap" % [label, index, other]
                    )


func test_preferred_height_reserves_space_without_needing_a_height() -> void:
    check(DotVisualization.preferred_height(9, 9) <= 200.0, "Heaviest fact reserves under 200")
    check(
        DotVisualization.preferred_height(3, 4) < DotVisualization.preferred_height(9, 9),
        "A light fact reserves less than the heaviest one"
    )
    check(DotVisualization.preferred_height(1, 5) > 0.0, "A single group still reserves space")


func test_times_zero_draws_one_empty_frame() -> void:
    var plan := DotVisualization.layout(0, 7, Vector2(288.0, 200.0))
    check(bool(plan["empty"]), "Times zero is an empty fact")
    equal((plan["cards"] as Array[Rect2]).size(), 1, "One frame keeps the reveal timing uniform")
    check(not bool(plan["split"]), "An empty frame never splits")
    equal(DotVisualization.face_pip_offsets(0).size(), 0, "An empty face draws no pips")


func _bounding_box(cards: Array[Rect2]) -> Rect2:
    var bounds: Rect2 = cards[0]
    for index in range(1, cards.size()):
        bounds = bounds.merge(cards[index])
    return bounds
