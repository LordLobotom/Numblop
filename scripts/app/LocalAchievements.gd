class_name LocalAchievements
extends RefCounted

## Records which achievement rewards have already been paid out on this device.
##
## The granted set is the single guard that makes a reward one-time, whether it was earned in
## play or awarded retroactively from an older save.

var granted: Array[String] = []


func _init(data: Dictionary = {}) -> void:
    var loaded_granted: Variant = data.get("granted", [])
    if loaded_granted is Array:
        for raw_id in loaded_granted:
            if raw_id is not String:
                continue
            var achievement_id := String(raw_id)
            if AchievementCatalog.has_achievement(achievement_id) and not granted.has(achievement_id):
                granted.append(achievement_id)


func has_granted(achievement_id: String) -> bool:
    return granted.has(achievement_id)


## Marks an achievement as paid and returns its coin reward, or 0 when nothing is owed.
func grant(achievement_id: String) -> int:
    if not AchievementCatalog.has_achievement(achievement_id) or granted.has(achievement_id):
        return 0
    granted.append(achievement_id)
    return AchievementCatalog.reward_coins(achievement_id)


func to_dictionary() -> Dictionary:
    return {
        "granted": granted.duplicate(),
    }
