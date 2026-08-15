class_name LocalProgress
extends RefCounted

const MINIMUM_SESSION_REWARD := 1
const EXPERIENCE_PER_LEVEL := 100
const MASTERY_MILESTONE_COINS := 5

var coins := 0
var experience := 0
var completed_sessions := 0

## Lifetime coins earned from finished rounds and from mastery-band milestones, kept apart from the
## balance so that two devices can be reconciled. See `CoinLedger` for why a balance alone cannot.
## Achievement earnings are deliberately absent: they are derived from the granted set instead.
var earned_rounds := 0
var earned_milestones := 0

var _rewarded_result: SessionResult


func _init(data: Dictionary = {}) -> void:
    coins = maxi(0, int(data.get("coins", 0)))
    experience = maxi(0, int(data.get("experience", 0)))
    completed_sessions = maxi(0, int(data.get("completed_sessions", 0)))
    earned_rounds = maxi(0, int(data.get("earned_rounds", 0)))
    earned_milestones = maxi(0, int(data.get("earned_milestones", 0)))
    # Saves written before the counter existed still prove at least one finished round when
    # they carry experience, so retroactive achievements can see that first round.
    if completed_sessions == 0 and experience > 0:
        completed_sessions = 1


func level() -> int:
    return 1 + experience / EXPERIENCE_PER_LEVEL


func totals() -> Dictionary:
    return {
        "coins": coins,
        "experience": experience,
        "level": level(),
        "completed_sessions": completed_sessions,
        "earned_rounds": earned_rounds,
        "earned_milestones": earned_milestones,
    }


## The two stored ledger buckets, in the shape `SaveManager` takes.
func ledger() -> Dictionary:
    return {
        "earned_rounds": earned_rounds,
        "earned_milestones": earned_milestones,
    }


func grant_mastery_milestone() -> int:
    coins += MASTERY_MILESTONE_COINS
    earned_milestones += MASTERY_MILESTONE_COINS
    return MASTERY_MILESTONE_COINS


## Banks an achievement payout. No ledger bucket moves: achievement earnings are derived from the
## granted set by `CoinLedger`, and storing them twice would let the two disagree.
func grant_achievement_reward(reward_coins: int) -> int:
    var awarded := maxi(0, reward_coins)
    coins += awarded
    return awarded


func apply_completed_session(
    result: SessionResult,
    profile: LearningProfile,
    save_state: Callable
) -> Dictionary:
    if result == null or not result.can_receive_reward() or result == _rewarded_result:
        return {}

    var reward_amount := maxi(MINIMUM_SESSION_REWARD, result.correct_count())
    var updated_coins := coins + reward_amount
    var updated_experience := experience + reward_amount
    var previous_completed_sessions := completed_sessions
    var previous_earned_rounds := earned_rounds
    # The save callback reads the counter and the ledger off this object, so raise them before
    # writing and roll them back when the write fails.
    completed_sessions += 1
    earned_rounds += reward_amount
    if save_state.is_valid():
        var save_result: Variant = save_state.call(profile, updated_coins, updated_experience)
        if save_result is int and int(save_result) != OK:
            completed_sessions = previous_completed_sessions
            earned_rounds = previous_earned_rounds
            return {}

    coins = updated_coins
    experience = updated_experience
    _rewarded_result = result
    return {
        "coins": reward_amount,
        "experience": reward_amount,
        "total_coins": coins,
        "total_experience": experience,
        "level": level(),
        "completed_sessions": completed_sessions,
    }
