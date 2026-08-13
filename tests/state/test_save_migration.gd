extends NumblopTestCase

## Save version 10 adds the write counter, the cloud block, and the coin ledger. Existing players
## are already carrying versions 6 to 9, so every one of those has to arrive at a correct ledger
## without the child noticing anything.

const TEST_PATH := "user://numblop_migration_test.json"


func test_a_legacy_save_gains_a_counter_and_a_cloud_block() -> void:
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = 40

    var migrated := SaveMigration.migrate(legacy)
    equal(migrated["save_counter"], 0, "An old save has no write history to count")
    equal(migrated["updated_at_unix"], 0, "No write time is known for an old save")
    check(migrated["cloud"] is Dictionary, "The cloud block exists")
    equal(migrated["cloud"]["last_synced_counter"], 0, "Nothing has ever been synchronised")
    equal(migrated["cloud"]["player_id"], "", "No Play account is attached yet")


func test_migration_never_mutates_the_dictionary_it_was_given() -> void:
    # Loading an old profile must not modify it. The migrated shape only reaches disk with the
    # next ordinary save.
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 7
    legacy["coins"] = 25
    SaveMigration.migrate(legacy)
    check(not legacy.has("earned_rounds"), "The source dictionary is untouched")
    check(not legacy.has("save_counter"), "No counter was written into the source")


func test_a_plain_legacy_save_attributes_every_coin_to_rounds() -> void:
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = 137

    var migrated := SaveMigration.migrate(legacy)
    equal(migrated["earned_rounds"], 137, "Everything unexplained is a round reward")
    equal(migrated["earned_milestones"], 0, "The split is unknowable and lands on rounds")


func test_the_backfill_accounts_for_what_was_already_spent() -> void:
    var cosmetics := LocalCosmetics.new()
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_HAT, "hat_crown", 1000)
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_GLASSES, "glasses_star", 1000)

    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = 50
    legacy["cosmetics"] = cosmetics.to_dictionary()

    var migrated := SaveMigration.migrate(legacy)
    equal(
        migrated["earned_rounds"],
        250,
        "50 left plus two 100-coin items means 250 was earned"
    )


func test_the_backfill_does_not_count_achievement_coins_as_round_earnings() -> void:
    # Achievement payouts are derived from the granted set, so counting them here as well would
    # pay a returning player twice the moment the ledger is rebuilt.
    var achievements := LocalAchievements.new()
    achievements.grant(AchievementCatalog.FIRST_STEPS_ID)

    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = 130
    legacy["achievements"] = achievements.to_dictionary()

    var migrated := SaveMigration.migrate(legacy)
    equal(migrated["earned_rounds"], 30, "The 100-coin achievement is excluded from rounds")


func test_a_migrated_save_reproduces_the_balance_it_started_with() -> void:
    # The invariant that makes the whole ledger trustworthy: rebuilding it must never change how
    # many coins the child has.
    var cosmetics := LocalCosmetics.new()
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_HAT, "hat_dino", 1000)
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_FOOTWEAR, "footwear_duck", 1000)
    var achievements := LocalAchievements.new()
    achievements.grant(AchievementCatalog.FIRST_STEPS_ID)
    achievements.grant(AchievementCatalog.streak_id(10))

    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 9
    legacy["coins"] = 275
    legacy["cosmetics"] = cosmetics.to_dictionary()
    legacy["achievements"] = achievements.to_dictionary()

    var migrated := SaveMigration.migrate(legacy)
    equal(
        CoinLedger.balance(
            int(migrated["earned_rounds"]),
            int(migrated["earned_milestones"]),
            achievements.granted,
            cosmetics
        ),
        275,
        "The rebuilt ledger implies exactly the balance that was stored"
    )


func test_a_corrupt_coin_value_cannot_produce_a_negative_ledger() -> void:
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = "not a number"

    var migrated := SaveMigration.migrate(legacy)
    equal(migrated["earned_rounds"], 0, "A junk balance rebuilds as nothing earned")


func test_migration_is_idempotent() -> void:
    # An older build round-trips a newer save and stamps its own version on the way out, so a
    # migration can meet a dictionary it has already produced.
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 8
    legacy["coins"] = 90

    var once := SaveMigration.migrate(legacy)
    once["earned_rounds"] = 90
    var twice := SaveMigration.migrate(once)
    equal(twice["earned_rounds"], 90, "A second pass does not rebuild what already exists")
    equal(twice["earned_milestones"], 0, "Existing buckets are left alone")


func test_a_save_from_a_newer_build_is_recognised() -> void:
    var future := LearningProfile.new().to_dictionary()
    future["version"] = SaveMigration.CURRENT_VERSION + 1
    check(SaveMigration.is_from_newer_build(future), "A newer schema is detected")
    check(
        not SaveMigration.is_from_newer_build(LearningProfile.new().to_dictionary()),
        "A profile-shaped dictionary with no file version is not from the future"
    )


func test_unknown_fields_written_by_a_newer_build_survive_a_save() -> void:
    # A downgrade -- or an older device round-tripping a newer cloud snapshot -- must not silently
    # delete fields it does not understand.
    _remove_test_file()
    var future := LearningProfile.new().to_dictionary()
    future["version"] = SaveMigration.CURRENT_VERSION + 1
    future["coins"] = 12
    future["a_field_from_the_future"] = {"kept": true}
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(future))
    file.close()

    equal(
        SaveManager.save_game_state(LearningProfile.new(), 12, 0, TEST_PATH),
        OK,
        "An older build still saves"
    )
    var reread := FileAccess.open(TEST_PATH, FileAccess.READ)
    var reloaded: Dictionary = JSON.parse_string(reread.get_as_text())
    reread.close()
    check(reloaded.has("a_field_from_the_future"), "The unknown field survived the round trip")
    equal(reloaded["version"], SaveManager.SAVE_VERSION, "This build stamps its own version")
    _remove_test_file()


func test_the_write_counter_rises_on_every_save() -> void:
    _remove_test_file()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_PATH)
    var first := SaveManager.load_save_counter(TEST_PATH)
    equal(first, 1, "The first save is counter 1")

    SaveManager.save_game_state(LearningProfile.new(), 1, 1, TEST_PATH)
    SaveManager.save_game_state(LearningProfile.new(), 2, 2, TEST_PATH)
    equal(SaveManager.load_save_counter(TEST_PATH), 3, "Every write moves it exactly one step")
    _remove_test_file()


func test_the_write_counter_survives_a_legacy_save_and_keeps_climbing() -> void:
    _remove_test_file()
    var legacy := LearningProfile.new().to_dictionary()
    legacy["version"] = 6
    legacy["coins"] = 5
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file.close()

    equal(SaveManager.load_save_counter(TEST_PATH), 0, "A legacy save starts at zero")
    SaveManager.save_game_state(LearningProfile.new(), 5, 0, TEST_PATH)
    equal(SaveManager.load_save_counter(TEST_PATH), 1, "The first v10 write is counter 1")
    _remove_test_file()


func test_the_recorded_write_time_uses_the_injected_clock() -> void:
    _remove_test_file()
    SaveManager.clock_override = func() -> int: return 1786000123
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_PATH)
    SaveManager.clock_override = Callable()

    var file := FileAccess.open(TEST_PATH, FileAccess.READ)
    var stored: Dictionary = JSON.parse_string(file.get_as_text())
    file.close()
    equal(stored["updated_at_unix"], 1786000123, "The write time is recorded")
    _remove_test_file()


func test_the_cloud_block_round_trips_and_rejects_junk() -> void:
    _remove_test_file()
    var seeded := LearningProfile.new().to_dictionary()
    seeded["version"] = 10
    seeded["cloud"] = {
        "last_synced_counter": 17,
        "last_synced_at_unix": 1786000000,
        "player_id": "g12345",
    }
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(seeded))
    file.close()

    var loaded := SaveManager.load_cloud_sync(TEST_PATH)
    equal(loaded["last_synced_counter"], 17, "Synced counter loads")
    equal(loaded["player_id"], "g12345", "Player id loads")

    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_PATH)
    equal(
        SaveManager.load_cloud_sync(TEST_PATH)["last_synced_counter"],
        17,
        "An ordinary save carries the cloud block through untouched"
    )
    _remove_test_file()


func test_a_junk_cloud_counter_cannot_win_every_future_merge() -> void:
    var loaded := LocalCloudSync.new({
        "last_synced_counter": "9999999999",
        "last_synced_at_unix": {},
        "player_id": 42,
    })
    equal(loaded.last_synced_counter, 0, "A non-numeric counter reads as nothing synced")
    equal(loaded.last_synced_at_unix, 0, "A non-numeric time reads as nothing synced")
    equal(loaded.player_id, "", "A non-string player id falls back to empty")


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
