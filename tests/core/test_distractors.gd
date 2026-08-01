extends NumblopTestCase


func test_zero_facts_have_unique_non_negative_nearby_fact_choices() -> void:
    for table_value in LearningRules.TABLES:
        var choices := _choices(
            table_value,
            0,
            LearningRules.QuestionMode.CHOICE_SIX,
            table_value
        )
        _check_choice_contract(choices, table_value, 0, 6)
        equal(_largest_multiplier_distance(choices, table_value, 0), 5, "×0 proximity")


func test_one_facts_do_not_duplicate_the_correct_product() -> void:
    for table_value in LearningRules.TABLES:
        var choices := _choices(
            table_value,
            1,
            LearningRules.QuestionMode.CHOICE_FOUR,
            table_value * 10
        )
        _check_choice_contract(choices, table_value, 1, 4)
        equal(_occurrence_count(choices, table_value), 1, "×1 answer occurrence")


func test_repeated_products_are_numeric_choices_without_duplicates() -> void:
    var first := _choices(3, 4, LearningRules.QuestionMode.CHOICE_SIX, 34)
    var reversed := _choices(4, 3, LearningRules.QuestionMode.CHOICE_SIX, 43)

    _check_choice_contract(first, 3, 4, 6)
    _check_choice_contract(reversed, 4, 3, 6)
    equal(_occurrence_count(first, 12), 1, "3 × 4 answer occurrence")
    equal(_occurrence_count(reversed, 12), 1, "4 × 3 answer occurrence")


func test_all_choice_questions_use_nearby_facts_from_the_presented_table() -> void:
    for table_value in LearningRules.TABLES:
        for multiplier in LearningRules.MULTIPLIERS:
            for mode in [
                LearningRules.QuestionMode.CHOICE_FOUR,
                LearningRules.QuestionMode.CHOICE_SIX,
            ]:
                var expected_size := 4 if mode == LearningRules.QuestionMode.CHOICE_FOUR else 6
                var choices := _choices(table_value, multiplier, mode, table_value * 100 + multiplier)
                _check_choice_contract(choices, table_value, multiplier, expected_size)
                check(
                    _largest_multiplier_distance(choices, table_value, multiplier) <= 5,
                    "Distractors should come from nearby facts"
                )


func test_number_input_has_no_choices() -> void:
    var choices := _choices(9, 9, LearningRules.QuestionMode.NUMBER_INPUT, 99)
    equal(choices, [], "Number input choices")


func _choices(table_value: int, multiplier: int, mode: int, seed: int) -> Array[int]:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return SessionGenerator._create_choices(table_value, multiplier, mode, rng)


func _check_choice_contract(
    choices: Array[int],
    table_value: int,
    multiplier: int,
    expected_size: int
) -> void:
    equal(choices.size(), expected_size, "Choice count")
    equal(_unique_count(choices), expected_size, "Unique choices")
    contains(choices, table_value * multiplier, "Correct answer")
    for choice in choices:
        check(choice >= 0, "Choice must be non-negative")
        check(choice % table_value == 0, "Choice should be a fact from the current table")
        check(
            LearningRules.MULTIPLIERS.has(choice / table_value),
            "Choice multiplier should be in the practiced range"
        )


func _largest_multiplier_distance(
    choices: Array[int],
    table_value: int,
    multiplier: int
) -> int:
    var largest := 0
    for choice in choices:
        largest = maxi(largest, absi(choice / table_value - multiplier))
    return largest


func _occurrence_count(values: Array[int], expected: int) -> int:
    var count := 0
    for value in values:
        if value == expected:
            count += 1
    return count


func _unique_count(values: Array[int]) -> int:
    var unique: Dictionary = {}
    for value in values:
        unique[value] = true
    return unique.size()
