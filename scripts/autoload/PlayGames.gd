extends Node

## The only place in Numblop that knows Play Games Services exists.
##
## It wraps the vendored `addons/GodotPlayGameServices` plugin (v3.4.0) so that the rest of the
## game never sees a plugin API, an Android singleton, or a missing one. On Windows, on the Web, in
## the editor, in tests, and on any Android build where the plugin failed to load, `available()` is
## false and every method returns immediately. **If this autoload were deleted, the game would still
## run**; only the Settings row that switches cloud save on and off refers to it.
##
## Cloud save is **on by default**. On Android the plugin is initialised at startup and Google --
## through the device account and Family Link for supervised children -- decides whether sign-in is
## allowed and what a child may use. Numblop does not put its own gate in front of that.
##
## Authentication is best-effort and silent. Offline, signed out, on a restricted account, or with
## Play Services missing entirely, sign-in simply does not complete and the game carries on exactly
## as it always did. No game rule waits on any of this.
##
## Sign-in only, for now. Saving to the cloud arrives in P2; see `docs/GOOGLE_PLAY_GAMES.md`.

signal availability_changed(available: bool)
signal sign_in_state_changed(signed_in: bool)

## The plugin's own autoload, which owns the bridge to the Android singleton.
const PLUGIN_AUTOLOAD_PATH := "/root/GodotPlayGameServices"
## Loaded by path rather than by `class_name`, so deleting the addon leaves this file still
## parsing -- and therefore still able to report "unavailable" -- instead of breaking the build.
const SIGN_IN_CLIENT_SCRIPT := (
    "res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd"
)

var _plugin: Node = null
var _sign_in_client: Node = null
var _signed_in := false


func _ready() -> void:
    # Deferred so a slow or misbehaving plugin can never delay the first frame a child sees.
    call_deferred("_start")


## True when the plugin loaded and its Android side answered. False everywhere else.
func available() -> bool:
    return _plugin != null and _sign_in_client != null


func signed_in() -> bool:
    return _signed_in


## Whether cloud save is switched on for this device. On unless someone turned it off.
func enabled() -> bool:
    return SettingsManager.play_games_enabled


## Switches cloud save on or off.
##
## Turning it off does not sign the player out of Play itself -- that is the account's business,
## not this game's -- but Numblop stops talking to it and goes back to being purely local.
func set_enabled(is_enabled: bool) -> void:
    if SettingsManager.play_games_enabled == is_enabled:
        return
    SettingsManager.set_play_games_enabled(is_enabled)
    if is_enabled:
        _authenticate()
        return
    _update_sign_in_state(false)


## Offers a manual sign-in for a player whose automatic one did not take.
func sign_in() -> void:
    if not available() or not enabled():
        return
    _sign_in_client.sign_in()


func _start() -> void:
    _resolve_plugin()
    availability_changed.emit(available())
    if available() and enabled():
        _authenticate()


## Finds the plugin's autoload and brings up the sign-in client.
##
## Everything is looked up rather than referenced by class, so a build without the addon -- or a
## future version that renames something -- degrades to "unavailable" instead of failing to load.
func _resolve_plugin() -> void:
    if OS.get_name() != "Android":
        return
    var plugin := get_node_or_null(PLUGIN_AUTOLOAD_PATH)
    if plugin == null or not plugin.has_method("initialize"):
        return
    # PLUGIN_NOT_FOUND (1) means the Android singleton is absent, which is the normal case for a
    # build exported without the .aar. Anything other than OK leaves the game offline.
    var result: Variant = plugin.initialize()
    if result is int and int(result) != 0:
        push_warning("Play Games plugin present but its Android side did not initialise")
        return
    _plugin = plugin
    _sign_in_client = _create_sign_in_client()


func _create_sign_in_client() -> Node:
    if not ResourceLoader.exists(SIGN_IN_CLIENT_SCRIPT):
        return null
    var client_script: GDScript = load(SIGN_IN_CLIENT_SCRIPT)
    if client_script == null or not client_script.can_instantiate():
        return null
    var client: Node = client_script.new()
    client.name = "NumblopSignInClient"
    add_child(client)
    client.user_authenticated.connect(_on_user_authenticated)
    return client


## Asks Play whether this device is already signed in.
##
## `is_authenticated()` is the quiet path: the plugin checks the existing session and only Google
## decides whether to show anything. A failure is not retried and not surfaced -- a child who is
## offline or on a restricted account must never see an error they cannot act on.
func _authenticate() -> void:
    if not available():
        return
    _sign_in_client.is_authenticated()


func _on_user_authenticated(is_authenticated: bool) -> void:
    _update_sign_in_state(is_authenticated and enabled())


func _update_sign_in_state(state: bool) -> void:
    if state == _signed_in:
        return
    _signed_in = state
    sign_in_state_changed.emit(_signed_in)


## Test seam: installs a stand-in for the plugin and its sign-in client.
##
## Nothing in the game calls it. It exists because the alternative -- proving the no-op guarantee
## only on real hardware -- means the behaviour that protects every Windows and Web player is never
## actually tested.
func _set_plugin_for_test(fake_plugin: Node, fake_sign_in_client: Node = null) -> void:
    _plugin = fake_plugin
    _sign_in_client = fake_sign_in_client if fake_plugin != null else null
    _signed_in = false
