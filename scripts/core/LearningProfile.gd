class_name LearningProfile
extends RefCounted

const SAVE_VERSION := 2

var mastery: Dictionary = {}

## When each fact was last put in front of the child, as a caller-supplied timestamp.
## Zero means never. `scripts/core/` has no clock of its own, so whoever records the answer
## passes the time in; the rules here only ever compare these values to each other.
var last_practiced: Dictionary = {}
var highest_unlocked_index := 0
## The last table has no later table whose index can remember that its gate was passed.
## Keep that one completion separately so free practice never disappears after a mistake.
var final_table_completed := false


func _init() -> void:
    reset()


func reset() -> void:
    mastery.clear()
    last_practiced.clear()
    highest_unlocked_index = 0
    final_table_completed = false
    for table_value in LearningRules.TABLES:
        for multiplier in LearningRules.MULTIPLIERS:
            var key := LearningRules.fact_key(table_value, multiplier)
            mastery[key] = 0
            last_practiced[key] = 0


func current_table() -> int:
    return LearningRules.TABLES[highest_unlocked_index]


func is_table_practice_eligible(table_value: int) -> bool:
    var table_index := LearningRules.TABLES.find(table_value)
    if table_index < 0:
        return false
    if table_index == LearningRules.TABLES.size() - 1:
        return final_table_completed
    return table_index < highest_unlocked_index


func get_mastery(table_value: int, multiplier: int) -> int:
    return int(mastery.get(LearningRules.fact_key(table_value, multiplier), 0))


func set_mastery(table_value: int, multiplier: int, value: int) -> void:
    mastery[LearningRules.fact_key(table_value, multiplier)] = LearningRules.clamp_mastery(value)
    _advance_unlocks()


func get_last_practiced(table_value: int, multiplier: int) -> int:
    return int(last_practiced.get(LearningRules.fact_key(table_value, multiplier), 0))


## Records that a fact was just practised. `timestamp` comes from the caller because nothing
## in `scripts/core/` may read a clock; any monotonic value works, since it is only ever
## compared against other stamps to find the fact that has waited longest.
func mark_practiced(table_value: int, multiplier: int, timestamp: int) -> void:
    last_practiced[LearningRules.fact_key(table_value, multiplier)] = maxi(0, timestamp)


func record_answer(
    table_value: int,
    multiplier: int,
    correct: bool,
    elapsed_seconds: float
) -> int:
    var previous := get_mastery(table_value, multiplier)
    var mode := LearningRules.mode_for_mastery(previous)
    var delta := LearningRules.mastery_delta(correct, elapsed_seconds, mode)
    set_mastery(table_value, multiplier, previous + delta)
    return delta


func mastered_fact_count() -> int:
    var count := 0
    for value in mastery.values():
        if int(value) >= LearningRules.UNLOCK_MASTERY:
            count += 1
    return count


func to_dictionary() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "highest_unlocked_index": highest_unlocked_index,
        "final_table_completed": final_table_completed,
        "mastery": mastery.duplicate(true),
        "last_practiced": last_practiced.duplicate(true),
    }


static func from_dictionary(data: Dictionary) -> LearningProfile:
    var profile := LearningProfile.new()
    var saved_mastery: Variant = data.get("mastery", {})
    if saved_mastery is Dictionary:
        for key in profile.mastery.keys():
            if saved_mastery.has(key):
                profile.mastery[key] = LearningRules.clamp_mastery(int(saved_mastery[key]))
    # Version 1 saves have no timestamps. Leaving those facts at zero makes them look like
    # the longest-waiting ones, which is exactly right: nothing is known about when they were
    # last seen, so the review slot should visit them first.
    var saved_last_practiced: Variant = data.get("last_practiced", {})
    if saved_last_practiced is Dictionary:
        for key in profile.last_practiced.keys():
            if saved_last_practiced.has(key):
                profile.last_practiced[key] = maxi(0, int(saved_last_practiced[key]))
    profile.highest_unlocked_index = clampi(
        int(data.get("highest_unlocked_index", 0)),
        0,
        LearningRules.TABLES.size() - 1
    )
    var saved_final_completion: Variant = data.get("final_table_completed", false)
    profile.final_table_completed = (
        saved_final_completion is bool and bool(saved_final_completion)
    )
    profile._advance_unlocks()
    return profile


func _advance_unlocks() -> void:
    while highest_unlocked_index < LearningRules.TABLES.size() - 1:
        var table_value: int = LearningRules.TABLES[highest_unlocked_index]
        var ready_facts := 0
        for multiplier in LearningRules.MULTIPLIERS:
            if get_mastery(table_value, multiplier) >= LearningRules.UNLOCK_MASTERY:
                ready_facts += 1
        if ready_facts < LearningRules.REQUIRED_FACTS_TO_UNLOCK:
            break
        highest_unlocked_index += 1
    _remember_final_table_completion()


func _remember_final_table_completion() -> void:
    if final_table_completed or highest_unlocked_index < LearningRules.TABLES.size() - 1:
        return
    var final_table: int = LearningRules.TABLES.back()
    var ready_facts := 0
    for multiplier in LearningRules.MULTIPLIERS:
        if get_mastery(final_table, multiplier) >= LearningRules.UNLOCK_MASTERY:
            ready_facts += 1
    if ready_facts >= LearningRules.REQUIRED_FACTS_TO_UNLOCK:
        final_table_completed = true
