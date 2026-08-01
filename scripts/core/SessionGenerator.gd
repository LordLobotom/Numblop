class_name SessionGenerator
extends RefCounted

const CURRENT := &"current"
const OLDER_WEAK := &"older_weak"
const OLDER_AUTOMATED := &"older_automated"
const SLOT_PLAN: Array[StringName] = [
    CURRENT, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
    OLDER_AUTOMATED, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
]


static func generate(profile: LearningProfile, seed: int) -> Array[PracticeQuestion]:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var current_facts := _facts_for_table(profile.current_table())
    var weak_facts := _older_facts(profile, false)
    var automated_facts := _older_facts(profile, true)
    var questions: Array[PracticeQuestion] = []
    var previous_key := ""
    var used_keys: Dictionary = {}

    for slot in SLOT_PLAN:
        var candidates: Array[Vector2i]
        match slot:
            OLDER_WEAK:
                candidates = weak_facts
            OLDER_AUTOMATED:
                candidates = automated_facts
            _:
                candidates = current_facts
        if candidates.is_empty():
            candidates = current_facts
        var fact := _select_lowest_mastery(
            profile,
            candidates,
            previous_key,
            used_keys,
            rng
        )
        var mastery := profile.get_mastery(fact.x, fact.y)
        var mode := LearningRules.mode_for_mastery(mastery)
        var choices := _create_choices(fact.x, fact.y, mode, rng)
        var question := PracticeQuestion.new(fact.x, fact.y, mode, choices)
        questions.append(question)
        previous_key = question.fact_key()
        used_keys[previous_key] = true

    assert(questions.size() == LearningRules.SESSION_LENGTH)
    return questions


static func _facts_for_table(table_value: int) -> Array[Vector2i]:
    var facts: Array[Vector2i] = []
    for multiplier in LearningRules.MULTIPLIERS:
        facts.append(Vector2i(table_value, multiplier))
    return facts


static func _older_facts(profile: LearningProfile, automated: bool) -> Array[Vector2i]:
    var facts: Array[Vector2i] = []
    for table_index in range(profile.highest_unlocked_index):
        var table_value: int = LearningRules.TABLES[table_index]
        for multiplier in LearningRules.MULTIPLIERS:
            var value := profile.get_mastery(table_value, multiplier)
            if automated == (value >= LearningRules.AUTOMATED_MASTERY):
                facts.append(Vector2i(table_value, multiplier))
    return facts


static func _select_lowest_mastery(
    profile: LearningProfile,
    candidates: Array[Vector2i],
    previous_key: String,
    used_keys: Dictionary,
    rng: RandomNumberGenerator
) -> Vector2i:
    var eligible: Array[Vector2i] = []
    for fact in candidates:
        var key := LearningRules.fact_key(fact.x, fact.y)
        if key != previous_key and not used_keys.has(key):
            eligible.append(fact)
    if eligible.is_empty():
        for fact in candidates:
            if LearningRules.fact_key(fact.x, fact.y) != previous_key:
                eligible.append(fact)
    if eligible.is_empty():
        eligible = candidates.duplicate()

    var lowest := 101
    for fact in eligible:
        lowest = mini(lowest, profile.get_mastery(fact.x, fact.y))

    var tied: Array[Vector2i] = []
    for fact in eligible:
        if profile.get_mastery(fact.x, fact.y) == lowest:
            tied.append(fact)
    return tied[rng.randi_range(0, tied.size() - 1)]


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
    _shuffle(values, rng)
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
        _shuffle(same_distance, rng)
        candidates.append_array(same_distance)
    return candidates


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
    for index in range(values.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary := values[index]
        values[index] = values[other]
        values[other] = temporary
