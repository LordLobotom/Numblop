class_name AchievementCatalog
extends RefCounted

## Deterministic definition and evaluation of every achievement.
##
## The catalog is pure: it never touches scenes, autoloads, saves, or the clock. Callers pass
## the player statistics in and receive progress values back, so the same statistics always
## produce the same result. Award bookkeeping lives in `LocalAchievements`.

const KIND_FIRST_SESSION := "first_session"
const KIND_STREAK := "streak"
const KIND_ISLAND := "island"

const FIRST_STEPS_ID := "first_steps"
const FIRST_STEPS_REWARD_COINS := 100
const STREAK_TARGETS: Array[int] = [10, 20, 50, 100]
const ISLAND_ID_PREFIX := "island_"
const ISLAND_REWARD_COINS := 50
const ISLAND_MASTERY_TARGET := 100


static func definitions() -> Array[Dictionary]:
    var catalog: Array[Dictionary] = []
    catalog.append({
        "id": FIRST_STEPS_ID,
        "kind": KIND_FIRST_SESSION,
        "title_key": "ACHIEVEMENT_FIRST_STEPS_TITLE",
        "description_key": "ACHIEVEMENT_FIRST_STEPS_DESC",
        "format_args": {},
        "table": 0,
        "target": 1,
        "reward_coins": FIRST_STEPS_REWARD_COINS,
    })
    for target in STREAK_TARGETS:
        catalog.append({
            "id": streak_id(target),
            "kind": KIND_STREAK,
            "title_key": "ACHIEVEMENT_STREAK_TITLE",
            "description_key": "ACHIEVEMENT_STREAK_DESC",
            "format_args": {"count": target},
            "table": 0,
            "target": target,
            "reward_coins": target,
        })
    for table_value in LearningRules.TABLES:
        catalog.append({
            "id": island_id(table_value),
            "kind": KIND_ISLAND,
            "title_key": "ACHIEVEMENT_ISLAND_TITLE",
            "description_key": "ACHIEVEMENT_ISLAND_DESC",
            "format_args": {"table": table_value},
            "table": table_value,
            "target": LearningRules.MULTIPLIERS.size(),
            "reward_coins": ISLAND_REWARD_COINS,
        })
    return catalog


static func streak_id(target: int) -> String:
    return "streak_%d" % target


static func island_id(table_value: int) -> String:
    return "%s%d" % [ISLAND_ID_PREFIX, table_value]


static func has_achievement(achievement_id: String) -> bool:
    return not definition(achievement_id).is_empty()


static func definition(achievement_id: String) -> Dictionary:
    for entry in definitions():
        if String(entry["id"]) == achievement_id:
            return entry
    return {}


static func reward_coins(achievement_id: String) -> int:
    var entry := definition(achievement_id)
    return int(entry.get("reward_coins", 0))


## Returns every achievement with its current `progress`, `target`, and `completed` flag.
##
## `statistics` accepts `completed_sessions` and `best_streak` integers; mastery is read from
## `profile` so island achievements stay in sync with the learning core.
static func evaluate(profile: LearningProfile, statistics: Dictionary) -> Array[Dictionary]:
    var completed_sessions := maxi(0, int(statistics.get("completed_sessions", 0)))
    var best_streak := maxi(0, int(statistics.get("best_streak", 0)))
    var evaluated: Array[Dictionary] = []
    for entry in definitions():
        var target := int(entry["target"])
        var progress := 0
        match String(entry["kind"]):
            KIND_FIRST_SESSION:
                progress = completed_sessions
            KIND_STREAK:
                progress = best_streak
            KIND_ISLAND:
                progress = _fully_mastered_fact_count(profile, int(entry["table"]))
        progress = clampi(progress, 0, target)
        entry["progress"] = progress
        entry["completed"] = progress >= target
        evaluated.append(entry)
    return evaluated


static func _fully_mastered_fact_count(profile: LearningProfile, table_value: int) -> int:
    if profile == null:
        return 0
    var count := 0
    for multiplier in LearningRules.MULTIPLIERS:
        if profile.get_mastery(table_value, multiplier) >= ISLAND_MASTERY_TARGET:
            count += 1
    return count
