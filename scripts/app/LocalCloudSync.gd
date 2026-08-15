class_name LocalCloudSync
extends RefCounted

## What this device has already synchronised with Play Games Saved Games.
##
## Inert until the cloud phase exists. It is written now so that turning synchronisation on later
## needs no second migration over live player data -- see `docs/GOOGLE_PLAY_GAMES.md`.

var last_synced_counter := 0
var last_synced_at_unix := 0
## The Play player this profile last synchronised as. A different id means the device changed
## account, which a merge has to treat differently from an ordinary two-device conflict.
var player_id := ""


func _init(data: Dictionary = {}) -> void:
    last_synced_counter = _loaded_number(data, "last_synced_counter")
    last_synced_at_unix = _loaded_number(data, "last_synced_at_unix")
    var loaded_player: Variant = data.get("player_id", "")
    player_id = loaded_player if loaded_player is String else ""


## Nothing may be inferred from a value that is not a number: a corrupt counter that reads as a
## huge integer would make this device win every merge for good.
static func _loaded_number(data: Dictionary, key: String) -> int:
    var raw: Variant = data.get(key, 0)
    if raw is float or raw is int:
        return maxi(0, int(raw))
    return 0


func to_dictionary() -> Dictionary:
    return {
        "last_synced_counter": last_synced_counter,
        "last_synced_at_unix": last_synced_at_unix,
        "player_id": player_id,
    }
