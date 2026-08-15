extends NumblopTestCase

## The mapping between the game's achievements and Play Console's is the one part of the
## integration that cannot be derived from anything. Console generates opaque ids, so a new
## achievement reaches Play only if someone remembers to add a line -- and if they forget, nothing
## fails at runtime: that achievement is quietly skipped forever. This is where it fails instead.


func test_every_achievement_in_the_catalog_has_a_play_id() -> void:
    for entry in AchievementCatalog.definitions():
        var achievement_id := String(entry["id"])
        check(
            PlayGamesCatalog.has_achievement(achievement_id),
            "%s has a Play Console id" % achievement_id
        )


func test_no_play_id_outlives_the_achievement_it_belonged_to() -> void:
    var known: Dictionary = {}
    for entry in AchievementCatalog.definitions():
        known[String(entry["id"])] = true
    for local_id in PlayGamesCatalog.ACHIEVEMENT_IDS:
        check(
            known.has(String(local_id)),
            "%s is still an achievement the game has" % local_id
        )


func test_play_ids_are_unique_and_non_empty() -> void:
    # Two achievements sharing an id would silently unlock the wrong one, which is worse than
    # unlocking nothing at all.
    var seen: Dictionary = {}
    for local_id in PlayGamesCatalog.ACHIEVEMENT_IDS:
        var play_id := PlayGamesCatalog.achievement_id(String(local_id))
        check(not play_id.is_empty(), "%s maps to a real id" % local_id)
        check(not seen.has(play_id), "%s does not reuse %s's id" % [local_id, seen.get(play_id, "")])
        seen[play_id] = local_id


func test_an_unknown_achievement_resolves_to_nothing_rather_than_failing() -> void:
    # A build may add an achievement before it exists in Console. The game must stay playable.
    equal(PlayGamesCatalog.achievement_id("not_in_console_yet"), "", "Unknown id maps to nothing")
    check(not PlayGamesCatalog.has_achievement(""), "An empty id is not an achievement")
