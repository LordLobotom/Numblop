class_name AchievementCatalog
extends RefCounted

## Deterministic definition and evaluation of every achievement.
##
## The catalog is pure: it never touches scenes, autoloads, saves, or the clock. Callers pass
## the player statistics in and receive progress values back, so the same statistics always
## produce the same result. Award bookkeeping lives in `LocalAchievements`.

const KIND_FIRST_SESSION := "first_session"
const KIND_STREAK := "streak"
const KIND_EXPERIENCE := "experience"
const KIND_COLLECTION := "collection"
const KIND_ISLAND := "island"

const FIRST_STEPS_ID := "first_steps"
const FIRST_STEPS_REWARD_COINS := 100
const STREAK_TARGETS: Array[int] = [10, 20, 50, 100, 500, 1000]
## A streak pays one coin per answer in it, but never more than a collection is worth.
const STREAK_MAX_REWARD_COINS := 50
const EXPERIENCE_TARGETS: Array[int] = [500, 1000, 5000, 10000]
const EXPERIENCE_ID_PREFIX := "experience_"
const EXPERIENCE_REWARD_COINS := 50
const COLLECTION_ID_PREFIX := "collection_"
const COLLECTION_REWARD_COINS := 50
## Paid item count per cosmetic category, in shop tab order.
##
## The numbers are restated here rather than read from `CosmeticCatalog`, which lives in the app
## layer: the core stays independent, and `test_achievement_catalog.gd` pins the two together so
## a new cosmetic cannot ship without a deliberate decision about the collection it belongs to.
const COLLECTION_TARGETS: Dictionary = {
    "body_color": 5,
    "belly_color": 6,
    "hat": 6,
    "glasses": 5,
    "necklace": 5,
    "footwear": 5,
}
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
            "reward_coins": mini(target, STREAK_MAX_REWARD_COINS),
        })
    for target in EXPERIENCE_TARGETS:
        catalog.append({
            "id": experience_id(target),
            "kind": KIND_EXPERIENCE,
            "title_key": "ACHIEVEMENT_EXPERIENCE_TITLE",
            "description_key": "ACHIEVEMENT_EXPERIENCE_DESC",
            "format_args": {"count": target},
            "table": 0,
            "target": target,
            "reward_coins": EXPERIENCE_REWARD_COINS,
        })
    for category in COLLECTION_TARGETS:
        var category_name := String(category)
        var owned_target := int(COLLECTION_TARGETS[category])
        catalog.append({
            "id": collection_id(category_name),
            "kind": KIND_COLLECTION,
            "category": category_name,
            "title_key": "ACHIEVEMENT_COLLECTION_%s_TITLE" % category_name.to_upper(),
            "description_key": "ACHIEVEMENT_COLLECTION_%s_DESC" % category_name.to_upper(),
            "format_args": {"count": owned_target},
            "table": 0,
            "target": owned_target,
            "reward_coins": COLLECTION_REWARD_COINS,
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


static func experience_id(target: int) -> String:
    return "%s%d" % [EXPERIENCE_ID_PREFIX, target]


static func collection_id(category: String) -> String:
    return "%s%s" % [COLLECTION_ID_PREFIX, category]


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
## `statistics` accepts `completed_sessions`, `best_streak`, and `experience` integers plus an
## `owned_cosmetics` map of category to purchased item count; mastery is read from `profile` so
## island achievements stay in sync with the learning core.
## Experience equals the lifetime count of correctly answered questions.
static func evaluate(profile: LearningProfile, statistics: Dictionary) -> Array[Dictionary]:
    var completed_sessions := maxi(0, int(statistics.get("completed_sessions", 0)))
    var best_streak := maxi(0, int(statistics.get("best_streak", 0)))
    var experience := maxi(0, int(statistics.get("experience", 0)))
    var owned_cosmetics: Dictionary = statistics.get("owned_cosmetics", {})
    var evaluated: Array[Dictionary] = []
    for entry in definitions():
        var target := int(entry["target"])
        var progress := 0
        match String(entry["kind"]):
            KIND_FIRST_SESSION:
                progress = completed_sessions
            KIND_STREAK:
                progress = best_streak
            KIND_EXPERIENCE:
                progress = experience
            KIND_COLLECTION:
                progress = maxi(0, int(owned_cosmetics.get(entry["category"], 0)))
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
