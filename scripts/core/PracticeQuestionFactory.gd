class_name PracticeQuestionFactory
extends RefCounted

## Builds the presentation shape of one question. Progression and free practice deliberately
## keep separate scheduling algorithms, while sharing these canonical mode and distractor rules.


static func create(
    table_value: int,
    multiplier: int,
    mastery: int,
    rng: RandomNumberGenerator
) -> PracticeQuestion:
    var mode := LearningRules.mode_for_mastery(mastery)
    return PracticeQuestion.new(
        table_value,
        multiplier,
        mode,
        _create_choices(table_value, multiplier, mode, rng)
    )


static func shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
    for index in range(values.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary := values[index]
        values[index] = values[other]
        values[other] = temporary


static func _create_choices(
    table_value: int,
    multiplier: int,
    mode: int,
    rng: RandomNumberGenerator
) -> Array[int]:
    if mode == LearningRules.QuestionMode.NUMBER_INPUT:
        return []

    var required := 4 if mode == LearningRules.QuestionMode.CHOICE_FOUR else 6
    var correct := table_value * multiplier
    var values: Array[int] = [correct]
    var candidates := _nearby_fact_products(table_value, multiplier, rng)
    for candidate in candidates:
        if not values.has(candidate):
            values.append(candidate)
        if values.size() == required:
            break
    shuffle_ints(values, rng)
    return values


static func _nearby_fact_products(
    table_value: int,
    multiplier: int,
    rng: RandomNumberGenerator
) -> Array[int]:
    var candidates: Array[int] = []
    for distance in range(1, LearningRules.MULTIPLIERS.size()):
        var same_distance: Array[int] = []
        var lower := multiplier - distance
        var upper := multiplier + distance
        if LearningRules.MULTIPLIERS.has(lower):
            same_distance.append(table_value * lower)
        if LearningRules.MULTIPLIERS.has(upper):
            same_distance.append(table_value * upper)
        shuffle_ints(same_distance, rng)
        candidates.append_array(same_distance)
    return candidates
