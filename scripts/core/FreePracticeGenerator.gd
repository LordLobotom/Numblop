class_name FreePracticeGenerator
extends RefCounted

## Free practice is intentionally not a variant of SessionGenerator's progression slot plan.
## Empty selection means smart review across every permanently completed table; a non-empty
## selection uses a balanced seeded round-robin across exactly those tables.

const FACT_REPEAT_PENALTY := 25
const TABLE_REPEAT_PENALTY := 10


static func generate(
    profile: LearningProfile,
    selected_tables: Array[int],
    question_count: int,
    seed: int
) -> Array[PracticeQuestion]:
    assert(LearningRules.is_free_practice_length(question_count), "Unsupported free-practice length")
    var tables := _eligible_tables(profile, selected_tables)
    assert(not tables.is_empty(), "Free practice needs at least one completed table")

    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var automatic := selected_tables.is_empty()
    var table_counts: Dictionary = {}
    var fact_counts: Dictionary = {}
    for table_value in tables:
        table_counts[table_value] = 0

    var questions: Array[PracticeQuestion] = []
    var previous_key := ""
    var explicit_schedule: Array[int] = []
    if not automatic:
        explicit_schedule = _balanced_table_schedule(tables, question_count, rng)
    for question_index in question_count:
        var table_value := (
            _smart_table(profile, tables, table_counts, fact_counts, previous_key, rng)
            if automatic else int(explicit_schedule[question_index])
        )
        var fact := _select_fact(profile, table_value, fact_counts, previous_key, rng)
        var question := PracticeQuestionFactory.create(
            fact.x,
            fact.y,
            profile.get_mastery(fact.x, fact.y),
            rng
        )
        questions.append(question)
        table_counts[table_value] = int(table_counts.get(table_value, 0)) + 1
        previous_key = question.fact_key()
        fact_counts[previous_key] = int(fact_counts.get(previous_key, 0)) + 1
    return questions


static func eligible_tables(profile: LearningProfile) -> Array[int]:
    return _eligible_tables(profile, [])


static func _eligible_tables(
    profile: LearningProfile,
    selected_tables: Array[int]
) -> Array[int]:
    var requested: Dictionary = {}
    for table_value in selected_tables:
        requested[table_value] = true
    var tables: Array[int] = []
    for table_value in LearningRules.TABLES:
        if not profile.is_table_practice_eligible(table_value):
            continue
        if selected_tables.is_empty() or requested.has(table_value):
            tables.append(table_value)
    return tables


static func _balanced_table_schedule(
    tables: Array[int],
    question_count: int,
    rng: RandomNumberGenerator
) -> Array[int]:
    var schedule: Array[int] = []
    while schedule.size() < question_count:
        var cycle := tables.duplicate()
        PracticeQuestionFactory.shuffle_ints(cycle, rng)
        for table_value in cycle:
            schedule.append(table_value)
            if schedule.size() == question_count:
                break
    return schedule


static func _smart_table(
    profile: LearningProfile,
    tables: Array[int],
    table_counts: Dictionary,
    fact_counts: Dictionary,
    previous_key: String,
    rng: RandomNumberGenerator
) -> int:
    var lowest_score := 1_000_000
    var tied: Array[int] = []
    for table_value in tables:
        var candidate_score := _lowest_fact_score(
            profile,
            table_value,
            fact_counts,
            previous_key
        )
        var score := candidate_score + TABLE_REPEAT_PENALTY * int(table_counts[table_value])
        if score < lowest_score:
            lowest_score = score
            tied = [table_value]
        elif score == lowest_score:
            tied.append(table_value)
    return tied[rng.randi_range(0, tied.size() - 1)]


static func _lowest_fact_score(
    profile: LearningProfile,
    table_value: int,
    fact_counts: Dictionary,
    previous_key: String
) -> int:
    var lowest := 1_000_000
    for multiplier in LearningRules.MULTIPLIERS:
        var key := LearningRules.fact_key(table_value, multiplier)
        if key == previous_key and LearningRules.MULTIPLIERS.size() > 1:
            continue
        lowest = mini(lowest, _fact_score(profile, table_value, multiplier, fact_counts))
    return lowest


static func _select_fact(
    profile: LearningProfile,
    table_value: int,
    fact_counts: Dictionary,
    previous_key: String,
    rng: RandomNumberGenerator
) -> Vector2i:
    var lowest_score := 1_000_000
    var oldest_stamp := 0x7FFFFFFF
    var tied: Array[Vector2i] = []
    for multiplier in LearningRules.MULTIPLIERS:
        var key := LearningRules.fact_key(table_value, multiplier)
        if key == previous_key and LearningRules.MULTIPLIERS.size() > 1:
            continue
        var score := _fact_score(profile, table_value, multiplier, fact_counts)
        var stamp := profile.get_last_practiced(table_value, multiplier)
        if score < lowest_score or (score == lowest_score and stamp < oldest_stamp):
            lowest_score = score
            oldest_stamp = stamp
            tied = [Vector2i(table_value, multiplier)]
        elif score == lowest_score and stamp == oldest_stamp:
            tied.append(Vector2i(table_value, multiplier))
    return tied[rng.randi_range(0, tied.size() - 1)]


static func _fact_score(
    profile: LearningProfile,
    table_value: int,
    multiplier: int,
    fact_counts: Dictionary
) -> int:
    var key := LearningRules.fact_key(table_value, multiplier)
    return (
        profile.get_mastery(table_value, multiplier)
        + FACT_REPEAT_PENALTY * int(fact_counts.get(key, 0))
    )
