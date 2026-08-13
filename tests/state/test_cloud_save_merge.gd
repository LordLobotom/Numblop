extends NumblopTestCase

## The merge is the one piece of the cloud-save work that can silently destroy a childhood of
## practice, so it is tested exhaustively here with no plugin, no network, and no device.
##
## Two properties matter more than any individual field rule. **Commutativity**: both devices must
## compute the same player state whichever way round they merge, or a two-device pair oscillates
## forever. **Never losing anything earned**: mastery, items, achievements and streak records only
## ever move upward through a merge.


func test_merging_a_save_with_itself_changes_nothing() -> void:
    var save := _save({"experience": 120, "completed_sessions": 12, "save_counter": 30})
    var merged := CloudSaveMerge.merge(save, save.duplicate(true))
    equal(merged["experience"], 120, "Experience unchanged")
    equal(merged["completed_sessions"], 12, "Rounds unchanged")
    equal(merged["coins"], save["coins"], "Balance unchanged")


func test_merging_is_commutative_for_everything_but_this_device_s_own_fields() -> void:
    var alpha := _save({
        "experience": 300,
        "completed_sessions": 30,
        "save_counter": 90,
        "coins": 150,
        "mastery": {"2_x_3": 80, "4_x_4": 40},
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_HAT, "hat_crown"]]),
        "granted": ["first_steps"],
        "profile_id": "aaaa",
    })
    var beta := _save({
        "experience": 260,
        "completed_sessions": 24,
        "save_counter": 140,
        "coins": 260,
        "mastery": {"2_x_3": 55, "4_x_4": 100},
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_GLASSES, "glasses_star"]]),
        "granted": ["streak_10"],
        "profile_id": "bbbb",
    })

    var forward := CloudSaveMerge.merge(alpha, beta)
    var backward := CloudSaveMerge.merge(beta, alpha)
    for field in CloudSaveMerge.DEVICE_LOCAL_FIELDS:
        forward.erase(field)
        backward.erase(field)
    check(
        forward.hash() == backward.hash(),
        "Both directions produce the same player state"
    )


func test_this_device_keeps_its_own_identity_and_sync_bookkeeping() -> void:
    var local := _save({"experience": 10, "profile_id": "local_id"})
    local["cloud"] = {"last_synced_counter": 8, "last_synced_at_unix": 5, "player_id": "me"}
    var remote := _save({"experience": 500, "profile_id": "remote_id"})
    remote["cloud"] = {"last_synced_counter": 99, "last_synced_at_unix": 9, "player_id": "them"}

    var merged := CloudSaveMerge.merge(local, remote)
    equal(merged["profile_id"], "local_id", "The device pseudonym is not adopted from elsewhere")
    equal(merged["cloud"]["last_synced_counter"], 8, "Sync bookkeeping stays device-local")
    equal(merged["experience"], 500, "The player state still merges")


func test_mastery_and_practice_stamps_take_the_higher_value_per_fact() -> void:
    var local := _save({"mastery": {"2_x_1": 90, "3_x_5": 10}, "last_practiced": {"2_x_1": 500}})
    var remote := _save({"mastery": {"2_x_1": 40, "3_x_5": 75}, "last_practiced": {"2_x_1": 900}})

    var merged := CloudSaveMerge.merge(local, remote)
    equal(merged["mastery"]["2_x_1"], 90, "The stronger value wins")
    equal(merged["mastery"]["3_x_5"], 75, "Per fact, not per save")
    equal(merged["last_practiced"]["2_x_1"], 900, "The more recent practice stamp wins")


func test_an_unlocked_island_never_closes_again() -> void:
    # One device unlocked the 3x table and then let a fact rot back below the gate. The other
    # never got there. Neither may take the island away.
    var unlocked := _save({"highest_unlocked_index": 1, "experience": 10})
    var behind := _save({"highest_unlocked_index": 0, "experience": 900})

    var merged := CloudSaveMerge.merge(behind, unlocked)
    equal(merged["highest_unlocked_index"], 1, "The unlock survives even from the losing save")


func test_owned_items_from_both_devices_are_kept() -> void:
    var local := _save({
        "cosmetics": _owning([
            [CosmeticCatalog.CATEGORY_HAT, "hat_dino"],
            [CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink"],
        ]),
    })
    var remote := _save({
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_HAT, "hat_pirat"]]),
    })

    var merged := CloudSaveMerge.merge(local, remote)
    var hats: Array = merged["cosmetics"]["unlocked_hats"]
    contains(hats, "hat_dino", "Locally bought hat kept")
    contains(hats, "hat_pirat", "Remotely bought hat kept")
    contains(merged["cosmetics"]["unlocked_belly_colors"], "pink", "Other categories union too")


func test_achievements_and_streak_records_from_both_devices_are_kept() -> void:
    var local := _save({
        "granted": ["first_steps", "streak_10"],
        "milestones": [{"count": 11, "ended_at_unix": 100, "utc_offset_minutes": 60}],
        "all_time_high": 11,
    })
    var remote := _save({
        "granted": ["island_2"],
        "milestones": [{"count": 25, "ended_at_unix": 300, "utc_offset_minutes": 60}],
        "all_time_high": 25,
    })

    var merged := CloudSaveMerge.merge(local, remote)
    var granted: Array = merged["achievements"]["granted"]
    equal(granted.size(), 3, "Every achievement survives")
    contains(granted, "island_2", "Remote achievement kept")
    equal(merged["streak"]["all_time_high"], 25, "The better record wins")
    equal(merged["streak"]["milestones"].size(), 2, "Both record rows survive")


func test_the_same_record_length_keeps_the_earlier_moment() -> void:
    var local := _save({
        "milestones": [{"count": 20, "ended_at_unix": 900, "utc_offset_minutes": 0}],
        "all_time_high": 20,
    })
    var remote := _save({
        "milestones": [{"count": 20, "ended_at_unix": 400, "utc_offset_minutes": 0}],
        "all_time_high": 20,
    })

    var merged := CloudSaveMerge.merge(local, remote)
    equal(merged["streak"]["milestones"].size(), 1, "The same length is one record, not two")
    equal(
        merged["streak"]["milestones"][0]["ended_at_unix"],
        400,
        "The run that actually happened first is the one that is kept"
    )


func test_the_tutorial_is_never_replayed_because_one_device_lagged() -> void:
    var finished := _save({"onboarding": {"completed": true, "step": 9}, "experience": 5})
    var midway := _save({"onboarding": {"completed": false, "step": 3}, "experience": 800})

    var merged := CloudSaveMerge.merge(midway, finished)
    check(merged["onboarding"]["completed"], "Finished on either device means finished")


func test_divergent_offline_purchases_keep_both_items_without_inventing_coins() -> void:
    # The scenario the whole ledger exists for: two devices, both offline, each earning and each
    # buying something different.
    var local := _save({
        "experience": 100,
        "earned_rounds": 400,
        "coins": 300,
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_HAT, "hat_crown"]]),
    })
    var remote := _save({
        "experience": 100,
        "earned_rounds": 400,
        "coins": 300,
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_GLASSES, "glasses_moon"]]),
    })

    var merged := CloudSaveMerge.merge(local, remote)
    contains(merged["cosmetics"]["unlocked_hats"], "hat_crown", "Both items survive")
    contains(merged["cosmetics"]["unlocked_glasses"], "glasses_moon", "Both items survive")
    # 400 earned, two 100-coin items owned. The documented downward imprecision: the child keeps
    # everything and is 100 short of adding the two balances together.
    equal(merged["coins"], 200, "Coins are recomputed from the ledger, never summed")


func test_the_merged_balance_is_never_negative() -> void:
    var poor := _save({
        "earned_rounds": 0,
        "coins": 0,
        "cosmetics": _owning([
            [CosmeticCatalog.CATEGORY_HAT, "hat_crown"],
            [CosmeticCatalog.CATEGORY_GLASSES, "glasses_star"],
        ]),
    })
    var merged := CloudSaveMerge.merge(poor, _save({"earned_rounds": 50}))
    equal(merged["coins"], 0, "Owning more than was ever earned clamps at zero")


func test_the_merged_balance_never_exceeds_what_was_earned() -> void:
    var local := _save({"earned_rounds": 500, "earned_milestones": 25, "granted": ["first_steps"]})
    var remote := _save({"earned_rounds": 450, "earned_milestones": 60, "granted": ["streak_20"]})

    var merged := CloudSaveMerge.merge(local, remote)
    # max(500,450) + max(25,60) + 100 + 20, nothing spent.
    equal(merged["coins"], 680, "Each bucket takes its own maximum; nothing is double counted")


func test_a_fresh_device_adopts_the_cloud_save_whole() -> void:
    var fresh := _save({})
    var populated := _save({
        "experience": 640,
        "completed_sessions": 64,
        "coins": 220,
        "earned_rounds": 640,
        "highest_unlocked_index": 3,
    })

    check(not CloudSaveMerge.has_progress(fresh), "A fresh save shows no play")
    check(CloudSaveMerge.has_progress(populated), "A played save does")
    var merged := CloudSaveMerge.merge(fresh, populated)
    equal(merged["experience"], 640, "The reinstall case restores everything")
    equal(merged["highest_unlocked_index"], 3, "Including the map position")
    equal(merged["coins"], 640, "And the balance the ledger implies")


func test_an_empty_cloud_leaves_the_local_save_alone() -> void:
    var local := _save({"experience": 90, "coins": 40, "earned_rounds": 90})
    var merged := CloudSaveMerge.merge(local, {})
    equal(merged["experience"], 90, "Nothing to merge means nothing changes")
    equal(merged["coins"], 40, "Including the balance, which is not recomputed")


func test_an_adopted_save_does_not_bring_the_other_device_s_identity_with_it() -> void:
    var populated := _save({"experience": 200, "profile_id": "other_device"})
    var merged := CloudSaveMerge.merge({}, populated)
    check(not merged.has("profile_id"), "The new device generates its own id on the next save")
    check(not merged.has("cloud"), "And its own sync bookkeeping")


func test_the_merged_save_sorts_after_both_of_its_parents() -> void:
    # Otherwise the next sync would treat the merge result as the stale side and merge it back.
    var local := _save({"save_counter": 40})
    var remote := _save({"save_counter": 900})
    var merged := CloudSaveMerge.merge(local, remote)
    equal(merged["save_counter"], 900, "At least as high as the highest parent")


func test_a_wildly_wrong_clock_cannot_win_a_merge_on_its_own() -> void:
    # The failure mode that makes timestamp-wins unusable: one device a year fast would otherwise
    # erase the other one permanently.
    var real := _save({
        "experience": 900,
        "completed_sessions": 90,
        "save_counter": 400,
        "updated_at_unix": 1786000000,
        "nickname": "Anicka",
    })
    var wrong_clock := _save({
        "experience": 20,
        "completed_sessions": 2,
        "save_counter": 3,
        "updated_at_unix": 1917000000,
        "nickname": "Junk",
    })

    check(
        CloudSaveMerge.base_is_local(real, wrong_clock),
        "Evidence of real play outranks a clock"
    )
    equal(CloudSaveMerge.merge(wrong_clock, real)["nickname"], "Anicka", "And decides preferences")


func test_a_nickname_is_taken_from_the_other_save_only_when_the_base_has_none() -> void:
    var base_with_name := _save({"experience": 500, "nickname": "Kuba"})
    var other_with_name := _save({"experience": 10, "nickname": "Pepa"})
    equal(
        CloudSaveMerge.merge(base_with_name, other_with_name)["nickname"],
        "Kuba",
        "The leading save keeps its name"
    )

    var base_without := _save({"experience": 500})
    equal(
        CloudSaveMerge.merge(base_without, other_with_name)["nickname"],
        "Pepa",
        "An empty name is filled in rather than left blank"
    )


func test_an_equipped_item_the_merge_does_not_own_falls_back_to_the_default() -> void:
    var local := _save({"experience": 500})
    local["cosmetics"]["selected_hat"] = "hat_santa"
    var remote := _save({"experience": 10})

    var merged := CloudSaveMerge.merge(local, remote)
    equal(
        merged["cosmetics"]["selected_hat"],
        CosmeticCatalog.DEFAULT_HAT_ID,
        "A selection nothing paid for cannot survive the merge"
    )


func test_unknown_fields_from_either_save_survive_the_merge() -> void:
    var local := _save({"experience": 500})
    local["from_a_newer_build"] = {"keep": "me"}
    var remote := _save({"experience": 10})
    remote["another_new_field"] = 7

    var merged := CloudSaveMerge.merge(local, remote)
    check(merged.has("from_a_newer_build"), "The base's unknown field survives")
    check(merged.has("another_new_field"), "So does the other save's")


func test_the_merged_save_is_a_valid_save_the_loaders_accept() -> void:
    var local := _save({
        "experience": 310,
        "completed_sessions": 31,
        "earned_rounds": 310,
        "granted": ["first_steps"],
        "cosmetics": _owning([[CosmeticCatalog.CATEGORY_FOOTWEAR, "footwear_star"]]),
    })
    var remote := _save({"experience": 280, "mastery": {"5_x_5": 100}})
    var merged := CloudSaveMerge.merge(local, remote)

    equal(merged["version"], SaveMigration.CURRENT_VERSION, "Stamped with the current schema")
    equal(LearningProfile.from_dictionary(merged).get_mastery(5, 5), 100, "Profile loads")
    equal(
        LocalProgress.new(merged).coins,
        merged["coins"],
        "Progress loads the recomputed balance"
    )
    contains(
        LocalCosmetics.new(merged["cosmetics"]).unlocked_footwear,
        "footwear_star",
        "Cosmetics load"
    )


## Builds a migrated save dictionary. Only the fields a case cares about need naming.
func _save(overrides: Dictionary) -> Dictionary:
    var data := LearningProfile.new().to_dictionary()
    data["version"] = SaveMigration.CURRENT_VERSION
    data["coins"] = overrides.get("coins", 0)
    data["experience"] = overrides.get("experience", 0)
    data["completed_sessions"] = overrides.get("completed_sessions", 0)
    data["earned_rounds"] = overrides.get("earned_rounds", 0)
    data["earned_milestones"] = overrides.get("earned_milestones", 0)
    data["save_counter"] = overrides.get("save_counter", 1)
    data["updated_at_unix"] = overrides.get("updated_at_unix", 1786000000)
    data["nickname"] = overrides.get("nickname", "")
    data["profile_id"] = overrides.get("profile_id", "test_profile")
    data["highest_unlocked_index"] = overrides.get("highest_unlocked_index", 0)
    data["cosmetics"] = overrides.get("cosmetics", LocalCosmetics.new().to_dictionary())
    data["achievements"] = {"granted": overrides.get("granted", [])}
    data["onboarding"] = overrides.get("onboarding", {"completed": false, "step": 0})
    data["streak"] = {
        "current_count": overrides.get("current_count", 0),
        "all_time_high": overrides.get("all_time_high", 0),
        "milestones": overrides.get("milestones", []),
    }
    data["cloud"] = LocalCloudSync.new().to_dictionary()
    for key in overrides.get("mastery", {}):
        data["mastery"][key] = overrides["mastery"][key]
    for key in overrides.get("last_practiced", {}):
        data["last_practiced"][key] = overrides["last_practiced"][key]
    return data


## A cosmetics dictionary owning the given `[category, item_id]` pairs.
func _owning(pairs: Array) -> Dictionary:
    var cosmetics := LocalCosmetics.new()
    for pair in pairs:
        cosmetics.purchase_and_equip_item(String(pair[0]), String(pair[1]), 100000)
    return cosmetics.to_dictionary()
