class_name CoinLedger
extends RefCounted

## Lifetime coin accounting, split so two devices can be reconciled without inventing or destroying
## currency.
##
## A balance cannot be merged. Two devices that each earn 100 coins and each buy a different hat
## both end up reading 0, and nothing in those two numbers says the child owns two hats. Earnings
## can be merged, because every term below is either a monotonic counter or is derived from a set
## that unions cleanly -- the granted achievements and the owned cosmetics. Both devices therefore
## compute the same balance from the same merged state, which is what makes cloud save safe.
##
## Pure and static: no scenes, no autoloads, no files, no clock.

## Coins already paid out for achievements.
##
## Derived rather than stored, because the granted set is what a merge unions; a stored total would
## have to be reconciled separately and could disagree with it.
static func achievement_coins(granted_ids: Array) -> int:
    var total := 0
    for raw_id in granted_ids:
        if raw_id is String:
            total += AchievementCatalog.reward_coins(String(raw_id))
    return total


## Coins spent on cosmetics, derived from what is owned.
##
## Free default items cost nothing and are skipped, so a fresh profile has spent zero.
static func spent_coins(cosmetics: LocalCosmetics) -> int:
    if cosmetics == null:
        return 0
    var total := 0
    for category in CosmeticCatalog.CATEGORIES:
        for item in CosmeticCatalog.items(category):
            var price := int(item["price"])
            if price > 0 and cosmetics.owns_item(category, String(item["id"])):
                total += price
    return total


## The balance the ledger implies. Never negative.
##
## During play the stored `coins` value stays authoritative and this is not re-derived on every
## load; a divergence between the two means a bug, and `tests/state/test_coin_ledger.gd` pins them
## together over the paths that grant and spend. A merge recomputes the balance with this.
static func balance(
    earned_rounds: int,
    earned_milestones: int,
    granted_ids: Array,
    cosmetics: LocalCosmetics
) -> int:
    var earned := (
        maxi(0, earned_rounds)
        + maxi(0, earned_milestones)
        + achievement_coins(granted_ids)
    )
    return maxi(0, earned - spent_coins(cosmetics))


## Reconstructs the round bucket for a save written before the ledger existed.
##
## Everything not derivable is attributed to rounds: the split between rounds and milestones cannot
## be recovered after the fact, and only the sum of the two buckets is ever used. Flooring at zero
## keeps a hand-edited or corrupt save from producing a negative counter that would then be treated
## as a real earning history.
static func backfill_earned_rounds(
    coins: int,
    granted_ids: Array,
    cosmetics: LocalCosmetics
) -> int:
    return maxi(0, coins + spent_coins(cosmetics) - achievement_coins(granted_ids))
