class_name LocalStreak
extends RefCounted

const MAX_TIME_ZONE_OFFSET_MINUTES := 14 * 60

var current_count := 0
var all_time_high := 0
var milestones: Array[Dictionary] = []


func _init(data: Dictionary = {}) -> void:
    current_count = maxi(0, int(data.get("current_count", 0)))
    var loaded_high := maxi(0, int(data.get("all_time_high", 0)))
    var previous_count := 0
    var loaded_milestones: Variant = data.get("milestones", [])
    if loaded_milestones is Array:
        for raw_milestone in loaded_milestones:
            if raw_milestone is not Dictionary:
                continue
            var count := maxi(0, int(raw_milestone.get("count", 0)))
            if count <= previous_count:
                continue
            milestones.append({
                "count": count,
                "ended_at_unix": maxi(0, int(raw_milestone.get("ended_at_unix", 0))),
                "utc_offset_minutes": clampi(
                    int(raw_milestone.get("utc_offset_minutes", 0)),
                    -MAX_TIME_ZONE_OFFSET_MINUTES,
                    MAX_TIME_ZONE_OFFSET_MINUTES
                ),
            })
            previous_count = count
    all_time_high = maxi(loaded_high, previous_count)


func record_answer(
    correct: bool,
    ended_at_unix: int = 0,
    utc_offset_minutes: int = 0
) -> Dictionary:
    if correct:
        current_count += 1
        return {}

    var ended_count := current_count
    current_count = 0
    if ended_count <= all_time_high or ended_count <= 0:
        return {}

    all_time_high = ended_count
    var milestone := {
        "count": ended_count,
        "ended_at_unix": maxi(0, ended_at_unix),
        "utc_offset_minutes": clampi(
            utc_offset_minutes,
            -MAX_TIME_ZONE_OFFSET_MINUTES,
            MAX_TIME_ZONE_OFFSET_MINUTES
        ),
    }
    milestones.append(milestone)
    return milestone.duplicate(true)


## The record as a player sees it: an unbroken run counts the moment it passes the old high.
##
## `all_time_high` deliberately lags behind it, because it is what gates milestone rows above and
## the once-per-run record flash on the practice screen -- raising it mid-run would silence both.
func best_count() -> int:
    return maxi(all_time_high, current_count)


func to_dictionary() -> Dictionary:
    return {
        "current_count": current_count,
        "all_time_high": all_time_high,
        "milestones": milestones.duplicate(true),
    }
