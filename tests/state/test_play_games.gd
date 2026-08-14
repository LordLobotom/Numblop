extends NumblopTestCase

## Play Games must be invisible to everyone who has not deliberately opted in -- every Windows and
## Web player, every Android player without the plugin, and every child whose guardian left the
## setting alone. That guarantee is the whole point of the wrapper, so it is tested here on a fake
## plugin rather than only on real hardware, where it would never be exercised at all.

const TEST_SETTINGS_PATH := "user://numblop_play_games_settings_test.cfg"
const TEST_CLOUD_PATH := "user://numblop_play_games_cloud_test.json"
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


class FakeSnapshotsClient:
    extends Node

    signal game_saved(is_saved: bool, save_data_name: String, save_data_description: String)
    signal game_loaded(snapshot: Variant)
    signal conflict_emitted(conflict: Variant)

    var load_calls: Array[Array] = []
    var save_calls: Array[Dictionary] = []

    func load_game(file_name: String, create_if_not_found := false) -> void:
        load_calls.append([file_name, create_if_not_found])

    func save_game(
        file_name: String,
        description: String,
        content: PackedByteArray,
        played_time_millis: int = 0,
        progress_value: int = 0
    ) -> void:
        save_calls.append({
            "file_name": file_name,
            "description": description,
            "content": content,
            "played_time_millis": played_time_millis,
            "progress_value": progress_value,
        })

    func answer_loaded(snapshot: Variant) -> void:
        game_loaded.emit(snapshot)

    func answer_saved(saved: bool = true) -> void:
        var description := ""
        if not save_calls.is_empty():
            description = String(save_calls[-1]["description"])
        game_saved.emit(saved, PlayGames.SNAPSHOT_NAME, description)


class FakePlayersClient:
    extends Node

    signal current_player_loaded(current_player: Variant)

    var load_calls := 0

    func load_current_player(_force_reload: bool) -> void:
        load_calls += 1

    func answer(player_id: String) -> void:
        current_player_loaded.emit({"player_id": player_id})


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


func test_an_available_plugin_requests_google_sign_in_on_startup() -> void:
    # Cloud save is on by default, so a fresh install must ask Google for its account without
    # requiring the player to discover Settings first. Google and Family Link remain the gate.
    var state := _install_fake_plugin(true)
    PlayGames._start()
    equal(state["client"].sign_in_calls, 1, "Startup requests Play Games sign-in")
    equal(state["client"].is_authenticated_calls, 0, "It does not stop at a passive status check")
    _remove_fake_plugin(state)


func test_a_device_switched_off_never_authenticates() -> void:
    var state := _install_fake_plugin(false)
    PlayGames._start()
    equal(state["client"].is_authenticated_calls, 0, "Switched off means no session check")
    PlayGames.sign_in()
    equal(state["client"].sign_in_calls, 0, "And no manual sign-in either")
    _remove_fake_plugin(state)


func test_explicitly_enabling_backup_requests_interactive_sign_in() -> void:
    var restore_settings: Variant = preserve_settings_file()
    var state := _install_fake_plugin(false)

    PlayGames.set_enabled(true)

    check(PlayGames.enabled(), "The explicit choice is persisted")
    equal(state["client"].sign_in_calls, 1, "Enabling backup opens Google's sign-in path")
    equal(
        state["client"].is_authenticated_calls,
        0,
        "The explicit choice is not reduced to another silent status check"
    )

    _remove_fake_plugin(state)
    restore_settings_file(restore_settings)


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
    equal(client.sign_in_calls, 1, "Startup asks exactly once")

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
    # `set_enabled` persists, and the only path it persists to is the real settings file.
    var restore_settings: Variant = preserve_settings_file()
    var state := _install_fake_plugin(true)
    PlayGames._start()
    state["client"].answer(true)
    check(PlayGames.signed_in(), "Signed in to begin with")

    PlayGames.set_enabled(false)
    check(not PlayGames.signed_in(), "Numblop stops treating the player as signed in")
    check(not PlayGames.enabled(), "And the switch is off")

    _remove_fake_plugin(state)
    restore_settings_file(restore_settings)


func test_snapshot_payload_round_trips_the_exact_profile() -> void:
    var state := LearningProfile.new().to_dictionary()
    state["version"] = SaveMigration.CURRENT_VERSION
    state["save_counter"] = 12
    state["experience"] = 34
    state["profile_id"] = "0123456789abcdef0123456789abcdef"
    PlayGames.clock_override = func() -> int: return 1786000456
    var payload := PlayGames.build_snapshot_payload(state)
    PlayGames.clock_override = Callable()
    var decoded := PlayGames.decode_snapshot_payload(
        JSON.stringify(payload).to_utf8_buffer()
    )
    equal(decoded["schema"], SaveMigration.CURRENT_VERSION, "Payload carries the schema")
    equal(decoded["save_counter"], 12, "Payload carries the ordering counter")
    equal(decoded["written_at_unix"], 1786000456, "Payload uses the injected clock")
    var decoded_profile: Dictionary = decoded["profile"]
    equal(
        LearningProfile.from_dictionary(decoded_profile).to_dictionary(),
        LearningProfile.from_dictionary(state).to_dictionary(),
        "The complete learning profile survives JSON"
    )
    equal(decoded_profile["profile_id"], state["profile_id"], "Device identity survives JSON")
    equal(decoded_profile["experience"], state["experience"], "Progress survives JSON")


func test_sign_in_loads_merges_uploads_and_verifies_before_acknowledging() -> void:
    _remove_cloud_profile()
    var profile := LearningProfile.new()
    profile.set_mastery(2, 3, 25)
    SaveManager.save_game_state(profile, 7, 7, TEST_CLOUD_PATH)

    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    PlayGames._on_user_authenticated(true)
    equal(state["players"].load_calls, 1, "A signed-in player identity is loaded")
    state["players"].answer("player-one")
    equal(state["snapshots"].load_calls.size(), 1, "Remote save is checked first")

    var counter_before_upload := SaveManager.load_save_counter(TEST_CLOUD_PATH)
    state["snapshots"].answer_loaded(null)
    equal(state["snapshots"].save_calls.size(), 1, "Local progress uploads into an empty cloud")
    equal(
        SaveManager.load_save_counter(TEST_CLOUD_PATH),
        counter_before_upload,
        "An empty cloud does not cause a pointless preliminary local rewrite"
    )
    var sent: Dictionary = state["snapshots"].save_calls[0]
    var sent_payload := PlayGames.decode_snapshot_payload(sent["content"])
    equal(sent_payload["profile"]["experience"], 7, "The actual local progress was sent")

    state["snapshots"].answer_saved(true)
    equal(state["snapshots"].load_calls.size(), 2, "A dispatched commit is read back")
    state["snapshots"].answer_loaded({"content": sent["content"]})
    var cloud := SaveManager.load_cloud_sync(TEST_CLOUD_PATH)
    equal(cloud["player_id"], "player-one", "The confirmed account binding is stored")
    equal(
        cloud["last_synced_counter"],
        SaveManager.load_save_counter(TEST_CLOUD_PATH),
        "Only an exact read-back is acknowledged"
    )

    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_answer_saves_wait_until_the_round_has_ended_before_syncing() -> void:
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass

    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    state["snapshots"].answer_loaded(null)
    var first_upload: Dictionary = state["snapshots"].save_calls[0]
    state["snapshots"].answer_saved(true)
    state["snapshots"].answer_loaded({"content": first_upload["content"]})
    var loads_before_round: int = state["snapshots"].load_calls.size()

    EventBus.session_started.emit(10)
    var changed := SaveManager.load_profile(TEST_CLOUD_PATH)
    changed.set_mastery(2, 2, 15)
    SaveManager.save_game_state(changed, 0, 0, TEST_CLOUD_PATH)
    PlayGames._begin_sync_if_needed()
    equal(
        state["snapshots"].load_calls.size(),
        loads_before_round,
        "A per-answer save cannot start cloud work during practice"
    )

    EventBus.session_ended.emit()
    PlayGames._sync_timer.stop()
    PlayGames._begin_sync_if_needed()
    equal(
        state["snapshots"].load_calls.size(),
        loads_before_round + 1,
        "The deferred save starts syncing once the round is settled"
    )

    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_a_snapshot_that_returns_during_practice_cannot_interrupt_the_round() -> void:
    _remove_cloud_profile()
    var local_profile := LearningProfile.new()
    local_profile.set_mastery(2, 3, 10)
    SaveManager.save_game_state(local_profile, 0, 0, TEST_CLOUD_PATH)
    var remote := SaveManager.load_state(TEST_CLOUD_PATH)
    var remote_profile := LearningProfile.from_dictionary(remote)
    remote_profile.set_mastery(2, 3, 80)
    remote.merge(remote_profile.to_dictionary(), true)
    remote["profile_id"] = "remote-device"
    remote["save_counter"] = int(remote["save_counter"]) + 5
    var remote_content := JSON.stringify(
        PlayGames.build_snapshot_payload(remote)
    ).to_utf8_buffer()

    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    var reloads: Array[int] = []
    PlayGames.reload_profile_callable = func() -> void: reloads.append(1)
    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    equal(state["snapshots"].load_calls.size(), 1, "The startup load is in flight")

    EventBus.session_started.emit(10)
    state["snapshots"].answer_loaded({"content": remote_content})
    equal(reloads.size(), 0, "An in-flight response cannot reload AppState during practice")
    equal(
        SaveManager.load_profile(TEST_CLOUD_PATH).get_mastery(2, 3),
        10,
        "The remote merge is deferred before it touches the durable local profile"
    )
    equal(state["snapshots"].save_calls.size(), 0, "Nothing stale is uploaded")

    EventBus.session_ended.emit()
    PlayGames._sync_timer.stop()
    PlayGames._begin_sync_if_needed()
    equal(state["snapshots"].load_calls.size(), 2, "The remote comparison is retried afterwards")
    state["snapshots"].answer_loaded({"content": remote_content})
    equal(reloads.size(), 1, "The safe retry applies the merged profile")
    equal(
        SaveManager.load_profile(TEST_CLOUD_PATH).get_mastery(2, 3),
        80,
        "The deferred remote progress is preserved"
    )

    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_an_upload_dispatched_before_practice_is_not_verified_during_the_round() -> void:
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    state["snapshots"].answer_loaded(null)
    equal(state["snapshots"].save_calls.size(), 1, "The upload was dispatched from home")

    EventBus.session_started.emit(10)
    state["snapshots"].answer_saved(true)
    equal(
        state["snapshots"].load_calls.size(),
        1,
        "Its verification read-back cannot start during practice"
    )

    EventBus.session_ended.emit()
    PlayGames._sync_timer.stop()
    PlayGames._begin_sync_if_needed()
    equal(
        state["snapshots"].load_calls.size(),
        2,
        "A fresh comparison retries after the round instead"
    )

    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_three_mismatched_upload_readbacks_block_further_retries() -> void:
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 4, 4, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    var reported: Array[StringName] = []
    var listener := func(value: StringName) -> void: reported.append(value)
    PlayGames.cloud_sync_state_changed.connect(listener)

    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    for attempt in PlayGames.MAX_VERIFICATION_FAILURES:
        state["snapshots"].answer_loaded(null)
        state["snapshots"].answer_saved(true)
        state["snapshots"].answer_loaded({"content": "not the upload".to_utf8_buffer()})
        if attempt < PlayGames.MAX_VERIFICATION_FAILURES - 1:
            PlayGames.sync_now(true)

    equal(
        state["snapshots"].save_calls.size(),
        PlayGames.MAX_VERIFICATION_FAILURES,
        "A persistent mismatch gets only the bounded number of uploads"
    )
    equal(
        reported.count(&"verification_retry_pending"),
        PlayGames.MAX_VERIFICATION_FAILURES - 1,
        "Each recoverable mismatch reports a pending retry"
    )
    check(reported.has(&"verification_failed"), "The final mismatch reports why sync stopped")
    equal(PlayGames.sync_state(), &"blocked", "The session stops attempting cloud writes")
    check(PlayGames.cloud_needs_attention(), "Settings can report the blocked state")
    var loads_before: int = state["snapshots"].load_calls.size()
    PlayGames.sync_now(true)
    equal(
        state["snapshots"].load_calls.size(),
        loads_before,
        "A blocked session ignores later sync requests"
    )

    PlayGames.cloud_sync_state_changed.disconnect(listener)
    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_a_newer_cloud_schema_is_never_loaded_or_overwritten() -> void:
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    var future := {
        "schema": SaveMigration.CURRENT_VERSION + 1,
        "profile": SaveManager.load_state(TEST_CLOUD_PATH),
    }
    state["snapshots"].answer_loaded({"content": JSON.stringify(future).to_utf8_buffer()})
    equal(state["snapshots"].save_calls.size(), 0, "A future schema is never overwritten")
    equal(PlayGames.sync_state(), &"blocked", "Upload is blocked for the session")
    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_switching_off_ignores_a_snapshot_response_that_was_already_in_flight() -> void:
    var restore_settings: Variant = preserve_settings_file()
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 0, 0, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    equal(state["snapshots"].load_calls.size(), 1, "A load is outstanding")

    PlayGames.set_enabled(false)
    state["snapshots"].answer_loaded(null)
    equal(state["snapshots"].save_calls.size(), 0, "The late response cannot restart cloud access")
    check(not PlayGames.signed_in(), "The wrapper remains signed out")

    _remove_fake_plugin(state)
    _remove_cloud_profile()
    restore_settings_file(restore_settings)


func test_an_unresolvable_plugin_conflict_is_merged_locally_and_never_overwritten() -> void:
    _remove_cloud_profile()
    var local_profile := LearningProfile.new()
    local_profile.set_mastery(2, 4, 20)
    SaveManager.save_game_state(local_profile, 0, 0, TEST_CLOUD_PATH)
    var local := SaveManager.load_state(TEST_CLOUD_PATH)

    var first := local.duplicate(true)
    var first_profile := LearningProfile.from_dictionary(first)
    first_profile.set_mastery(2, 4, 65)
    first.merge(first_profile.to_dictionary(), true)
    first["profile_id"] = "remote-a"
    first["save_counter"] = 8
    var second := local.duplicate(true)
    var second_profile := LearningProfile.from_dictionary(second)
    second_profile.set_mastery(2, 5, 75)
    second.merge(second_profile.to_dictionary(), true)
    second["profile_id"] = "remote-b"
    second["save_counter"] = 9

    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass
    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    PlayGames._on_snapshot_conflict({
        "conflicting_snapshot": {
            "content": JSON.stringify(PlayGames.build_snapshot_payload(first)).to_utf8_buffer(),
        },
        "server_snapshot": {
            "content": JSON.stringify(PlayGames.build_snapshot_payload(second)).to_utf8_buffer(),
        },
    })

    var merged := SaveManager.load_profile(TEST_CLOUD_PATH)
    equal(merged.get_mastery(2, 4), 65, "First candidate survives locally")
    equal(merged.get_mastery(2, 5), 75, "Second candidate survives locally")
    equal(state["snapshots"].save_calls.size(), 0, "Unresolvable conflict is not overwritten")
    check(
        FileAccess.file_exists(TEST_CLOUD_PATH + SaveManager.PREMERGE_SUFFIX),
        "The pre-merge parent remains recoverable"
    )
    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_a_restore_that_could_replace_this_device_is_announced_on_the_bus() -> void:
    # This is what lets a scene wait for a restore without ever naming Play Games, and it is why a
    # reinstalled child is not walked through the tutorial the cloud already finished for them.
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 3, 3, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass

    var announced: Array = []
    var listener := func(pending: bool) -> void: announced.append(pending)
    EventBus.external_restore_pending.connect(listener)

    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    check(PlayGames.restore_pending(), "A started comparison could still bring a remote save")
    equal(announced.size(), 1, "The wait is announced once, not once per check")
    equal(announced[0], true, "The bus carries the raised flag")

    state["snapshots"].answer_loaded(null)
    check(
        not PlayGames.restore_pending(),
        "An empty cloud cannot replace anything, so nothing waits for the upload to finish"
    )
    equal(announced.size(), 2, "The end of the wait is announced too")
    equal(announced[1], false, "The bus carries the lowered flag")

    EventBus.external_restore_pending.disconnect(listener)
    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_a_comparison_that_never_answers_still_ends_the_wait() -> void:
    # Nothing in the game may wait on the network forever. The sync timeout is the guarantee, so a
    # silent server can never leave a screen holding back what it wanted to show.
    _remove_cloud_profile()
    SaveManager.save_game_state(LearningProfile.new(), 1, 1, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass

    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    check(PlayGames.restore_pending(), "The comparison is outstanding")

    PlayGames._on_sync_timeout()
    check(not PlayGames.restore_pending(), "A timed-out comparison releases the wait")

    _remove_fake_plugin(state)
    _remove_cloud_profile()


func test_switching_cloud_save_off_releases_a_pending_restore() -> void:
    # `set_enabled` persists, and the only path it persists to is the real settings file.
    _remove_cloud_profile()
    var restore_settings: Variant = preserve_settings_file()
    SaveManager.save_game_state(LearningProfile.new(), 1, 1, TEST_CLOUD_PATH)
    var state := _install_fake_plugin(true, true)
    PlayGames.profile_path = TEST_CLOUD_PATH
    PlayGames.reload_profile_callable = func() -> void: pass

    PlayGames._on_user_authenticated(true)
    state["players"].answer("player-one")
    check(PlayGames.restore_pending(), "The comparison is outstanding")

    PlayGames.set_enabled(false)
    check(not PlayGames.restore_pending(), "Turning backup off cannot strand a waiting screen")

    _remove_fake_plugin(state)
    restore_settings_file(restore_settings)
    _remove_cloud_profile()


## Installs the plugin doubles and sets the switch, returning what the caller must clean up.
func _install_fake_plugin(cloud_save_on: bool, with_cloud := false) -> Dictionary:
    var previous := SettingsManager.play_games_enabled
    SettingsManager.play_games_enabled = cloud_save_on
    var plugin := FakePlugin.new()
    var client := FakeSignInClient.new()
    PlayGames.add_child(client)
    var snapshots: Node = null
    var players: Node = null
    if with_cloud:
        snapshots = FakeSnapshotsClient.new()
        players = FakePlayersClient.new()
        PlayGames.add_child(snapshots)
        PlayGames.add_child(players)
    PlayGames._set_plugin_for_test(plugin, client, snapshots, players)
    return {
        "plugin": plugin,
        "client": client,
        "snapshots": snapshots,
        "players": players,
        "previous": previous,
    }


func _remove_fake_plugin(state: Dictionary) -> void:
    PlayGames._set_plugin_for_test(null)
    var client: Node = state["client"]
    PlayGames.remove_child(client)
    client.free()
    for key in ["snapshots", "players"]:
        var cloud_client: Node = state.get(key)
        if cloud_client != null:
            PlayGames.remove_child(cloud_client)
            cloud_client.free()
    state["plugin"].free()
    SettingsManager.play_games_enabled = bool(state["previous"])
    PlayGames.reload_profile_callable = Callable(AppState, "reload_profile_from_disk")


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


func _remove_cloud_profile() -> void:
    SaveManager.delete_profile(TEST_CLOUD_PATH)
