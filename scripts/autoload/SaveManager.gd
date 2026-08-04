extends Node

const PROFILE_PATH := "user://profile.json"
const SAVE_VERSION := 9
const PROFILE_ID_BYTES := 16


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
        int(progress["completed_sessions"])
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
    onboarding: Variant = null
) -> Error:
    var cosmetics_to_save := cosmetics
    if cosmetics_to_save.is_empty():
        cosmetics_to_save = load_cosmetics(path)
    var streak_to_save := streak
    if streak_to_save.is_empty():
        streak_to_save = load_streak(path)
    var nickname_to_save := (
        LocalNickname.sanitize(nickname) if nickname is String else load_nickname(path)
    )
    # An empty achievement set and a zero session count are meaningful values, so these two use
    # an explicit null sentinel instead of the "empty means reload" rule above.
    var achievements_to_save: Dictionary = (
        achievements if achievements is Dictionary else load_achievements(path)
    )
    var completed_sessions_to_save := (
        maxi(0, int(completed_sessions)) if completed_sessions is int
        else int(load_progress(path)["completed_sessions"])
    )
    var onboarding_to_save: Dictionary = (
        onboarding if onboarding is Dictionary else load_onboarding(path)
    )
    var profile_id := load_profile_id(path)
    if profile_id.is_empty():
        profile_id = Crypto.new().generate_random_bytes(PROFILE_ID_BYTES).hex_encode()
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Could not open profile for writing: %s" % path)
        return FileAccess.get_open_error()
    var data := profile.to_dictionary()
    data["version"] = SAVE_VERSION
    data["coins"] = maxi(0, coins)
    data["experience"] = maxi(0, experience)
    data["completed_sessions"] = completed_sessions_to_save
    data["cosmetics"] = LocalCosmetics.new(cosmetics_to_save).to_dictionary()
    data["streak"] = LocalStreak.new(streak_to_save).to_dictionary()
    data["achievements"] = LocalAchievements.new(achievements_to_save).to_dictionary()
    data["onboarding"] = LocalOnboarding.new(onboarding_to_save).to_dictionary()
    data["nickname"] = nickname_to_save
    data["profile_id"] = profile_id
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
    return LocalProgress.new({
        "coins": data.get("coins", 0),
        "experience": data.get("experience", 0),
        "completed_sessions": data.get("completed_sessions", 0),
    }).totals()


func load_achievements(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    var achievements: Variant = data.get("achievements", {})
    return LocalAchievements.new(
        achievements if achievements is Dictionary else {}
    ).to_dictionary()


func load_onboarding(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    var onboarding: Variant = data.get("onboarding", {})
    return LocalOnboarding.new(
        onboarding if onboarding is Dictionary else {}
    ).to_dictionary()


func load_cosmetics(path: String = PROFILE_PATH) -> Dictionary:
    var data := _load_state_dictionary(path)
    var cosmetics: Variant = data.get("cosmetics", {})
    return LocalCosmetics.new(cosmetics if cosmetics is Dictionary else {}).to_dictionary()


func load_nickname(path: String = PROFILE_PATH) -> String:
    var data := _load_state_dictionary(path)
    var nickname: Variant = data.get("nickname", "")
    return LocalNickname.sanitize(nickname) if nickname is String else ""


func load_profile_id(path: String = PROFILE_PATH) -> String:
    var data := _load_state_dictionary(path)
    var profile_id: Variant = data.get("profile_id", "")
    return profile_id if profile_id is String else ""


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
