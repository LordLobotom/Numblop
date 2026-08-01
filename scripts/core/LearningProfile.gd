class_name LearningProfile
extends RefCounted

const SAVE_VERSION := 1

var mastery: Dictionary = {}
var highest_unlocked_index := 0


func _init() -> void:
    reset()


func reset() -> void:
    mastery.clear()
    highest_unlocked_index = 0
    for table_value in LearningRules.TABLES:
        for multiplier in LearningRules.MULTIPLIERS:
            mastery[LearningRules.fact_key(table_value, multiplier)] = 0


func current_table() -> int:
    return LearningRules.TABLES[highest_unlocked_index]


func get_mastery(table_value: int, multiplier: int) -> int:
    return int(mastery.get(LearningRules.fact_key(table_value, multiplier), 0))


func set_mastery(table_value: int, multiplier: int, value: int) -> void:
    mastery[LearningRules.fact_key(table_value, multiplier)] = LearningRules.clamp_mastery(value)
    _advance_unlocks()


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
        "mastery": mastery.duplicate(true),
    }


static func from_dictionary(data: Dictionary) -> LearningProfile:
    var profile := LearningProfile.new()
    var saved_mastery: Variant = data.get("mastery", {})
    if saved_mastery is Dictionary:
        for key in profile.mastery.keys():
            if saved_mastery.has(key):
                profile.mastery[key] = LearningRules.clamp_mastery(int(saved_mastery[key]))
    profile.highest_unlocked_index = clampi(
        int(data.get("highest_unlocked_index", 0)),
        0,
        LearningRules.TABLES.size() - 1
    )
    profile._advance_unlocks()
    return profile


func _advance_unlocks() -> void:
    while highest_unlocked_index < LearningRules.TABLES.size() - 1:
        var table_value: int = LearningRules.TABLES[highest_unlocked_index]
        var ready := true
        for multiplier in LearningRules.MULTIPLIERS:
            if get_mastery(table_value, multiplier) < LearningRules.UNLOCK_MASTERY:
                ready = false
                break
        if not ready:
            return
        highest_unlocked_index += 1
