extends Node

const PROFILE_PATH := "user://profile.json"
const SAVE_VERSION := SaveMigration.CURRENT_VERSION
const PROFILE_ID_BYTES := 16

## The previous save, kept so a truncated or unreadable primary file is a recoverable accident
## rather than a wiped childhood of practice.
const BACKUP_SUFFIX := ".bak"
## Only ever exists during a write. A leftover one means the process died mid-save; it is
## overwritten by the next write and never read.
const TEMP_SUFFIX := ".tmp"

## Every field this build writes. Anything else found in a save is preserved untouched, so a file
## written by a newer build survives a round trip through this one instead of losing fields.
const KNOWN_FIELDS: Array[String] = [
    "version",
    "highest_unlocked_index",
    "mastery",
    "last_practiced",
    "coins",
    "experience",
    "completed_sessions",
    "earned_rounds",
    "earned_milestones",
    "cosmetics",
    "streak",
    "achievements",
    "onboarding",
    "nickname",
    "profile_id",
    "save_counter",
    "updated_at_unix",
    "cloud",
]

## How many loads have fallen through to the backup this session. Tests assert that recovery
## actually happened rather than that nothing crashed; nothing in the game reads it.
var recovered_loads := 0

## Lets a test freeze `updated_at_unix`. Unset in the game, where the system clock is correct
## enough for a value that is only ever a tie-breaker of last resort.
var clock_override := Callable()


func save_profile(profile: LearningProfile, path: String = PROFILE_PATH) -> Error:
    var progress := load_progress(path)
    var cosmetics := load_cosmetics(path)
    var streak := load_streak(path)
    var achievements := load_achievements(path)
    return save_game_state(
        profile,
        int(progress["coins"]),
        int(progress["experience"]),
        path,
        cosmetics,
        streak,
        null,
        achievements,
        int(progress["completed_sessions"]),
        null,
        {
            "earned_rounds": int(progress["earned_rounds"]),
            "earned_milestones": int(progress["earned_milestones"]),
        }
    )


func save_game_state(
    profile: LearningProfile,
    coins: int,
    experience: int,
    path: String = PROFILE_PATH,
    cosmetics: Dictionary = {},
    streak: Dictionary = {},
    nickname: Variant = null,
    achievements: Variant = null,
    completed_sessions: Variant = null,
    onboarding: Variant = null,
    ledger: Variant = null
) -> Error:
    var existing := _load_state_dictionary(path)
    var cosmetics_to_save := cosmetics
    if cosmetics_to_save.is_empty():
        cosmetics_to_save = _cosmetics_from_state(existing)
    var streak_to_save := streak
    if streak_to_save.is_empty():
        streak_to_save = _streak_from_state(existing)
    var nickname_to_save := (
        LocalNickname.sanitize(nickname) if nickname is String
        else _nickname_from_state(existing)
    )
    # An empty achievement set and a zero session count are meaningful values, so these use an
    # explicit null sentinel instead of the "empty means reload" rule above.
    var achievements_to_save: Dictionary = (
        achievements if achievements is Dictionary else _achievements_from_state(existing)
    )
    var completed_sessions_to_save := (
        maxi(0, int(completed_sessions)) if completed_sessions is int
        else _number_from_state(existing, "completed_sessions")
    )
    var onboarding_to_save: Dictionary = (
        onboarding if onboarding is Dictionary else _onboarding_from_state(existing)
    )
    var ledger_to_save: Dictionary = ledger if ledger is Dictionary else {}
    var profile_id := _profile_id_from_state(existing)
    if profile_id.is_empty():
        profile_id = Crypto.new().generate_random_bytes(PROFILE_ID_BYTES).hex_encode()

    # Unknown fields first, so nothing this build owns can be shadowed by a stale value.
    var data := _preserved_unknown_fields(existing)
    var profile_data := profile.to_dictionary()
    for key in profile_data:
        data[key] = profile_data[key]
    # `LearningProfile` stamps a version of its own, which is not the file's. Ours wins, and it is
    # set after the profile fields for exactly that reason.
    data["version"] = SAVE_VERSION
    data["coins"] = maxi(0, coins)
    data["experience"] = maxi(0, experience)
    data["completed_sessions"] = completed_sessions_to_save
    data["earned_rounds"] = (
        maxi(0, int(ledger_to_save["earned_rounds"])) if ledger_to_save.has("earned_rounds")
        else _number_from_state(existing, "earned_rounds")
    )
    data["earned_milestones"] = (
        maxi(0, int(ledger_to_save["earned_milestones"])) if ledger_to_save.has("earned_milestones")
        else _number_from_state(existing, "earned_milestones")
    )
    data["cosmetics"] = LocalCosmetics.new(cosmetics_to_save).to_dictionary()
    data["streak"] = LocalStreak.new(streak_to_save).to_dictionary()
    data["achievements"] = LocalAchievements.new(achievements_to_save).to_dictionary()
    data["onboarding"] = LocalOnboarding.new(onboarding_to_save).to_dictionary()
    data["nickname"] = nickname_to_save
    data["profile_id"] = profile_id
    data["save_counter"] = _number_from_state(existing, "save_counter") + 1
    data["updated_at_unix"] = _now()
    # Nothing updates the cloud block yet, so it is carried through validated. The field exists now
    # so that switching synchronisation on later needs no second migration over live saves.
    data["cloud"] = LocalCloudSync.new(_cloud_from_state(existing)).to_dictionary()

    var write_error := _write_atomically(path, JSON.stringify(data, "  "))
    if write_error != OK:
        return write_error
    EventBus.profile_saved.emit()
    return OK


## Writes through a temporary file so an interrupted save can never truncate the real one.
##
## `FileAccess.WRITE` truncates on open, so writing in place means a process killed mid-write
## leaves a half file that parses as nothing and loads as a brand-new profile. Instead: write the
## whole thing beside the target, move the current save to the backup name, then move the new file
## into place. Both moves replace atomically, so at no point is there a moment with no readable
## save -- a crash between them leaves the previous save under the backup name, which is exactly
## what `_load_state_dictionary` falls through to.
func _write_atomically(path: String, text: String) -> Error:
    var temp_path := path + TEMP_SUFFIX
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_error("Could not open profile for writing: %s" % temp_path)
        return FileAccess.get_open_error()
    file.store_string(text)
    var store_error := file.get_error()
    file.close()
    if store_error != OK:
        push_error("Could not write profile data: %s" % temp_path)
        _delete_if_exists(temp_path)
        return store_error

    if FileAccess.file_exists(path):
        var backup_error := DirAccess.rename_absolute(path, path + BACKUP_SUFFIX)
        if backup_error != OK:
            # Losing the safety net is not a reason to lose the save; the commit below still
            # replaces the primary atomically.
            push_warning("Could not refresh the profile backup: %s" % (path + BACKUP_SUFFIX))

    var commit_error := DirAccess.rename_absolute(temp_path, path)
    if commit_error != OK:
        push_error("Could not commit the profile save: %s" % path)
        _delete_if_exists(temp_path)
        return commit_error
    return OK


## Removes the profile, its backup, and any leftover temporary file.
##
## Tests use it so one case cannot recover another's data through the backup; the account-deletion
## path in `docs/GOOGLE_PLAY_GAMES.md` will want the same thing.
func delete_profile(path: String = PROFILE_PATH) -> void:
    _delete_if_exists(path)
    _delete_if_exists(path + BACKUP_SUFFIX)
    _delete_if_exists(path + TEMP_SUFFIX)


func load_profile(path: String = PROFILE_PATH) -> LearningProfile:
    var data := _load_state_dictionary(path)
    if data.is_empty():
        return LearningProfile.new()
    return LearningProfile.from_dictionary(data)


func load_progress(path: String = PROFILE_PATH) -> Dictionary:
    return _progress_from_state(_load_state_dictionary(path))


func load_achievements(path: String = PROFILE_PATH) -> Dictionary:
    return _achievements_from_state(_load_state_dictionary(path))


func load_onboarding(path: String = PROFILE_PATH) -> Dictionary:
    return _onboarding_from_state(_load_state_dictionary(path))


func load_cosmetics(path: String = PROFILE_PATH) -> Dictionary:
    return _cosmetics_from_state(_load_state_dictionary(path))


func load_nickname(path: String = PROFILE_PATH) -> String:
    return _nickname_from_state(_load_state_dictionary(path))


func load_profile_id(path: String = PROFILE_PATH) -> String:
    return _profile_id_from_state(_load_state_dictionary(path))


func load_streak(path: String = PROFILE_PATH) -> Dictionary:
    return _streak_from_state(_load_state_dictionary(path))


func load_cloud_sync(path: String = PROFILE_PATH) -> Dictionary:
    return LocalCloudSync.new(_cloud_from_state(_load_state_dictionary(path))).to_dictionary()


## The write counter of the save on disk. Zero when there is none.
func load_save_counter(path: String = PROFILE_PATH) -> int:
    return _number_from_state(_load_state_dictionary(path), "save_counter")


func _progress_from_state(data: Dictionary) -> Dictionary:
    return LocalProgress.new({
        "coins": data.get("coins", 0),
        "experience": data.get("experience", 0),
        "completed_sessions": data.get("completed_sessions", 0),
        "earned_rounds": data.get("earned_rounds", 0),
        "earned_milestones": data.get("earned_milestones", 0),
    }).totals()


func _achievements_from_state(data: Dictionary) -> Dictionary:
    var achievements: Variant = data.get("achievements", {})
    return LocalAchievements.new(
        achievements if achievements is Dictionary else {}
    ).to_dictionary()


func _onboarding_from_state(data: Dictionary) -> Dictionary:
    var onboarding: Variant = data.get("onboarding", {})
    return LocalOnboarding.new(onboarding if onboarding is Dictionary else {}).to_dictionary()


func _cosmetics_from_state(data: Dictionary) -> Dictionary:
    var cosmetics: Variant = data.get("cosmetics", {})
    return LocalCosmetics.new(cosmetics if cosmetics is Dictionary else {}).to_dictionary()


func _streak_from_state(data: Dictionary) -> Dictionary:
    var streak: Variant = data.get("streak", {})
    return LocalStreak.new(streak if streak is Dictionary else {}).to_dictionary()


func _cloud_from_state(data: Dictionary) -> Dictionary:
    var cloud: Variant = data.get("cloud", {})
    return cloud if cloud is Dictionary else {}


func _nickname_from_state(data: Dictionary) -> String:
    var nickname: Variant = data.get("nickname", "")
    return LocalNickname.sanitize(nickname) if nickname is String else ""


func _profile_id_from_state(data: Dictionary) -> String:
    var profile_id: Variant = data.get("profile_id", "")
    return profile_id if profile_id is String else ""


func _number_from_state(data: Dictionary, key: String) -> int:
    var raw: Variant = data.get(key, 0)
    if raw is float or raw is int:
        return maxi(0, int(raw))
    return 0


func _preserved_unknown_fields(existing: Dictionary) -> Dictionary:
    var preserved: Dictionary = {}
    for key in existing:
        if not KNOWN_FIELDS.has(String(key)):
            preserved[key] = existing[key]
    return preserved


func _now() -> int:
    if clock_override.is_valid():
        return int(clock_override.call())
    return int(Time.get_unix_time_from_system())


## The save on disk, migrated to the current schema, or the backup when the primary is unusable.
##
## A missing primary with a readable backup is the crash-between-renames case from
## `_write_atomically`, and is recovered the same way a corrupt one is.
func _load_state_dictionary(path: String) -> Dictionary:
    var data := _read_state_file(path)
    if not data.is_empty():
        return SaveMigration.migrate(data)
    var backup := _read_state_file(path + BACKUP_SUFFIX)
    if not backup.is_empty():
        recovered_loads += 1
        push_warning("Profile was unreadable; recovered the previous save from the backup")
        return SaveMigration.migrate(backup)
    return {}


func _read_state_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Could not read profile at %s" % path)
        return {}
    var text := file.get_as_text()
    file.close()
    # A JSON instance rather than `JSON.parse_string`: the static helper pushes an engine error on
    # malformed input, and a corrupt save is something this class handles, not an engine fault. It
    # would otherwise fill a child's device log -- and fail the test runner, which treats any
    # `ERROR:` line as a failed run.
    var parser := JSON.new()
    if parser.parse(text) != OK:
        push_warning("Profile data at %s is invalid: %s" % [path, parser.get_error_message()])
        return {}
    var parsed: Variant = parser.data
    if parsed is not Dictionary:
        push_warning("Profile data at %s is not an object" % path)
        return {}
    return parsed


func _delete_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
