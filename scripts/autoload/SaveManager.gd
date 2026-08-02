extends Node

const PROFILE_PATH := "user://profile.json"
const SAVE_VERSION := 5


func save_profile(profile: LearningProfile, path: String = PROFILE_PATH) -> Error:
    var progress := load_progress(path)
    var cosmetics := load_cosmetics(path)
    var streak := load_streak(path)
    return save_game_state(
        profile,
        int(progress["coins"]),
        int(progress["experience"]),
        path,
        cosmetics,
        streak
    )


func save_game_state(
    profile: LearningProfile,
    coins: int,
    experience: int,
    path: String = PROFILE_PATH,
    cosmetics: Dictionary = {},
    streak: Dictionary = {}
) -> Error:
    var cosmetics_to_save := cosmetics
    if cosmetics_to_save.is_empty():
        cosmetics_to_save = load_cosmetics(path)
    var streak_to_save := streak
    if streak_to_save.is_empty():
        streak_to_save = load_streak(path)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Could not open profile for writing: %s" % path)
        return FileAccess.get_open_error()
    var data := profile.to_dictionary()
    data["version"] = SAVE_VERSION
    data["coins"] = maxi(0, coins)
    data["experience"] = maxi(0, experience)
    data["cosmetics"] = LocalCosmetics.new(cosmetics_to_save).to_dictionary()
    data["streak"] = LocalStreak.new(streak_to_save).to_dictionary()
    file.store_string(JSON.stringify(data, "  "))
    EventBus.profile_saved.emit()
    return OK


func load_profile(path: String = PROFILE_PATH) -> LearningProfile:
    var data := _load_state_dictionary(path)
    if data.is_empty():
        return LearningProfile.new()
    return LearningProfile.from_dictionary(data)


func load_progress(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    return {
        "coins": maxi(0, int(data.get("coins", 0))),
        "experience": maxi(0, int(data.get("experience", 0))),
    }


func load_cosmetics(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    var cosmetics: Variant = data.get("cosmetics", {})
    return LocalCosmetics.new(cosmetics if cosmetics is Dictionary else {}).to_dictionary()


func load_streak(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    var streak: Variant = data.get("streak", {})
    return LocalStreak.new(streak if streak is Dictionary else {}).to_dictionary()


func _load_state_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Could not read profile; starting locally with new state")
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is not Dictionary:
        push_warning("Profile data is invalid; starting locally with new state")
        return {}
    return parsed
