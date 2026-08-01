class_name LocalProgress
extends RefCounted

const SESSION_REWARD_COINS := 10
const SESSION_REWARD_EXPERIENCE := 10
const EXPERIENCE_PER_LEVEL := 100

var coins := 0
var experience := 0

var _rewarded_result: SessionResult


func _init(data: Dictionary = {}) -> void:
    coins = maxi(0, int(data.get("coins", 0)))
    experience = maxi(0, int(data.get("experience", 0)))


func level() -> int:
    return 1 + experience / EXPERIENCE_PER_LEVEL


func totals() -> Dictionary:
    return {
        "coins": coins,
        "experience": experience,
        "level": level(),
    }


func apply_completed_session(
    result: SessionResult,
    profile: LearningProfile,
    save_state: Callable
) -> Dictionary:
    if result == null or not result.can_receive_reward() or result == _rewarded_result:
        return {}

    var updated_coins := coins + SESSION_REWARD_COINS
    var updated_experience := experience + SESSION_REWARD_EXPERIENCE
    if save_state.is_valid():
        var save_result: Variant = save_state.call(profile, updated_coins, updated_experience)
        if save_result is int and int(save_result) != OK:
            return {}

    coins = updated_coins
    experience = updated_experience
    _rewarded_result = result
    return {
        "coins": SESSION_REWARD_COINS,
        "experience": SESSION_REWARD_EXPERIENCE,
        "total_coins": coins,
        "total_experience": experience,
        "level": level(),
    }
