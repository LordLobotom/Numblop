class_name NumblopTestCase
extends RefCounted

var failures: Array[String] = []


func check(condition: bool, message: String = "Check failed") -> void:
    if not condition:
        failures.append(message)


func equal(actual: Variant, expected: Variant, message: String = "") -> void:
    if actual != expected:
        failures.append("%s expected=%s actual=%s" % [message, expected, actual])


func contains(values: Variant, expected: Variant, message: String = "") -> void:
    if not values.has(expected):
        failures.append("%s missing=%s" % [message, expected])


## Snapshot of the real settings file, to be handed back to `restore_settings_file`.
##
## `SettingsManager.SETTINGS_PATH` is a constant, so anything that saves settings writes the file
## belonging to whoever is sitting at this machine -- and several paths save without looking like
## they do: the settings screen's debounce timer, and any call that flips a preference. A test that
## touches settings therefore brackets itself with these two, and the suite leaves the machine
## configured exactly as it found it.
func preserve_settings_file() -> Variant:
    var path := _settings_path()
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var contents := file.get_as_text()
    file.close()
    return contents


func restore_settings_file(contents: Variant) -> void:
    var path := _settings_path()
    if contents == null:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    else:
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file != null:
            file.store_string(String(contents))
            file.close()
    # The autoload cached whatever the test set; put it back in step with the file on disk.
    var manager := _settings_manager()
    if manager != null:
        manager.load_settings()


## The settings autoload, looked up by node path rather than by its global name.
##
## This file compiles as a dependency of `run_tests.gd` before the autoloads are registered, so
## naming `SettingsManager` here is a compile error even though every test script may do it freely.
func _settings_manager() -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    return tree.root.get_node_or_null("/root/SettingsManager")


func _settings_path() -> String:
    var manager := _settings_manager()
    if manager == null:
        return "user://settings.cfg"
    return String(manager.SETTINGS_PATH)
