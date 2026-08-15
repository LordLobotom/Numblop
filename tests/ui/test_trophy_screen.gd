extends NumblopTestCase

## Every achievement must ship its own artwork, at the one size the trophy tile needs.
##
## The same shape of contract as "every string in all ten languages": the catalog is the source of
## truth, and art that is missing or oversized is a failure here rather than a surprise on a phone.

const ICON_DIRECTORY := "res://ui/achievements"
## The tile is 64 px, so 192 covers a 3x display exactly. A full-size original dropped in here
## would be about 2 MB each and would quietly add tens of megabytes to the build.
const ICON_SIZE := Vector2i(192, 192)


func test_every_achievement_in_the_catalog_has_its_own_icon() -> void:
    for entry in AchievementCatalog.definitions():
        var achievement_id := String(entry["id"])
        var icon_path := "%s/%s.png" % [ICON_DIRECTORY, achievement_id]
        check(
            ResourceLoader.exists(icon_path),
            "%s has artwork at %s" % [achievement_id, icon_path]
        )


func test_achievement_icons_are_drawn_at_the_size_the_tile_needs() -> void:
    for entry in AchievementCatalog.definitions():
        var achievement_id := String(entry["id"])
        var icon_path := "%s/%s.png" % [ICON_DIRECTORY, achievement_id]
        if not ResourceLoader.exists(icon_path):
            continue
        var texture: Texture2D = load(icon_path)
        check(texture != null, "%s icon loads as a texture" % achievement_id)
        if texture != null:
            equal(texture.get_size(), Vector2(ICON_SIZE), "%s icon size" % achievement_id)


func test_the_trophy_screen_resolves_one_icon_per_achievement() -> void:
    var packed: PackedScene = load("res://scenes/screens/TrophyScreen.tscn")
    check(packed != null, "Trophy scene must load")
    if packed == null:
        return
    var scene: TrophyScreen = packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)

    var seen: Dictionary = {}
    for entry in AchievementCatalog.definitions():
        var achievement_id := String(entry["id"])
        var icon := scene.achievement_icon(achievement_id)
        check(icon != null, "%s resolves an icon" % achievement_id)
        if icon != null:
            seen[icon.resource_path] = achievement_id
    equal(
        seen.size(),
        AchievementCatalog.definitions().size(),
        "No two achievements share the same artwork"
    )

    # A catalog entry can be added before its art is drawn; that row must still render.
    equal(
        scene.achievement_icon("not_drawn_yet"),
        TrophyScreen.TROPHY_TEXTURE,
        "An achievement without artwork falls back to the trophy crest"
    )

    scene_tree.root.remove_child(scene)
    scene.free()
