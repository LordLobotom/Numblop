extends NumblopTestCase

## Play Games must be invisible to everyone who has not deliberately opted in -- every Windows and
## Web player, every Android player without the plugin, and every child whose guardian left the
## setting alone. That guarantee is the whole point of the wrapper, so it is tested here on a fake
## plugin rather than only on real hardware, where it would never be exercised at all.

const TEST_SETTINGS_PATH := "user://numblop_play_games_settings_test.cfg"
## The autoload name resolves to the live instance, so the script itself is loaded to get a
## throwaway copy that cannot disturb the running game's settings.
const SettingsManagerScript: GDScript = preload("res://scripts/autoload/SettingsManager.gd")


## Stands in for the plugin's own autoload.
class FakePlugin:
    extends Node

    var initialize_calls := 0

    func initialize() -> int:
        initialize_calls += 1
        return 0


## Stands in for `PlayGamesSignInClient`, matching its signal and methods.
class FakeSignInClient:
    extends Node

    signal user_authenticated(is_authenticated: bool)

    var is_authenticated_calls := 0
    var sign_in_calls := 0

    func is_authenticated() -> void:
        is_authenticated_calls += 1

    func sign_in() -> void:
        sign_in_calls += 1

    ## Plays back what Google would have answered.
    func answer(authenticated: bool) -> void:
        user_authenticated.emit(authenticated)


func test_cloud_save_is_on_for_a_device_that_has_never_been_configured() -> void:
    # Both the fresh-install case and an existing settings file written before the key existed:
    # the missing value reads as on, so nobody has to find a switch to get their progress backed up.
    var settings: Node = SettingsManagerScript.new()
    settings.load_settings("user://a_settings_file_that_does_not_exist.cfg")
    check(settings.play_games_enabled, "Cloud save defaults to on")
    settings.free()


func test_turning_cloud_save_off_survives_a_restart() -> void:
    _remove_settings_file()
    var settings: Node = SettingsManagerScript.new()
    settings.load_settings(TEST_SETTINGS_PATH)
    equal(settings.set_play_games_enabled(false, TEST_SETTINGS_PATH), OK, "Opt-out saves")

    var reloaded: Node = SettingsManagerScript.new()
    reloaded.load_settings(TEST_SETTINGS_PATH)
    check(not reloaded.play_games_enabled, "A deliberate opt-out is remembered")

    # It belongs to the device, not the child's progress, so resetting a profile cannot change it
    # behind anyone's back.
    check(
        not SaveManager.load_progress("user://a_profile_that_does_not_exist.json").has(
            "play_games_enabled"
        ),
        "The cloud-save switch is not part of the progress file"
    )
    settings.free()
    reloaded.free()
    _remove_settings_file()


func test_without_a_plugin_every_call_is_a_no_op() -> void:
    # Windows, Web, the editor, the test runner, and any Android build where the plugin's Android
    # side did not come up.
    check(not PlayGames.available(), "No plugin is resolved off Android")
    check(not PlayGames.signed_in(), "And nobody is signed in")
    # Neither of these may throw, block, or touch the network.
    PlayGames.sign_in()
    PlayGames._authenticate()
    check(not PlayGames.signed_in(), "Still signed out afterwards")


func test_a_plugin_without_a_sign_in_client_counts_as_unavailable() -> void:
    # Failing safe matters more than failing loudly: a half-wired plugin would leave the game
    # guessing about a child's account.
    var fake := FakePlugin.new()
    PlayGames._set_plugin_for_test(fake, null)
    check(not PlayGames.available(), "A plugin with no sign-in client is ignored")
    PlayGames.sign_in()
    PlayGames._set_plugin_for_test(null)
    fake.free()


func test_an_available_plugin_authenticates_without_being_asked() -> void:
    # Cloud save is on by default, so a child who never touches Settings still gets their progress
    # backed up. Google and Family Link decide whether the account may actually sign in.
    var state := _install_fake_plugin(true)
    PlayGames._start()
    equal(state["client"].is_authenticated_calls, 1, "Startup checks the existing session")
    equal(state["client"].sign_in_calls, 0, "Without forcing an interactive sign-in prompt")
    _remove_fake_plugin(state)


func test_a_device_switched_off_never_authenticates() -> void:
    var state := _install_fake_plugin(false)
    PlayGames._start()
    equal(state["client"].is_authenticated_calls, 0, "Switched off means no session check")
    PlayGames.sign_in()
    equal(state["client"].sign_in_calls, 0, "And no manual sign-in either")
    _remove_fake_plugin(state)


func test_the_signed_in_state_comes_from_google_not_from_asking() -> void:
    # A sign-in call that returns is not a sign-in that succeeded. Offline, a restricted family
    # account, or a declined prompt all come back the same way.
    var state := _install_fake_plugin(true)
    var client: FakeSignInClient = state["client"]
    var reported: Array[bool] = []
    var listener := func(value: bool) -> void: reported.append(value)
    PlayGames.sign_in_state_changed.connect(listener)

    PlayGames._start()
    check(not PlayGames.signed_in(), "Asking is not being signed in")

    client.answer(true)
    check(PlayGames.signed_in(), "Google's answer decides")
    equal(reported.size(), 1, "The change is announced exactly once")

    client.answer(true)
    equal(reported.size(), 1, "An unchanged state is not re-announced")

    PlayGames.sign_in_state_changed.disconnect(listener)
    _remove_fake_plugin(state)


func test_a_failed_sign_in_leaves_the_game_completely_playable() -> void:
    # The whole promise: no account, no network, no Play Services -- none of it may cost a child
    # anything. Answering false is what offline and a restricted account both look like.
    var state := _install_fake_plugin(true)
    PlayGames._start()
    state["client"].answer(false)

    check(not PlayGames.signed_in(), "Not signed in")
    var profile := SaveManager.load_profile("user://a_profile_that_does_not_exist.json")
    equal(profile.current_table(), 2, "A round can still be generated")
    equal(
        SessionGenerator.generate(profile, 99).size(),
        LearningRules.SESSION_LENGTH,
        "Practice is unaffected by a failed sign-in"
    )
    _remove_fake_plugin(state)


func test_switching_cloud_save_off_ends_the_session_for_the_game() -> void:
    var state := _install_fake_plugin(true)
    PlayGames._start()
    state["client"].answer(true)
    check(PlayGames.signed_in(), "Signed in to begin with")

    PlayGames.set_enabled(false)
    check(not PlayGames.signed_in(), "Numblop stops treating the player as signed in")
    check(not PlayGames.enabled(), "And the switch is off")

    _remove_fake_plugin(state)
    SettingsManager.load_settings()


## Installs the plugin doubles and sets the switch, returning what the caller must clean up.
func _install_fake_plugin(cloud_save_on: bool) -> Dictionary:
    var previous := SettingsManager.play_games_enabled
    SettingsManager.play_games_enabled = cloud_save_on
    var plugin := FakePlugin.new()
    var client := FakeSignInClient.new()
    PlayGames.add_child(client)
    client.user_authenticated.connect(PlayGames._on_user_authenticated)
    PlayGames._set_plugin_for_test(plugin, client)
    return {"plugin": plugin, "client": client, "previous": previous}


func _remove_fake_plugin(state: Dictionary) -> void:
    PlayGames._set_plugin_for_test(null)
    var client: Node = state["client"]
    PlayGames.remove_child(client)
    client.free()
    state["plugin"].free()
    SettingsManager.play_games_enabled = bool(state["previous"])


## The one screen allowed to know about Play Games: it is the switch that turns it on.
##
## Everything else must stay ignorant, so deleting the autoload would cost the game one settings row
## and nothing else. The learning core and the app services have no exception at all.
const ALLOWED_TO_REFERENCE: Array[String] = [
    "res://scripts/ui/SettingsScreen.gd",
    "res://scenes/screens/SettingsScreen.tscn",
]


func test_no_gameplay_system_depends_on_this_autoload() -> void:
    for directory in ["res://scripts/core", "res://scripts/app", "res://scripts/ui", "res://scenes"]:
        _check_directory_never_mentions_play_games(directory)


func test_the_learning_core_and_app_services_have_no_exception() -> void:
    # Stated separately so a future entry in ALLOWED_TO_REFERENCE cannot quietly weaken the rule
    # that actually protects the game's determinism.
    for allowed in ALLOWED_TO_REFERENCE:
        check(
            not allowed.begins_with("res://scripts/core")
                and not allowed.begins_with("res://scripts/app"),
            "%s may never be exempt from the Play Games isolation rule" % allowed
        )


func _check_directory_never_mentions_play_games(directory_path: String) -> void:
    var directory := DirAccess.open(directory_path)
    if directory == null:
        return
    directory.list_dir_begin()
    var entry := directory.get_next()
    while entry != "":
        var full_path := "%s/%s" % [directory_path, entry]
        if directory.current_is_dir():
            _check_directory_never_mentions_play_games(full_path)
        elif (entry.ends_with(".gd") or entry.ends_with(".tscn")) \
                and not ALLOWED_TO_REFERENCE.has(full_path):
            var file := FileAccess.open(full_path, FileAccess.READ)
            if file != null:
                var text := file.get_as_text()
                file.close()
                check(
                    not text.contains("PlayGames"),
                    "%s must not depend on the Play Games autoload" % full_path
                )
        entry = directory.get_next()
    directory.list_dir_end()


func _remove_settings_file() -> void:
    if FileAccess.file_exists(TEST_SETTINGS_PATH):
        DirAccess.remove_absolute(TEST_SETTINGS_PATH)
