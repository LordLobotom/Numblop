class_name CloudSaveMerge
extends RefCounted

## Reconciles two saves of the same profile into one, without losing anything a child earned.
##
## Pure and static: two dictionaries in, one dictionary out. No plugin, no network, no clock, no
## files. That is the whole point -- this is the code that can silently destroy a childhood of
## practice, so it is provable on a laptop long before any Play API exists.
##
## The governing rule: **never lose mastery, an owned item, an achievement, or a streak record.
## Accept small imprecision in the coin balance instead.** For a child, a hat disappearing is a
## betrayal; ending up fifty coins short of the arithmetic sum is invisible.
##
## Timestamps decide nothing on their own. A tablet clock can be wrong by years, and the failure
## mode is total: the wrong device would win every merge for good. `save_counter` leads, and
## `updated_at_unix` is only ever the last tie-breaker before an arbitrary-but-stable one.
##
## Both inputs must already have been through `SaveMigration`.

const COSMETIC_UNLOCK_KEYS: Array[String] = [
    "unlocked_body_colors",
    "unlocked_belly_colors",
    "unlocked_hats",
    "unlocked_glasses",
    "unlocked_necklaces",
    "unlocked_footwear",
]
const COSMETIC_SELECTION_KEYS: Array[String] = [
    "selected_body_color",
    "selected_belly_color",
    "selected_hat",
    "selected_glasses",
    "selected_necklace",
    "selected_footwear",
]

## Fields that describe *this device* rather than the player, and so are never taken from the
## other save. They are also the only reason `merge` is not perfectly commutative.
const DEVICE_LOCAL_FIELDS: Array[String] = ["profile_id", "cloud"]


## Merges `remote` into `local` and returns the combined save.
##
## Commutative in every field except those in `DEVICE_LOCAL_FIELDS`, which always come from
## `local`. Both devices therefore agree on the merged player state even if they merge in opposite
## directions, which is what stops a two-device loop from oscillating forever.
static func merge(local: Dictionary, remote: Dictionary) -> Dictionary:
    if remote.is_empty():
        return local.duplicate(true)
    if local.is_empty():
        var adopted := remote.duplicate(true)
        # A save adopted onto a device keeps that device's own identity and sync bookkeeping.
        for field in DEVICE_LOCAL_FIELDS:
            adopted.erase(field)
        return adopted

    var local_leads := base_is_local(local, remote)
    var base := local if local_leads else remote
    var other := remote if local_leads else local

    # Unknown fields from both, so a merge cannot delete what a newer build wrote. The base wins a
    # collision for the same reason it wins every other ambiguous field.
    var merged := _unknown_fields(other)
    merged.merge(_unknown_fields(base), true)

    var profile_data := _merge_learning_profile(local, remote)
    for key in profile_data:
        merged[key] = profile_data[key]

    var cosmetics := LocalCosmetics.new(_merge_cosmetics(local, remote, base))
    var achievements := LocalAchievements.new(_merge_achievements(local, remote))

    merged["version"] = SaveMigration.CURRENT_VERSION
    # The merged save must sort after both of its parents, or the next sync would treat it as the
    # stale side and merge it right back.
    merged["save_counter"] = maxi(
        _number(local, "save_counter"),
        _number(remote, "save_counter")
    )
    merged["updated_at_unix"] = maxi(
        _number(local, "updated_at_unix"),
        _number(remote, "updated_at_unix")
    )
    merged["experience"] = maxi(_number(local, "experience"), _number(remote, "experience"))
    merged["completed_sessions"] = maxi(
        _number(local, "completed_sessions"),
        _number(remote, "completed_sessions")
    )
    merged["earned_rounds"] = maxi(
        _number(local, "earned_rounds"),
        _number(remote, "earned_rounds")
    )
    merged["earned_milestones"] = maxi(
        _number(local, "earned_milestones"),
        _number(remote, "earned_milestones")
    )
    merged["cosmetics"] = cosmetics.to_dictionary()
    merged["achievements"] = achievements.to_dictionary()
    merged["streak"] = _merge_streak(local, remote, base)
    merged["onboarding"] = _merge_onboarding(local, remote)
    merged["nickname"] = _merge_nickname(base, other)
    # Recomputed rather than carried: a balance cannot be merged, but the ledger it is derived from
    # can. See `CoinLedger`.
    merged["coins"] = CoinLedger.balance(
        int(merged["earned_rounds"]),
        int(merged["earned_milestones"]),
        achievements.granted,
        cosmetics
    )
    merged["profile_id"] = _string(local, "profile_id")
    merged["cloud"] = LocalCloudSync.new(_dictionary(local, "cloud")).to_dictionary()
    return merged


## Picks the save that wins every genuinely ambiguous field.
##
## Ordered so that the strongest evidence of real play comes first and the clock comes last. The
## final tie-break on `profile_id` is arbitrary, but it is *stable*, which is what matters: both
## devices must reach the same answer whichever way round they merge.
static func base_is_local(local: Dictionary, remote: Dictionary) -> bool:
    for key in ["experience", "completed_sessions", "save_counter", "updated_at_unix"]:
        var local_value := _number(local, key)
        var remote_value := _number(remote, key)
        if local_value != remote_value:
            return local_value > remote_value
    return _string(local, "profile_id") >= _string(remote, "profile_id")


static func choose_base(local: Dictionary, remote: Dictionary) -> Dictionary:
    return local if base_is_local(local, remote) else remote


## Whether a save shows any real play. The caller uses it to tell a first sign-in apart from a
## genuine two-device conflict, which changes what the child is told rather than what is merged.
static func has_progress(data: Dictionary) -> bool:
    if data.is_empty():
        return false
    return (
        _number(data, "experience") > 0
        or _number(data, "completed_sessions") > 0
        or _number(data, "highest_unlocked_index") > 0
    )


static func _merge_learning_profile(local: Dictionary, remote: Dictionary) -> Dictionary:
    var local_profile := LearningProfile.from_dictionary(local)
    var remote_profile := LearningProfile.from_dictionary(remote)
    var merged_profile := LearningProfile.new()
    for table_value in LearningRules.TABLES:
        for multiplier in LearningRules.MULTIPLIERS:
            merged_profile.set_mastery(
                table_value,
                multiplier,
                maxi(
                    local_profile.get_mastery(table_value, multiplier),
                    remote_profile.get_mastery(table_value, multiplier)
                )
            )
            merged_profile.mark_practiced(
                table_value,
                multiplier,
                maxi(
                    local_profile.get_last_practiced(table_value, multiplier),
                    remote_profile.get_last_practiced(table_value, multiplier)
                )
            )
    # Unlocking is monotonic, and an island already opened must never close again -- not even when
    # the fact that opened it has since dropped back below the gate on one of the two devices.
    merged_profile.highest_unlocked_index = maxi(
        merged_profile.highest_unlocked_index,
        maxi(local_profile.highest_unlocked_index, remote_profile.highest_unlocked_index)
    )
    return merged_profile.to_dictionary()


static func _merge_cosmetics(
    local: Dictionary,
    remote: Dictionary,
    base: Dictionary
) -> Dictionary:
    var local_cosmetics := _dictionary(local, "cosmetics")
    var remote_cosmetics := _dictionary(remote, "cosmetics")
    var merged: Dictionary = {}
    for key in COSMETIC_UNLOCK_KEYS:
        merged[key] = _union(local_cosmetics.get(key, []), remote_cosmetics.get(key, []))
    # What is *worn* is a preference, so it follows the base. `LocalCosmetics` drops a selection the
    # merged inventory does not actually own, so this cannot equip something unpaid for.
    var base_cosmetics := _dictionary(base, "cosmetics")
    for key in COSMETIC_SELECTION_KEYS:
        if base_cosmetics.has(key):
            merged[key] = base_cosmetics[key]
    return merged


static func _merge_achievements(local: Dictionary, remote: Dictionary) -> Dictionary:
    return {
        "granted": _union(
            _dictionary(local, "achievements").get("granted", []),
            _dictionary(remote, "achievements").get("granted", [])
        ),
    }


## Unions the record milestones and keeps the running count from the base.
##
## Two devices can each hold a record the other never saw, and both are real. Where both recorded
## the same length, the earlier one is the one that happened. `LocalStreak` then re-applies its own
## strictly-increasing rule, which is why the rows are sorted before they are handed over.
static func _merge_streak(local: Dictionary, remote: Dictionary, base: Dictionary) -> Dictionary:
    var local_streak := _dictionary(local, "streak")
    var remote_streak := _dictionary(remote, "streak")
    var by_count: Dictionary = {}
    for source in [local_streak, remote_streak]:
        var rows: Variant = source.get("milestones", [])
        if rows is not Array:
            continue
        for row in rows:
            if row is not Dictionary:
                continue
            var count := maxi(0, int(row.get("count", 0)))
            if count <= 0:
                continue
            var ended_at := maxi(0, int(row.get("ended_at_unix", 0)))
            if by_count.has(count) and int(by_count[count]["ended_at_unix"]) <= ended_at:
                continue
            by_count[count] = row.duplicate(true)
    var counts := by_count.keys()
    counts.sort()
    var milestones: Array = []
    for count in counts:
        milestones.append(by_count[count])
    return LocalStreak.new({
        "current_count": _dictionary(base, "streak").get("current_count", 0),
        "all_time_high": maxi(
            maxi(0, int(local_streak.get("all_time_high", 0))),
            maxi(0, int(remote_streak.get("all_time_high", 0)))
        ),
        "milestones": milestones,
    }).to_dictionary()


## Finished on either device means finished. A child who has been walked through the tutorial once
## must never be walked through it again because their other phone had not caught up.
static func _merge_onboarding(local: Dictionary, remote: Dictionary) -> Dictionary:
    var local_onboarding := LocalOnboarding.new(_dictionary(local, "onboarding"))
    var remote_onboarding := LocalOnboarding.new(_dictionary(remote, "onboarding"))
    return LocalOnboarding.new({
        "completed": local_onboarding.completed or remote_onboarding.completed,
        "step": maxi(local_onboarding.step, remote_onboarding.step),
    }).to_dictionary()


static func _merge_nickname(base: Dictionary, other: Dictionary) -> String:
    var chosen := LocalNickname.sanitize(_string(base, "nickname"))
    if not chosen.is_empty():
        return chosen
    return LocalNickname.sanitize(_string(other, "nickname"))


static func _unknown_fields(data: Dictionary) -> Dictionary:
    var preserved: Dictionary = {}
    for key in data:
        var name := String(key)
        if not SaveManager.KNOWN_FIELDS.has(name):
            preserved[name] = data[key]
    return preserved


## Union of two id arrays, sorted so both devices produce a byte-identical result.
static func _union(first: Variant, second: Variant) -> Array:
    var combined: Array = []
    for source in [first, second]:
        if source is not Array:
            continue
        for value in source:
            if value is String and not combined.has(value):
                combined.append(value)
    combined.sort()
    return combined


static func _number(data: Dictionary, key: String) -> int:
    var raw: Variant = data.get(key, 0)
    if raw is float or raw is int:
        return maxi(0, int(raw))
    return 0


static func _string(data: Dictionary, key: String) -> String:
    var raw: Variant = data.get(key, "")
    return raw if raw is String else ""


static func _dictionary(data: Dictionary, key: String) -> Dictionary:
    var raw: Variant = data.get(key, {})
    return raw if raw is Dictionary else {}
