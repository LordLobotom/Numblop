extends Node

## The only place in Numblop that knows Play Games Services exists.
##
## Authentication and Saved Games are best-effort and asynchronous. Every learning rule and every
## save happens locally first; no gameplay path waits for this autoload. Removing it leaves a fully
## playable local game.

signal availability_changed(available: bool)
signal sign_in_state_changed(signed_in: bool)
signal cloud_sync_state_changed(state: StringName)

const PLUGIN_AUTOLOAD_PATH := "/root/GodotPlayGameServices"
const SIGN_IN_CLIENT_SCRIPT := "res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd"
const SNAPSHOTS_CLIENT_SCRIPT := "res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd"
const PLAYERS_CLIENT_SCRIPT := "res://addons/GodotPlayGameServices/scripts/players/players_client.gd"
const ACHIEVEMENTS_CLIENT_SCRIPT := "res://addons/GodotPlayGameServices/scripts/achievements/achievements_client.gd"
const SNAPSHOT_NAME := "numblop_profile_v1"
const SYNC_DEBOUNCE_SECONDS := 2.0
const SYNC_TIMEOUT_SECONDS := 15.0
const MAX_VERIFICATION_FAILURES := 3

var _plugin: Node = null
var _sign_in_client: Node = null
var _snapshots_client: Node = null
var _players_client: Node = null
var _achievements_client: Node = null
## What this launch has already told Play, so an unchanged achievement is not resent on every
## round. Play is idempotent about both calls; this only keeps the traffic honest.
var _published_unlocks: Dictionary = {}
var _published_steps: Dictionary = {}
var _signed_in := false
var _player_id := ""
var _sync_in_flight := false
var _sync_requested := false
var _force_remote_check := false
var _upload_blocked_for_session := false
var _verifying_upload := false
var _pending_upload_json := ""
var _pending_upload_counter := 0
var _verification_failures := 0
var _restore_pending := false
var _cloud_state: StringName = &"signed_out"
var _practice_active := false
var _sync_timer: Timer
var _sync_timeout_timer: Timer
var clock_override := Callable()
var reload_profile_callable := Callable()
var achievements_state_callable := Callable()
var profile_path := SaveManager.PROFILE_PATH


func _ready() -> void:
    _sync_timer = Timer.new()
    _sync_timer.one_shot = true
    _sync_timer.wait_time = SYNC_DEBOUNCE_SECONDS
    add_child(_sync_timer)
    _sync_timer.timeout.connect(_begin_sync_if_needed)
    _sync_timeout_timer = Timer.new()
    _sync_timeout_timer.one_shot = true
    _sync_timeout_timer.wait_time = SYNC_TIMEOUT_SECONDS
    add_child(_sync_timeout_timer)
    _sync_timeout_timer.timeout.connect(_on_sync_timeout)
    EventBus.profile_saved.connect(_on_local_profile_saved)
    EventBus.session_started.connect(_on_session_started)
    EventBus.session_ended.connect(_on_session_ended)
    EventBus.achievements_unlocked.connect(_on_achievements_unlocked)
    EventBus.application_paused.connect(_on_application_paused)
    reload_profile_callable = Callable(AppState, "reload_profile_from_disk")
    achievements_state_callable = Callable(AppState, "achievements_state")
    # Deferred so a slow or misbehaving plugin can never delay the first frame a child sees.
    call_deferred("_start")


func available() -> bool:
    return _plugin != null and _sign_in_client != null


func cloud_available() -> bool:
    return available() and _snapshots_client != null and _players_client != null


func achievements_available() -> bool:
    return available() and _achievements_client != null


func signed_in() -> bool:
    return _signed_in


func enabled() -> bool:
    return SettingsManager.play_games_enabled


func sync_state() -> StringName:
    if _upload_blocked_for_session:
        return &"blocked"
    if _sync_in_flight:
        return &"syncing"
    if _signed_in:
        return &"ready"
    return &"signed_out"


func cloud_needs_attention() -> bool:
    return _cloud_state in [
        &"account_changed",
        &"conflict_saved_locally",
        &"conflict_unresolved",
        &"invalid_remote",
        &"local_write_failed",
        &"premerge_failed",
        &"update_required",
        &"verification_failed",
    ]


func set_enabled(is_enabled: bool) -> void:
    if SettingsManager.play_games_enabled == is_enabled:
        return
    SettingsManager.set_play_games_enabled(is_enabled)
    if is_enabled:
        # Re-enabling backup is an explicit user action. Unlike the silent startup check, this
        # must use Google's interactive sign-in path so a signed-out player can actually recover.
        sign_in()
        return
    _sync_timer.stop()
    _sync_requested = false
    _finish_sync()
    _update_sign_in_state(false)


func sign_in() -> void:
    if not available() or not enabled():
        return
    _sign_in_client.sign_in()


## Requests a remote comparison without making the caller await it.
func sync_now(force_remote_check := true) -> void:
    if not cloud_available() or not signed_in() or not enabled():
        return
    _force_remote_check = _force_remote_check or force_remote_check
    _begin_sync_if_needed()


func _start() -> void:
    _resolve_plugin()
    availability_changed.emit(available())
    if available() and enabled():
        # Google Play Games is the account gate for cloud backup. Ask it to sign in once per
        # launch instead of merely inspecting the current state; failure remains asynchronous and
        # costs the offline game nothing, while a fresh install can restore without finding Settings.
        sign_in()


func _resolve_plugin() -> void:
    if OS.get_name() != "Android":
        return
    var plugin := get_node_or_null(PLUGIN_AUTOLOAD_PATH)
    if plugin == null or not plugin.has_method("initialize"):
        return
    var result: Variant = plugin.initialize()
    if result is int and int(result) != 0:
        push_warning("Play Games plugin present but its Android side did not initialise")
        return
    _plugin = plugin
    _sign_in_client = _create_client(SIGN_IN_CLIENT_SCRIPT, "NumblopSignInClient")
    _snapshots_client = _create_client(SNAPSHOTS_CLIENT_SCRIPT, "NumblopSnapshotsClient")
    _players_client = _create_client(PLAYERS_CLIENT_SCRIPT, "NumblopPlayersClient")
    _achievements_client = _create_client(ACHIEVEMENTS_CLIENT_SCRIPT, "NumblopAchievementsClient")
    _connect_cloud_clients()


func _create_client(script_path: String, node_name: String) -> Node:
    if not ResourceLoader.exists(script_path):
        return null
    var client_script: GDScript = load(script_path)
    if client_script == null or not client_script.can_instantiate():
        return null
    var client: Node = client_script.new()
    client.name = node_name
    add_child(client)
    return client


func _connect_cloud_clients() -> void:
    if _sign_in_client != null and _sign_in_client.has_signal("user_authenticated") \
            and not _sign_in_client.user_authenticated.is_connected(
        _on_user_authenticated
    ):
        _sign_in_client.user_authenticated.connect(_on_user_authenticated)
    if _snapshots_client != null and _snapshots_client.has_signal("game_loaded") \
            and _snapshots_client.has_signal("game_saved") \
            and _snapshots_client.has_signal("conflict_emitted"):
        if not _snapshots_client.game_loaded.is_connected(_on_game_loaded):
            _snapshots_client.game_loaded.connect(_on_game_loaded)
        if not _snapshots_client.game_saved.is_connected(_on_game_saved):
            _snapshots_client.game_saved.connect(_on_game_saved)
        if not _snapshots_client.conflict_emitted.is_connected(_on_snapshot_conflict):
            _snapshots_client.conflict_emitted.connect(_on_snapshot_conflict)
    if _players_client != null and _players_client.has_signal("current_player_loaded") \
            and not _players_client.current_player_loaded.is_connected(
        _on_current_player_loaded
    ):
        _players_client.current_player_loaded.connect(_on_current_player_loaded)


func _authenticate() -> void:
    if not available():
        return
    _sign_in_client.is_authenticated()


func _on_user_authenticated(is_authenticated: bool) -> void:
    _update_sign_in_state(is_authenticated and enabled())
    if not _signed_in:
        return
    # Backfill before anything else. A child may have played offline for months, and everything
    # they earned in that time has to reach Play the first time they ever sign in. Achievements do
    # not need the snapshot clients, so this does not wait on the cloud-save handshake.
    publish_achievements()
    if not cloud_available():
        return
    _players_client.load_current_player(true)


func _on_current_player_loaded(player: Variant) -> void:
    if not signed_in() or not enabled():
        return
    _player_id = _player_id_from(player)
    if _player_id.is_empty():
        _set_cloud_state(&"player_unavailable")
        return
    _upload_blocked_for_session = false
    _verification_failures = 0
    sync_now(true)


func _update_sign_in_state(state: bool) -> void:
    if state == _signed_in:
        return
    _signed_in = state
    if not state:
        _player_id = ""
        _sync_in_flight = false
        _verifying_upload = false
        _set_restore_pending(false)
        # A different account must be told everything from scratch rather than inheriting what the
        # previous one was already known to have.
        _published_unlocks.clear()
        _published_steps.clear()
    sign_in_state_changed.emit(_signed_in)
    _set_cloud_state(&"ready" if state else &"signed_out")


func _on_local_profile_saved() -> void:
    if not cloud_available() or not signed_in() or _upload_blocked_for_session:
        return
    # Answers are deliberately saved after every tap, but cloud work belongs between rounds. Apart
    # from avoiding needless network traffic, this prevents a remote merge from replacing the
    # in-memory profile and interrupting the question that is currently on screen.
    if _practice_active:
        _sync_requested = true
        return
    var state := SaveManager.load_state(profile_path)
    var cloud := LocalCloudSync.new(_dictionary(state, "cloud"))
    if cloud.last_synced_counter == _number(state, "save_counter"):
        return
    _sync_requested = true
    _sync_timer.start()


func _on_session_started(_question_count: int) -> void:
    _practice_active = true


func _on_session_ended() -> void:
    _practice_active = false
    # Progress bars move with a finished round, so this is where step counts are refreshed.
    publish_achievements()
    if _sync_requested and cloud_available() and signed_in() and not _upload_blocked_for_session:
        _sync_timer.start()


## Sent the moment an achievement completes, mid-round included.
##
## Nothing here reads anything back or touches the local profile, so unlike a snapshot merge it
## cannot disturb the question on screen. There is no reason to make a child wait for the round to
## end before Play tells them what they just did.
func _on_achievements_unlocked(_entries: Array) -> void:
    publish_achievements()


## Mirrors the local achievement state onto Play.
##
## Local is the truth and Play is the mirror: this only ever pushes, never reads back and never
## changes anything the game owns. Every call is fire-and-forget — the plugin's replies are not even
## connected — because an achievement that fails to reach Play must cost a child nothing at all.
##
## Completion is reported the way Console defines the achievement: `unlock()` for the single
## one-step achievement, and a full absolute step count for the twenty-four incremental ones. The
## distinction is not cosmetic — an incremental achievement never completes from an `unlock()`, so
## sending the wrong one loses every achievement a child earned offline.
func publish_achievements() -> void:
    if not achievements_available() or not signed_in() or not enabled():
        return
    if not achievements_state_callable.is_valid():
        return
    var state: Variant = achievements_state_callable.call()
    if state is not Dictionary:
        return
    var entries: Variant = (state as Dictionary).get("achievements", [])
    if entries is not Array:
        return
    for entry in entries:
        if entry is Dictionary:
            _publish_achievement(entry)


func _publish_achievement(entry: Dictionary) -> void:
    var local_id := String(entry.get("id", ""))
    # An achievement can exist in the game before it exists in Console. Skipping it keeps the build
    # playable; `tests/state/test_play_games_catalog.gd` is what stops it from shipping that way.
    var play_id := PlayGamesCatalog.achievement_id(local_id)
    if play_id.is_empty():
        return

    var target := int(entry.get("target", 0))
    if bool(entry.get("completed", false)):
        if _published_unlocks.has(local_id):
            return
        _published_unlocks[local_id] = true
        # Console makes every multi-step achievement incremental, and Play ignores `unlock()` on
        # one of those -- it completes only when its steps reach the target. Sending the target as
        # an absolute step count is what finishes it, and it stays idempotent on a re-send.
        if target > 1:
            _published_steps[local_id] = target
            _achievements_client.set_achievement_steps(play_id, target)
        else:
            _achievements_client.unlock_achievement(play_id)
        return

    # A one-step achievement has no progress to report; it is either unlocked or it is not.
    if target <= 1:
        return
    var progress := clampi(int(entry.get("progress", 0)), 0, target)
    if progress <= 0 or int(_published_steps.get(local_id, 0)) >= progress:
        return
    _published_steps[local_id] = progress
    # Absolute steps, not a delta. Play keeps the higher value, which is exactly what a local
    # mastery dip -- or a reinstall that has not merged yet -- must not be able to undo.
    _achievements_client.set_achievement_steps(play_id, progress)


func _on_application_paused() -> void:
    if cloud_available() and signed_in() and not _upload_blocked_for_session:
        _sync_requested = true
        _begin_sync_if_needed()


func _begin_sync_if_needed() -> void:
    if _sync_in_flight:
        _sync_requested = true
        return
    if _practice_active:
        _sync_requested = true
        return
    if not cloud_available() or not signed_in() or not enabled() \
            or _player_id.is_empty() or _upload_blocked_for_session:
        return
    var local := SaveManager.load_state(profile_path)
    var cloud := LocalCloudSync.new(_dictionary(local, "cloud"))
    if not cloud.player_id.is_empty() and cloud.player_id != _player_id:
        # Never upload one child's local progress into a different Play account silently.
        _block_upload(&"account_changed")
        return
    if not _force_remote_check and cloud.last_synced_counter == _number(local, "save_counter"):
        _sync_requested = false
        return
    _sync_requested = false
    _force_remote_check = false
    _sync_in_flight = true
    _verifying_upload = false
    # From here until the comparison resolves, the local save may still be replaced by a remote one.
    _set_restore_pending(true)
    _set_cloud_state(&"syncing")
    _snapshots_client.load_game(SNAPSHOT_NAME, false)
    _sync_timeout_timer.start()


func _on_game_loaded(snapshot: Variant) -> void:
    if not _sync_in_flight or not signed_in() or not enabled():
        return
    _sync_timeout_timer.stop()
    if _practice_active:
        # The request may have started on the home screen and returned after Play was tapped. Do
        # not write or reload anything until AppState has settled the round; its per-answer saves
        # remain authoritative in the meantime.
        _sync_requested = true
        _finish_sync()
        _set_cloud_state(&"ready")
        return
    var content := _snapshot_content(snapshot)
    if _verifying_upload:
        _verify_uploaded_content(content)
        return

    var local := SaveManager.load_state(profile_path)
    var remote: Dictionary = {}
    if snapshot != null:
        var payload := decode_snapshot_payload(content)
        if payload.is_empty():
            _block_upload(&"invalid_remote")
            return
        if _number(payload, "schema") > SaveMigration.CURRENT_VERSION:
            _block_upload(&"update_required")
            return
        remote = SaveMigration.migrate(_dictionary(payload, "profile"))
        if remote.is_empty() or SaveMigration.is_from_newer_build(remote):
            _block_upload(&"invalid_remote")
            return

    var cloud := LocalCloudSync.new(_dictionary(local, "cloud"))
    cloud.player_id = _player_id
    if remote.is_empty():
        # An empty cloud has nothing to merge. Upload the existing local file directly instead of
        # rewriting it merely to increment its counter; the verified acknowledgement below stores
        # the player binding and sync marker.
        if local.is_empty():
            _set_cloud_state(&"synced")
            _finish_sync()
        else:
            # Nothing came back, so nothing can overwrite this device. The upload that follows is
            # this device's own data going out and cannot change what is already on screen.
            _set_restore_pending(false)
            _upload_state(local)
        return
    if CloudSaveMerge.has_progress(local) and CloudSaveMerge.has_progress(remote):
        if SaveManager.write_premerge_copy(local, profile_path) != OK:
            _block_upload(&"premerge_failed")
            return

    var merged := CloudSaveMerge.merge(local, remote)
    if SaveManager.save_merged_state(merged, cloud.to_dictionary(), profile_path) != OK:
        _block_upload(&"local_write_failed")
        return
    _reload_runtime_profile()
    # The restored state is on disk and in memory; the rest of this sync only pushes it back out.
    _set_restore_pending(false)
    _upload_state(SaveManager.load_state(profile_path))


func _upload_state(state: Dictionary) -> void:
    if _upload_blocked_for_session:
        _finish_sync()
        return
    _pending_upload_counter = _number(state, "save_counter")
    _pending_upload_json = JSON.stringify(build_snapshot_payload(state))
    # This metadata can surface in Google's UI. Keep it language-neutral instead of placing
    # untranslatable prose in GDScript.
    var description := "Numblop"
    _snapshots_client.save_game(
        SNAPSHOT_NAME,
        description,
        _pending_upload_json.to_utf8_buffer(),
        0,
        _number(state, "experience")
    )
    _sync_timeout_timer.start()


func _on_game_saved(is_saved: bool, save_data_name: String, _description: String) -> void:
    if not _sync_in_flight or save_data_name != SNAPSHOT_NAME:
        return
    if _practice_active:
        # The commit was already dispatched, but even its read-back and local acknowledgement wait
        # until practice ends. The next comparison safely converges whether that commit landed or
        # not.
        _sync_requested = true
        _finish_sync()
        _set_cloud_state(&"ready")
        return
    if not is_saved:
        _finish_sync()
        return
    # The upstream plugin emits this when commit is dispatched, not when the Task completes.
    # Read the snapshot back and acknowledge only an exact round trip.
    _verifying_upload = true
    _snapshots_client.load_game(SNAPSHOT_NAME, false)
    _sync_timeout_timer.start()


func _verify_uploaded_content(content: PackedByteArray) -> void:
    _verifying_upload = false
    var returned := decode_snapshot_payload(content)
    var expected := decode_snapshot_payload(_pending_upload_json.to_utf8_buffer())
    if returned.is_empty() or expected.is_empty() \
            or JSON.stringify(returned) != JSON.stringify(expected):
        _verification_failures += 1
        # Do not immediately loop on the save that the merge itself emitted. A later local save
        # may try again after the ordinary debounce, but a persistent mismatch is capped for this
        # launch so it cannot consume a child's battery and data indefinitely.
        _sync_requested = false
        if _verification_failures >= MAX_VERIFICATION_FAILURES:
            _block_upload(&"verification_failed")
        else:
            _set_cloud_state(&"verification_retry_pending")
            _finish_sync()
        return
    _verification_failures = 0
    var current := SaveManager.load_state(profile_path)
    if _number(current, "save_counter") == _pending_upload_counter:
        var cloud := LocalCloudSync.new(_dictionary(current, "cloud"))
        # The acknowledgement itself is a write, so predict the counter it will produce. This
        # makes the bookkeeping write clean rather than immediately scheduling another upload.
        cloud.last_synced_counter = _pending_upload_counter + 1
        cloud.last_synced_at_unix = _now()
        cloud.player_id = _player_id
        if SaveManager.save_merged_state(current, cloud.to_dictionary(), profile_path) == OK:
            SaveManager.clear_premerge_copy(profile_path)
    _set_cloud_state(&"synced")
    _finish_sync()


## The vendored v3.4.0 plugin exposes both candidates but no resolve-conflict call. We still merge
## every candidate into the local durable save, then block upload for this launch. That preserves
## everything the child earned and avoids an endless destructive overwrite loop; cloud convergence
## remains blocked until upstream exposes `SnapshotsClient.resolveConflict`.
func _on_snapshot_conflict(conflict: Variant) -> void:
    if not _sync_in_flight or not signed_in() or not enabled():
        return
    _sync_timeout_timer.stop()
    if _practice_active:
        _sync_requested = true
        _finish_sync()
        _set_cloud_state(&"ready")
        return
    var local := SaveManager.load_state(profile_path)
    if SaveManager.write_premerge_copy(local, profile_path) != OK:
        _block_upload(&"premerge_failed")
        return
    var merged := local
    for candidate in _conflict_snapshots(conflict):
        var payload := decode_snapshot_payload(_snapshot_content(candidate))
        if payload.is_empty() or _number(payload, "schema") > SaveMigration.CURRENT_VERSION:
            _block_upload(&"conflict_unresolved")
            return
        var candidate_profile := SaveMigration.migrate(_dictionary(payload, "profile"))
        if candidate_profile.is_empty() or SaveMigration.is_from_newer_build(candidate_profile):
            _block_upload(&"conflict_unresolved")
            return
        merged = CloudSaveMerge.merge(merged, candidate_profile)
    var cloud := LocalCloudSync.new(_dictionary(local, "cloud"))
    cloud.player_id = _player_id
    if SaveManager.save_merged_state(merged, cloud.to_dictionary(), profile_path) == OK:
        _reload_runtime_profile()
    _block_upload(&"conflict_saved_locally")


func _block_upload(reason: StringName) -> void:
    _upload_blocked_for_session = true
    _set_cloud_state(reason)
    _finish_sync()


func _finish_sync() -> void:
    _sync_timeout_timer.stop()
    _sync_in_flight = false
    _verifying_upload = false
    _pending_upload_json = ""
    _pending_upload_counter = 0
    # Announced only once this autoload has settled, and the backstop for every path that ends a
    # sync early: a timeout, a block, a deferral to the end of practice, or a sign-out. Nothing may
    # leave the flag raised.
    _set_restore_pending(false)
    if _sync_requested and not _upload_blocked_for_session:
        call_deferred("_begin_sync_if_needed")


func _on_sync_timeout() -> void:
    if not _sync_in_flight:
        return
    _set_cloud_state(&"retry_pending")
    _finish_sync()


func _reload_runtime_profile() -> void:
    if reload_profile_callable.is_valid():
        reload_profile_callable.call()


## Announces whether a remote save could still land on top of this device.
##
## Published on `EventBus` rather than through this autoload's own signals, so a scene can wait for
## a restore without ever naming Play Games.
func _set_restore_pending(pending: bool) -> void:
    if _restore_pending == pending:
        return
    _restore_pending = pending
    EventBus.external_restore_pending.emit(pending)


func restore_pending() -> bool:
    return _restore_pending


func _set_cloud_state(state: StringName) -> void:
    _cloud_state = state
    cloud_sync_state_changed.emit(state)


func _now() -> int:
    if clock_override.is_valid():
        return int(clock_override.call())
    return int(Time.get_unix_time_from_system())


func build_snapshot_payload(state: Dictionary) -> Dictionary:
    return {
        "schema": SaveMigration.CURRENT_VERSION,
        "app_version": str(ProjectSettings.get_setting("application/config/version", "")),
        "written_at_unix": _now(),
        "device_id": _string(state, "profile_id"),
        "save_counter": _number(state, "save_counter"),
        "profile": state.duplicate(true),
    }


func decode_snapshot_payload(content: PackedByteArray) -> Dictionary:
    if content.is_empty():
        return {}
    var parser := JSON.new()
    if parser.parse(content.get_string_from_utf8()) != OK or parser.data is not Dictionary:
        return {}
    var payload: Dictionary = parser.data
    if payload.get("schema") is not int and payload.get("schema") is not float:
        return {}
    if payload.get("profile") is not Dictionary:
        return {}
    return payload


func _snapshot_content(snapshot: Variant) -> PackedByteArray:
    if snapshot == null:
        return PackedByteArray()
    var raw: Variant = snapshot.get("content") if snapshot is Object else snapshot.get("content", null)
    return raw if raw is PackedByteArray else PackedByteArray()


func _conflict_snapshots(conflict: Variant) -> Array:
    if conflict == null:
        return []
    return [conflict.get("conflicting_snapshot"), conflict.get("server_snapshot")]


func _player_id_from(player: Variant) -> String:
    if player == null:
        return ""
    var raw: Variant = player.get("player_id") if player is Object else player.get("player_id", "")
    return raw if raw is String else ""


func _number(data: Dictionary, key: String) -> int:
    var raw: Variant = data.get(key, 0)
    return maxi(0, int(raw)) if raw is int or raw is float else 0


func _string(data: Dictionary, key: String) -> String:
    var raw: Variant = data.get(key, "")
    return raw if raw is String else ""


func _dictionary(data: Dictionary, key: String) -> Dictionary:
    var raw: Variant = data.get(key, {})
    return raw if raw is Dictionary else {}


## Test seam: installs stand-ins without invoking Android or touching the vendored plugin.
func _set_plugin_for_test(
    fake_plugin: Node,
    fake_sign_in_client: Node = null,
    fake_snapshots_client: Node = null,
    fake_players_client: Node = null,
    fake_achievements_client: Node = null
) -> void:
    _plugin = fake_plugin
    _sign_in_client = fake_sign_in_client if fake_plugin != null else null
    _snapshots_client = fake_snapshots_client if fake_plugin != null else null
    _players_client = fake_players_client if fake_plugin != null else null
    _achievements_client = fake_achievements_client if fake_plugin != null else null
    _published_unlocks.clear()
    _published_steps.clear()
    _signed_in = false
    _player_id = ""
    _sync_in_flight = false
    _sync_requested = false
    _upload_blocked_for_session = false
    _verifying_upload = false
    _verification_failures = 0
    _set_restore_pending(false)
    _cloud_state = &"signed_out"
    _practice_active = false
    profile_path = SaveManager.PROFILE_PATH
    if fake_plugin != null:
        _connect_cloud_clients()
