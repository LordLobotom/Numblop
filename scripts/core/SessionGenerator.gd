class_name SessionGenerator
extends RefCounted

const CURRENT := &"current"
const OLDER_WEAK := &"older_weak"
const OLDER_AUTOMATED := &"older_automated"

## Tables 2 to 5: seven from the table being learned, two older weak, one older automated.
const SLOT_PLAN: Array[StringName] = [
    CURRENT, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
    OLDER_AUTOMATED, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
]

## From the 6x table on: eight current, three older weak, one older automated. Both extra
## slots go to review, and the review slots stay spread out so no two land back to back.
const EXTENDED_SLOT_PLAN: Array[StringName] = [
    CURRENT, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
    OLDER_AUTOMATED, CURRENT, OLDER_WEAK, CURRENT, CURRENT,
    OLDER_WEAK, CURRENT,
]


static func slot_plan(table_value: int) -> Array[StringName]:
    return EXTENDED_SLOT_PLAN if LearningRules.uses_extended_mix(table_value) else SLOT_PLAN


static func generate(profile: LearningProfile, seed: int) -> Array[PracticeQuestion]:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var table_value := profile.current_table()
    var current_facts := _facts_for_table(table_value)
    var weak_facts := _older_facts(profile, false)
    var automated_facts := _older_facts(profile, true)
    var questions: Array[PracticeQuestion] = []
    var previous_key := ""
    var used_keys: Dictionary = {}

    for slot in slot_plan(table_value):
        var candidates: Array[Vector2i]
        match slot:
            OLDER_WEAK:
                candidates = weak_facts
            OLDER_AUTOMATED:
                candidates = automated_facts
            _:
                candidates = current_facts
        var borrowed := candidates.is_empty()
        if borrowed:
            candidates = current_facts
        # The automated slot exists to keep saturated facts from being forgotten, so it goes
        # to whichever has waited longest rather than to the weakest -- they are all at 100,
        # so mastery cannot tell them apart and would leave the choice entirely to the rng.
        var fact := (
            _select_least_recently_practiced(profile, candidates, previous_key, used_keys, rng)
            if slot == OLDER_AUTOMATED and not borrowed
            else _select_lowest_mastery(profile, candidates, previous_key, used_keys, rng)
        )
        var question := PracticeQuestionFactory.create(
            fact.x,
            fact.y,
            profile.get_mastery(fact.x, fact.y),
            rng
        )
        questions.append(question)
        previous_key = question.fact_key()
        used_keys[previous_key] = true

    assert(questions.size() == LearningRules.session_length(table_value))
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
            if automated == (value >= LearningRules.REVIEW_MASTERY):
                facts.append(Vector2i(table_value, multiplier))
    return facts


static func _select_lowest_mastery(
    profile: LearningProfile,
    candidates: Array[Vector2i],
    previous_key: String,
    used_keys: Dictionary,
    rng: RandomNumberGenerator
) -> Vector2i:
    var eligible := _eligible_facts(candidates, previous_key, used_keys)

    var lowest := 101
    for fact in eligible:
        lowest = mini(lowest, profile.get_mastery(fact.x, fact.y))

    var tied: Array[Vector2i] = []
    for fact in eligible:
        if profile.get_mastery(fact.x, fact.y) == lowest:
            tied.append(fact)
    return tied[rng.randi_range(0, tied.size() - 1)]


## Picks the fact that has gone longest without being asked, so the automated pool is
## cycled through rather than sampled. Facts never practised carry a zero stamp and so come
## first, which is what puts a freshly saturated fact into rotation straight away.
static func _select_least_recently_practiced(
    profile: LearningProfile,
    candidates: Array[Vector2i],
    previous_key: String,
    used_keys: Dictionary,
    rng: RandomNumberGenerator
) -> Vector2i:
    var eligible := _eligible_facts(candidates, previous_key, used_keys)

    var oldest := profile.get_last_practiced(eligible[0].x, eligible[0].y)
    for fact in eligible:
        oldest = mini(oldest, profile.get_last_practiced(fact.x, fact.y))

    # Everything that has waited the same length is equally overdue; the seed breaks it so a
    # cohort of never-practised facts is not always visited in table order.
    var tied: Array[Vector2i] = []
    for fact in eligible:
        if profile.get_last_practiced(fact.x, fact.y) == oldest:
            tied.append(fact)
    return tied[rng.randi_range(0, tied.size() - 1)]


## Prefers facts not already used this session, then anything but an immediate repeat, and
## only falls back to the whole pool when the pool is smaller than the slots asking for it.
static func _eligible_facts(
    candidates: Array[Vector2i],
    previous_key: String,
    used_keys: Dictionary
) -> Array[Vector2i]:
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
    return eligible


## Kept as a narrow compatibility seam for the distractor contract tests. Scheduling remains
## wholly inside this progression generator; question construction is shared by both modes.
static func _create_choices(
    table_value: int,
    multiplier: int,
    mode: int,
    rng: RandomNumberGenerator
) -> Array[int]:
    return PracticeQuestionFactory._create_choices(table_value, multiplier, mode, rng)
