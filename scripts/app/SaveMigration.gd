class_name SaveMigration
extends RefCounted

## Brings a loaded save dictionary up to the current schema, in memory.
##
## Field-tolerant loading already handles an *added* field for free: every `Local*` model
## substitutes its own default for whatever it does not find. Migration exists for the other kind
## of change -- a field whose value has to be computed from other fields, which no default can
## stand in for. The coin ledger is the first of those and the reason this class exists.
##
## Nothing here writes to disk. Booting an old profile must never modify it; the migrated shape
## lands on disk with the next ordinary save, exactly like the pre-tutorial adoption in `AppState`.
##
## Every step is guarded by the fields it produces rather than by the version alone, so re-running
## a migration is a no-op. That matters because an older build round-trips a newer save (see
## `SaveManager` unknown-field preservation) and stamps its own version on the way out.

const CURRENT_VERSION := 11

## The version that introduced the coin ledger, the monotonic write counter, and the cloud block.
const LEDGER_VERSION := 10
const FINAL_TABLE_COMPLETION_VERSION := 11


static func loaded_version(data: Dictionary) -> int:
    var raw: Variant = data.get("version", 0)
    if raw is float or raw is int:
        return maxi(0, int(raw))
    return 0


## True when the save was written by a build newer than this one.
##
## The local game keeps playing regardless -- refusing to load would look like data loss to a child.
## It matters for a cloud snapshot, where overwriting a newer schema really would destroy fields
## this build cannot represent.
static func is_from_newer_build(data: Dictionary) -> bool:
    return loaded_version(data) > CURRENT_VERSION


static func migrate(data: Dictionary) -> Dictionary:
    if data.is_empty():
        return data
    var migrated := data.duplicate(true)
    if loaded_version(migrated) <= LEDGER_VERSION:
        _migrate_to_10(migrated)
    if loaded_version(migrated) <= FINAL_TABLE_COMPLETION_VERSION:
        _migrate_to_11(migrated)
    return migrated


## Save 10 -- lifetime coin buckets, a write counter, and the cloud block.
##
## Only the ledger needs real work. The counter starts at zero because an older save has no history
## of writes to count, and the cloud block starts empty because nothing has ever been synchronised.
static func _migrate_to_10(data: Dictionary) -> void:
    if not data.has("earned_rounds"):
        # Reuse the validating loaders rather than reading the raw arrays: an unknown cosmetic id
        # or an achievement that no longer exists must not inflate the reconstructed earnings.
        var achievements_data: Variant = data.get("achievements", {})
        var granted := LocalAchievements.new(
            achievements_data if achievements_data is Dictionary else {}
        ).granted
        var cosmetics_data: Variant = data.get("cosmetics", {})
        var cosmetics := LocalCosmetics.new(
            cosmetics_data if cosmetics_data is Dictionary else {}
        )
        data["earned_rounds"] = CoinLedger.backfill_earned_rounds(
            _loaded_number(data, "coins"),
            granted,
            cosmetics
        )
    if not data.has("earned_milestones"):
        data["earned_milestones"] = 0
    if not data.has("save_counter"):
        data["save_counter"] = 0
    if not data.has("updated_at_unix"):
        data["updated_at_unix"] = 0
    if not data.has("cloud"):
        data["cloud"] = LocalCloudSync.new().to_dictionary()


## Save 11 -- a permanent completion bit for the final table. Earlier tables already preserve
## completion through highest_unlocked_index; 9x has no next index, so legacy saves derive the bit
## once from the same nine-of-ten gate and then keep it forever.
static func _migrate_to_11(data: Dictionary) -> void:
    if not data.has("final_table_completed"):
        data["final_table_completed"] = LearningProfile.from_dictionary(data).final_table_completed


static func _loaded_number(data: Dictionary, key: String) -> int:
    var raw: Variant = data.get(key, 0)
    if raw is float or raw is int:
        return maxi(0, int(raw))
    return 0
