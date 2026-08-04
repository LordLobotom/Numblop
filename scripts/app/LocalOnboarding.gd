class_name LocalOnboarding
extends RefCounted

## How far the one-time guided tutorial got.
##
## `step` is kept beside `completed` so a child who closes the game halfway through is
## pointed at the control they stopped on, instead of being walked from the Play button
## again. Once `completed` is true the tutorial never runs on this profile.

var completed := false
var step := 0


func _init(data: Dictionary = {}) -> void:
    # A corrupt save must not decide the tutorial is finished, so anything that is not a
    # real flag counts as "not yet".
    var loaded_completed: Variant = data.get("completed", false)
    completed = loaded_completed if loaded_completed is bool else false
    var loaded_step: Variant = data.get("step", 0)
    step = maxi(0, int(loaded_step)) if loaded_step is float or loaded_step is int else 0


func to_dictionary() -> Dictionary:
    return {
        "completed": completed,
        "step": step,
    }
