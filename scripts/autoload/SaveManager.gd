extends Node

const PROFILE_PATH := "user://profile.json"


func save_profile(profile: LearningProfile, path: String = PROFILE_PATH) -> Error:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Could not open profile for writing: %s" % path)
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(profile.to_dictionary(), "  "))
    EventBus.profile_saved.emit()
    return OK


func load_profile(path: String = PROFILE_PATH) -> LearningProfile:
    if not FileAccess.file_exists(path):
        return LearningProfile.new()
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Could not read profile; starting locally with a new profile")
        return LearningProfile.new()
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is not Dictionary:
        push_warning("Profile data is invalid; starting locally with a new profile")
        return LearningProfile.new()
    return LearningProfile.from_dictionary(parsed)
