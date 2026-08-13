extends NumblopTestCase


## Resolves a footer crest by path.
##
## The five items now live in scenes/components/NavBar.tscn, so their unique names
## belong to that scene's owner and no longer resolve from a screen root. The path
## itself is unchanged, and is what the navigation contract pins.
func _nav_button(screen: Node, button_name: String) -> BaseButton:
    var item_name := button_name.replace("Button", "Item")
    return screen.get_node(
        "SafeArea/Content/Navigation/NavigationRow/%s/%s" % [item_name, button_name]
    )


func test_main_scene_has_touch_ready_portrait_controls() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    var scene := packed.instantiate()
    var home: HomeScreen = scene.get_node("HomeScreen")
    var play_button: PlayButton = home.get_node("%PlayButton")
    check(play_button.custom_minimum_size.y >= 48.0, "Play touch target")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var crest_button := _nav_button(home, button_name)
        check(crest_button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    check(home.get_node_or_null("%LanguageSelect") == null, "No language picker on home")
    check(scene.has_node("HomeScreen"), "Main scene must contain the blob home")
    check(scene.has_node("MapScreen"), "Main scene must contain the stage map")
    check(scene.has_node("SettingsScreen"), "Main scene must contain settings")
    check(scene.has_node("CosmeticsScreen"), "Main scene must contain cosmetics")
    check(scene.has_node("TrophyScreen"), "Main scene must contain streak records")
    check(scene.has_node("OpeningScreen"), "Main scene must start with the opening overlay")
    scene.free()


func test_home_crest_navigation_uses_requested_artwork_and_bold_play_font() -> void:
    var packed: PackedScene = load("res://scenes/screens/HomeScreen.tscn")
    check(packed != null, "Home scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var expected_paths := {
        "OutfitButton": "res://ui/crests/crest_outfit.png",
        "MapButton": "res://ui/crests/crest_map.png",
        "HomeButton": "res://ui/crests/crest_home.png",
        "TrophyButton": "res://ui/crests/crest_trophy.png",
        "SettingsButton": "res://ui/crests/crest_settings.png",
    }
    for button_name in expected_paths:
        var button := _nav_button(scene, button_name)
        equal(button.texture_normal.resource_path, expected_paths[button_name], button_name)
    var navigation_row := scene.get_node("SafeArea/Content/Navigation/NavigationRow")
    var navigation_order: Array[String] = []
    for item in navigation_row.get_children():
        navigation_order.append(str(item.name))
    equal(
        navigation_order,
        ["OutfitItem", "MapItem", "HomeItem", "TrophyItem", "SettingsItem"],
        "Home remains the middle footer item"
    )
    var play_label: Label = scene.get_node("%PlayLabel")
    equal(
        play_label.get_theme_font("font").resource_path,
        "res://ui/fonts/Baloo2Bold.tres",
        "Play uses the bold font"
    )
    # The label is a full-rect child of the 340x104 %PlayButton, so these offsets exist only
    # to place it on the lit face rather than on the button box. The face is now drawn by
    # PlayButton rather than measured off a PNG, so the numbers come from its constants:
    #   body   = 340x104 inset by OUTLINE_WIDTH 5  -> y 5..99
    #   face   = body minus LIP_HEIGHT 8 at the foot -> y 5..91, centre 48
    #   glyph  = 30% of the face height, its tip GLYPH_RIGHT_MARGIN 24 from the body's
    #            right edge -> it occupies roughly x 289..311
    # "Hrát" at font size 36 is about 110 px wide, so a centred label spans 114..224 and
    # clears the glyph comfortably.
    equal(play_label.offset_left, 20.0, "Play label sits right of the pill's left edge")
    equal(play_label.offset_right, -22.0, "Play label still clears the triangle glyph")
    equal(
        (play_label.offset_left + 340.0 + play_label.offset_right) / 2.0,
        169.0,
        "Play text centres 169 px across the button"
    )
    equal(play_label.offset_bottom, -8.0, "Play label sits on the lit pill face")
    equal(
        (play_label.offset_top + 104.0 + play_label.offset_bottom) / 2.0,
        48.0,
        "Play text centres on the drawn face, 48 px down the button"
    )
    scene.free()


func test_home_uses_one_stats_bar_with_the_flame_streak() -> void:
    var packed: PackedScene = load("res://scenes/screens/HomeScreen.tscn")
    check(packed != null, "Home scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.get_node("%StatsBar") is PanelContainer, "One shared stats background")
    check(scene.get_node_or_null("SafeArea/Content/Stats/CoinsPanel") == null, "No coin card")
    check(scene.get_node_or_null("SafeArea/Content/Stats/XpPanel") == null, "No XP card")
    check(scene.get_node("%StreakLabel") is Label, "Visible streak count")
    equal(
        scene.get_node("%FlameIcon").texture.resource_path,
        "res://ui/crests/crest_flame.png",
        "Streak flame artwork"
    )
    check(scene.has_method("set_streak"), "Home accepts streak presentation state")
    scene.free()


func test_bottom_navigation_spreads_five_items_evenly_at_wider_sizes() -> void:
    for scene_path in [
        "res://scenes/screens/HomeScreen.tscn",
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Navigation scene loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var row := scene.get_node("SafeArea/Content/Navigation/NavigationRow")
        equal(row.get_child_count(), 5, "Five navigation items")
        for item in row.get_children():
            equal(
                item.size_flags_horizontal,
                Control.SIZE_EXPAND_FILL,
                "%s expands equally" % item.name
            )
        scene.free()


func test_every_screen_highlights_its_own_navigation_item() -> void:
    # Each screen used to hand-encode the active item twice, by sizing one crest larger
    # and bolding its label, with nothing tying the two together or checking the screen
    # highlighted itself. The component derives both from one property.
    var expected_active := {
        "res://scenes/screens/HomeScreen.tscn": NavBar.Item.HOME,
        "res://scenes/screens/MapScreen.tscn": NavBar.Item.MAP,
        "res://scenes/screens/CosmeticsScreen.tscn": NavBar.Item.OUTFIT,
        "res://scenes/screens/TrophyScreen.tscn": NavBar.Item.TROPHY,
        "res://scenes/screens/SettingsScreen.tscn": NavBar.Item.SETTINGS,
    }
    var button_for_item := {
        NavBar.Item.OUTFIT: "OutfitButton",
        NavBar.Item.MAP: "MapButton",
        NavBar.Item.HOME: "HomeButton",
        NavBar.Item.TROPHY: "TrophyButton",
        NavBar.Item.SETTINGS: "SettingsButton",
    }
    for scene_path in expected_active:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Screen loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var navigation := scene.get_node("SafeArea/Content/Navigation") as NavBar
        check(navigation != null, "%s uses the shared footer" % scene_path.get_file())
        if navigation == null:
            scene.free()
            continue
        var active: NavBar.Item = expected_active[scene_path]
        equal(navigation.active_item, active, "%s highlights itself" % scene_path.get_file())
        for item in button_for_item:
            var button := _nav_button(scene, button_for_item[item])
            check(
                button.custom_minimum_size.y >= 48.0,
                "%s stays a touch target" % button_for_item[item]
            )
        scene.free()


func test_title_headers_share_one_stylebox() -> void:
    # The four headers had drifted to two background alphas and two vertical paddings.
    # Their contents still differ -- a coin pill here, a crest there -- so the shared pieces
    # are the card style here and the title scale in the test below, not a header component.
    for scene_path in [
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Screen loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var header: PanelContainer = scene.get_node("SafeArea/Content/Header")
        var style := header.get_theme_stylebox("panel")
        equal(
            style.resource_path,
            "res://ui/styles/header_panel.tres",
            "%s uses the shared header card" % scene_path.get_file()
        )
        scene.free()


func test_screen_titles_share_one_size_and_face() -> void:
    # Extracting a HeaderBar component would have moved %TitleLabel into a sub-scene, where
    # its unique name no longer resolves from the screen root. The headers stayed four scenes,
    # and this is what pays for that choice: the titles must not drift apart again.
    var bold: Font = load("res://ui/fonts/Baloo2Bold.tres")
    for scene_path in [
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Screen loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var title: Label = scene.get_node("%TitleLabel")
        equal(
            title.get_theme_font_size("font_size"),
            22,
            "%s title uses the heading step" % scene_path.get_file()
        )
        equal(
            title.get_theme_font("font"),
            bold,
            "%s title uses the bold face" % scene_path.get_file()
        )
        check(
            scene.get_node("SafeArea/Content/Header").is_ancestor_of(title),
            "%s title lives in the shared header card" % scene_path.get_file()
        )
        scene.free()


func test_nav_bar_grows_and_bolds_only_the_active_item() -> void:
    # Exercised through the component's real lifecycle: the highlight is applied in
    # _ready, so a scene that never enters the tree still carries the authored sizes.
    var packed: PackedScene = load("res://scenes/components/NavBar.tscn")
    check(packed != null, "NavBar component must load")
    if packed == null:
        return
    var button_for_item := {
        NavBar.Item.OUTFIT: "OutfitButton",
        NavBar.Item.MAP: "MapButton",
        NavBar.Item.HOME: "HomeButton",
        NavBar.Item.TROPHY: "TrophyButton",
        NavBar.Item.SETTINGS: "SettingsButton",
    }
    var label_for_item := {
        NavBar.Item.OUTFIT: "OutfitLabel",
        NavBar.Item.MAP: "MapLabel",
        NavBar.Item.HOME: "HomeLabel",
        NavBar.Item.TROPHY: "TrophyLabel",
        NavBar.Item.SETTINGS: "SettingsLabel",
    }
    var scene_tree := Engine.get_main_loop() as SceneTree
    for active in button_for_item:
        var navigation: NavBar = packed.instantiate()
        navigation.active_item = active
        scene_tree.root.add_child(navigation)
        for item in button_for_item:
            var button: BaseButton = navigation.get_node("%%%s" % button_for_item[item])
            var label: Label = navigation.get_node("%%%s" % label_for_item[item])
            var is_active: bool = item == active
            equal(
                button.custom_minimum_size,
                NavBar.ACTIVE_CREST_SIZE if is_active else NavBar.IDLE_CREST_SIZE,
                "%s crest size when %s is active" % [button_for_item[item], active]
            )
            check(button.custom_minimum_size.y >= 48.0, "Crest stays a touch target")
            equal(
                label.get_theme_font("font") == NavBar.BOLD_FONT,
                is_active,
                "%s bold only when active" % label_for_item[item]
            )
        scene_tree.root.remove_child(navigation)
        navigation.free()


func test_navigation_screens_center_a_540_pixel_column_on_wide_displays() -> void:
    for scene_path in [
        "res://scenes/screens/HomeScreen.tscn",
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Responsive scene loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var safe_area := scene.get_node("SafeArea") as CenteredContentMargin
        check(safe_area != null, "Screen uses the centered content margin")
        if safe_area == null:
            scene.free()
            continue

        safe_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
        safe_area.size = Vector2(390.0, 844.0)
        safe_area._update_margins()
        equal(safe_area.get_theme_constant("margin_left"), 16, "Phone left margin")
        equal(safe_area.get_theme_constant("margin_right"), 16, "Phone right margin")
        # Vertical insets are the authored base off-device; a notch or gesture bar is
        # added on top of these only when running on a handset.
        equal(safe_area.get_theme_constant("margin_top"), 20, "Phone top margin")
        equal(safe_area.get_theme_constant("margin_bottom"), 16, "Phone bottom margin")

        safe_area.size = Vector2(900.0, 900.0)
        safe_area._update_margins()
        equal(safe_area.get_theme_constant("margin_left"), 180, "Wide left margin")
        equal(safe_area.get_theme_constant("margin_right"), 180, "Wide right margin")
        equal(
            safe_area.size.x
                - safe_area.get_theme_constant("margin_left")
                - safe_area.get_theme_constant("margin_right"),
            540.0,
            "Wide content uses sixty percent of the responsive viewport"
        )
        scene.free()


func test_scene_typography_and_radii_stay_on_the_shared_scale() -> void:
    # The UI had accumulated 23 font sizes and 9 corner radii, with steps like 22-vs-23
    # carrying no meaning. Anything outside these sets is drift, not a decision.
    # 42, 50 and 58 are the numeric-hero tier: the equation, the keypad readout and the
    # milestone fact, which are read as figures rather than as text. The title step is
    # 28 rather than 27 so the milestone fact stays exactly 1.5x it.
    var allowed_font_sizes := [12, 15, 18, 22, 28, 36, 42, 50, 58]
    var allowed_radii := [8, 16, 22, 28]
    for scene_path in _all_scene_paths():
        var file := FileAccess.open(scene_path, FileAccess.READ)
        if file == null:
            continue
        var line_number := 0
        while file.get_position() < file.get_length():
            var line := file.get_line().strip_edges()
            line_number += 1
            var value := line.get_slice(" = ", 1)
            if line.contains("font_sizes/font_size = "):
                check(
                    allowed_font_sizes.has(int(value)),
                    "%s:%d font size %s is off the scale" % [
                        scene_path.get_file(), line_number, value
                    ]
                )
            elif line.begins_with("corner_radius_"):
                check(
                    allowed_radii.has(int(value)),
                    "%s:%d corner radius %s is off the scale" % [
                        scene_path.get_file(), line_number, value
                    ]
                )


func test_theme_publishes_the_font_scale_as_reusable_variations() -> void:
    var theme: Theme = load("res://ui/theme.tres")
    check(theme != null, "Theme must load")
    if theme == null:
        return
    var expected := {"Caption": 12, "Tag": 15, "Body": 18, "Heading": 22, "Title": 28, "Display": 36}
    for variation in expected:
        equal(
            theme.get_type_variation_base(variation),
            &"Label",
            "%s varies Label" % variation
        )
        equal(
            theme.get_font_size("font_size", variation),
            expected[variation],
            "%s font size" % variation
        )
    equal(theme.default_font_size, 18, "Theme default is the body step")


func _all_scene_paths() -> Array[String]:
    var paths: Array[String] = []
    for directory in ["res://scenes/screens", "res://scenes/components", "res://scenes"]:
        var access := DirAccess.open(directory)
        if access == null:
            continue
        access.list_dir_begin()
        var file_name := access.get_next()
        while not file_name.is_empty():
            if not access.current_is_dir() and file_name.ends_with(".tscn"):
                paths.append("%s/%s" % [directory, file_name])
            file_name = access.get_next()
        access.list_dir_end()
    return paths


func test_every_screen_keeps_its_content_off_the_display_edge() -> void:
    # Practice, Reward and Opening used to hardcode their own insets, so they neither
    # centered on wide displays nor knew about a notch or gesture bar.
    var expected_bases := {
        "res://scenes/screens/HomeScreen.tscn": Vector2i(20, 16),
        "res://scenes/screens/MapScreen.tscn": Vector2i(20, 16),
        "res://scenes/screens/CosmeticsScreen.tscn": Vector2i(20, 16),
        "res://scenes/screens/TrophyScreen.tscn": Vector2i(20, 16),
        "res://scenes/screens/SettingsScreen.tscn": Vector2i(20, 16),
        "res://scenes/screens/PracticeScreen.tscn": Vector2i(24, 24),
        "res://scenes/screens/RewardScreen.tscn": Vector2i(34, 28),
        "res://scenes/screens/OpeningScreen.tscn": Vector2i(36, 36),
    }
    for scene_path in expected_bases:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Screen loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        # Opening still calls its container SafeMargin.
        var safe_area := scene.get_node_or_null("SafeArea") as CenteredContentMargin
        if safe_area == null:
            safe_area = scene.get_node_or_null("SafeMargin") as CenteredContentMargin
        check(safe_area != null, "%s manages its own edge insets" % scene_path.get_file())
        if safe_area != null:
            var expected: Vector2i = expected_bases[scene_path]
            equal(safe_area.base_top_margin, expected.x, "%s top base" % scene_path.get_file())
            equal(
                safe_area.base_bottom_margin,
                expected.y,
                "%s bottom base" % scene_path.get_file()
            )
            equal(safe_area.compact_side_margin, 16, "%s side base" % scene_path.get_file())
        _release_audio_streams(scene)
        scene.free()


## Drops stream references before a screen is freed.
##
## These screens are instantiated outside the scene tree, so nothing ever runs the
## teardown that would normally release their audio. Godot then reports the stream as
## still in use at exit, which the test runner treats as a failure.
func _release_audio_streams(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stream = null
    for child in node.get_children():
        _release_audio_streams(child)


func test_scroll_panels_stay_clear_of_the_scrollbar_at_the_narrowest_width() -> void:
    # At 390 wide the side insets leave 358 units, and a vertical scrollbar eats into
    # that. Panels sized to the old 350 readable column overflowed by a few pixels.
    var narrowest_content := 390.0 - 2.0 * 16.0
    for entry in [
        ["res://scenes/screens/MapScreen.tscn", "%MapCanvas"],
        ["res://scenes/screens/CosmeticsScreen.tscn", "SafeArea/Content/CosmeticsPanel"],
        ["res://scenes/screens/SettingsScreen.tscn", "SafeArea/Content/SettingsPanel"],
    ]:
        var packed: PackedScene = load(entry[0])
        check(packed != null, "Screen loads: %s" % entry[0])
        if packed == null:
            continue
        var scene := packed.instantiate()
        var panel: Control = scene.get_node(entry[1])
        check(
            panel.custom_minimum_size.x <= narrowest_content - 16.0,
            "%s leaves room for the scrollbar" % entry[1]
        )
        scene.free()


func test_nav_screens_leave_room_for_the_device_safe_area() -> void:
    # The nav bar is the last child of a VBoxContainer, so it only sits at the bottom while
    # something above it can still shrink. Home was built entirely from fixed minimums and
    # its column already overflowed 844 with no insets at all, which is why its bar landed a
    # pixel off on devices with a cutout while every other screen looked right.
    var design_height := 844.0
    var authored_insets := 20.0 + 16.0
    # Comfortably past a tall cutout plus a gesture bar, in viewport units.
    var inset_budget := 80.0
    for scene_path in [
        "res://scenes/screens/HomeScreen.tscn",
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
    ]:
        var scene := (load(scene_path) as PackedScene).instantiate()
        var tree := Engine.get_main_loop() as SceneTree
        tree.root.add_child(scene)
        # Full-rect anchors fight an assigned size, and the width matters here: PetHint
        # autowraps, so its minimum height depends on how wide the column actually is.
        (scene as Control).set_anchors_preset(Control.PRESET_TOP_LEFT)
        (scene as Control).size = Vector2(390.0, design_height)
        var content: Control = scene.get_node("SafeArea/Content")
        var required := content.get_combined_minimum_size().y + authored_insets
        check(
            required + inset_budget <= design_height,
            "%s absorbs a device safe area (needs %d of %d)" % [
                scene_path.get_file(), int(required), int(design_height)
            ]
        )
        tree.root.remove_child(scene)
        scene.free()


## A Google account switch that cannot work is worse than no switch: a guardian would flip it and
## nothing would happen. So the row hides itself unless a usable plugin is actually present, which
## is never the case on Windows, on the Web, or in this test run without a stand-in.
func test_the_play_games_row_stays_hidden_until_a_plugin_can_serve_it() -> void:
    var scene: SettingsScreen = (
        load("res://scenes/screens/SettingsScreen.tscn") as PackedScene
    ).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)

    var tile: Control = scene.get_node("%CloudItem")
    check(not tile.visible, "No plugin means the row keeps its original two tiles")

    var fake_plugin := Node.new()
    var fake_client := Node.new()
    PlayGames._set_plugin_for_test(fake_plugin, fake_client)
    scene.refresh_play_games()
    check(tile.visible, "A usable plugin reveals the third tile")

    PlayGames._set_plugin_for_test(null)
    scene.refresh_play_games()
    check(not tile.visible, "Losing the plugin hides it again")

    fake_plugin.free()
    fake_client.free()
    tree.root.remove_child(scene)
    scene.free()


func test_the_cloud_tile_is_lit_by_the_setting_and_names_the_session_separately() -> void:
    # The tile follows the switch, like the two beside it -- a light that ignored the tap would
    # not be a switch. Whether Google actually let the device in is carried by the accessible
    # name, which is the only place on this screen that can say it.
    var scene: SettingsScreen = (
        load("res://scenes/screens/SettingsScreen.tscn") as PackedScene
    ).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    # The screen has a debounce timer that saves preferences, and it saves to the real settings
    # file. Bracketing the whole case is the only reliable guard.
    var restore_settings: Variant = preserve_settings_file()

    SettingsManager.play_games_enabled = true
    scene.refresh_from_settings()
    var tile: IconToggle = scene.get_node("%CloudButton")
    check(tile.button_pressed, "Cloud save is on by default")
    equal(tile.icon, tile.icon_on, "On shows the cloud")
    equal(
        tile.tooltip_text,
        tr("SETTINGS_CLOUD_WAITING_ACCESSIBLE"),
        "On but not signed in is a state of its own, not silence"
    )

    SettingsManager.play_games_enabled = false
    scene.refresh_from_settings()
    check(not tile.button_pressed, "A deliberate opt-out darkens the tile")
    equal(tile.icon, tile.icon_off, "Off shows the struck-through cloud")
    equal(tile.tooltip_text, tr("SETTINGS_CLOUD_OFF_ACCESSIBLE"), "And says so")

    SettingsManager.play_games_enabled = true
    scene.refresh_from_settings()
    PlayGames._set_cloud_state(&"conflict_saved_locally")
    equal(
        tile.tooltip_text,
        tr("SETTINGS_CLOUD_ATTENTION_ACCESSIBLE"),
        "A fail-closed conflict is spoken instead of looking healthy forever"
    )
    PlayGames._set_cloud_state(&"signed_out")

    tree.root.remove_child(scene)
    scene.free()
    restore_settings_file(restore_settings)


func test_the_sound_tile_is_lit_when_sound_is_audible() -> void:
    # The tile says "Sound" but the stored setting is a mute, so the two are inverses. Get
    # that backwards and the screen confidently reports the opposite of the truth.
    var scene: SettingsScreen = (
        load("res://scenes/screens/SettingsScreen.tscn") as PackedScene
    ).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    var restore_settings: Variant = preserve_settings_file()

    # Set the autoload fields directly: saving here would write a real settings file.
    SettingsManager.audio_muted = false
    SettingsManager.haptics_enabled = true
    scene.refresh_from_settings()
    var sound: IconToggle = scene.get_node("%MuteButton")
    var haptics: IconToggle = scene.get_node("%HapticsButton")
    check(sound.button_pressed, "Audible sound lights the tile")
    equal(sound.icon, sound.icon_on, "Audible sound shows the on icon")
    check(haptics.button_pressed, "Enabled vibration lights the tile")

    SettingsManager.audio_muted = true
    SettingsManager.haptics_enabled = false
    scene.refresh_from_settings()
    check(not sound.button_pressed, "Muted sound darkens the tile")
    equal(sound.icon, sound.icon_off, "Muted sound shows the off icon")
    equal(haptics.icon, haptics.icon_off, "Disabled vibration shows the off icon")

    tree.root.remove_child(scene)
    scene.free()
    restore_settings_file(restore_settings)


func test_body_panels_sit_outside_their_scroll_container() -> void:
    # A ScrollContainer clips to its own rect, so a panel nested inside one loses the
    # drop shadow that rounds its corners. Trophy always nested Panel -> Scroll and looked
    # right; Cosmetics and Settings nested the other way and looked clipped.
    for entry in [
        ["res://scenes/screens/TrophyScreen.tscn", "SafeArea/Content/AchievementsPanel"],
        ["res://scenes/screens/CosmeticsScreen.tscn", "SafeArea/Content/CosmeticsPanel"],
        ["res://scenes/screens/SettingsScreen.tscn", "SafeArea/Content/SettingsPanel"],
    ]:
        var packed: PackedScene = load(entry[0])
        check(packed != null, "Screen loads: %s" % entry[0])
        if packed == null:
            continue
        var scene := packed.instantiate()
        var panel: PanelContainer = scene.get_node(entry[1])
        var scrolls := _find_scroll_containers(scene)
        for scroll in scrolls:
            check(
                not scroll.is_ancestor_of(panel),
                "%s draws its shadow outside the scroll clip" % entry[1]
            )
        check(
            not scrolls.is_empty() and panel.is_ancestor_of(scrolls[0]),
            "%s wraps its own scroll" % entry[1]
        )
        scene.free()


func test_body_panels_share_one_container_style() -> void:
    # Three drifted copies of this style is how the shadows stopped matching.
    var shared: StyleBox = load("res://ui/styles/container_panel.tres")
    check(shared != null, "Shared container style exists")
    for entry in [
        ["res://scenes/screens/TrophyScreen.tscn", "SafeArea/Content/AchievementsPanel"],
        ["res://scenes/screens/CosmeticsScreen.tscn", "SafeArea/Content/CosmeticsPanel"],
        ["res://scenes/screens/SettingsScreen.tscn", "SafeArea/Content/SettingsPanel"],
    ]:
        var scene := (load(entry[0]) as PackedScene).instantiate()
        var panel: PanelContainer = scene.get_node(entry[1])
        check(
            panel.get_theme_stylebox("panel") == shared,
            "%s uses the shared container style" % entry[1]
        )
        scene.free()


func test_scrollable_screens_can_steal_a_touch_drag_from_their_children() -> void:
    # Every scrollable screen is packed with controls that consume input (map islands,
    # trophy cards, settings sliders, cosmetic swatches). With a zero deadzone the child
    # keeps the gesture and the screen refuses to scroll under a finger on Android.
    var expected_deadzone := int(
        ProjectSettings.get_setting("gui/common/default_scroll_deadzone")
    )
    check(expected_deadzone > 0, "Touch drags must be claimable by ScrollContainers")
    for scene_path in [
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/RewardScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Scrollable scene loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        var scrolls := _find_scroll_containers(scene)
        check(not scrolls.is_empty(), "%s has a ScrollContainer" % scene_path)
        for scroll in scrolls:
            equal(
                scroll.scroll_deadzone,
                expected_deadzone,
                "%s :: %s inherits the touch deadzone" % [scene_path.get_file(), scroll.name]
            )
        scene.free()


func _find_scroll_containers(node: Node) -> Array[ScrollContainer]:
    var found: Array[ScrollContainer] = []
    if node is ScrollContainer:
        found.append(node)
    for child in node.get_children():
        found.append_array(_find_scroll_containers(child))
    return found


func test_map_screen_has_all_stage_navigation_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/MapScreen.tscn")
    check(packed != null, "Map scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("set_stage_states"), "Map accepts presentation state")
    check(scene.has_method("show_table_unlocked"), "Map can celebrate a didactic unlock")
    check(scene.has_signal("return_home_requested"), "Map can return home")
    check(scene.get_node("%Scroll") is ScrollContainer, "Map can reveal the new island")
    check(scene.get_node("%MapCanvas") is MapPath, "Winding trail canvas")
    check(scene.get_node("%MapCenter") is CenterContainer, "Wide map remains centered")
    equal(scene.get_node("%MapCanvas").custom_minimum_size.x, 336.0, "Readable map width")
    check(scene.has_method("show_table_details"), "Unlocked island opens fact mastery")
    check(scene.has_method("close_detail_if_open"), "Back closes fact mastery first")
    check(scene.has_signal("fact_detail_opened"), "Island detail exposes selection feedback")
    check(scene.get_node("%FactDetailOverlay") is Control, "Fact detail overlay")
    check(scene.get_node("%FactGrid") is GridContainer, "Two-column fact grid")
    equal(scene.get_node("%FactGrid").columns, 2, "Ten facts use two compact columns")
    check(scene.get_node("%FactDetailClose").custom_minimum_size.y >= 48.0, "Close touch target")
    equal(
        scene._fact_status_color(&"mastered"),
        scene.FACT_MASTERED_COLOR,
        "Mastered facts use orange-gold"
    )
    equal(
        scene._fact_status_color(&"automated"),
        scene.FACT_AUTOMATED_COLOR,
        "Automated facts use green"
    )
    equal(
        scene.FACT_PRACTICING_COLOR,
        Color(0.58, 0.37, 0.78),
        "Practicing facts use purple"
    )
    check(scene.get_node_or_null("%BackButton") == null, "Map has no top back arrow")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button := _nav_button(scene, button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)

    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    var facts: Array[Dictionary] = []
    for multiplier in LearningRules.MULTIPLIERS:
        facts.append({
            "multiplier": multiplier,
            "mastery": multiplier * 10,
            "status": &"building" if multiplier < 6 else &"practicing",
        })
    var stage_states: Array[Dictionary] = [{
        "table": 2,
        "unlocked": true,
        "current": true,
        "completed": false,
        "progress_points": 360,
        "progress_max": 800,
        "progress_percent": 45,
        "facts": facts,
    }]
    scene.set_stage_states(stage_states)
    var island := scene.get_node("%MapCanvas").get_node("Stage2") as TextureButton
    check(island != null, "Island is a button")
    if island == null:
        scene.free()
        return
    check(island.custom_minimum_size.y >= 48.0, "Island touch target")
    island.pressed.emit()
    check(scene.get_node("%FactDetailOverlay").visible, "Island detail opens")
    equal(scene.get_node("%FactGrid").get_child_count(), 10, "All ten facts are shown")
    var legend_grid: GridContainer = scene.get_node("%LegendGrid")
    equal(legend_grid.get_child_count(), 4, "Legend shows all four mastery bands")
    for legend_item in legend_grid.get_children():
        check(
            legend_item.get_node_or_null("DotHolder/LegendDot") is Panel,
            "Legend uses a drawn color dot instead of a font glyph"
        )
    check(scene.close_detail_if_open(), "Open detail consumes back")
    check(not scene.get_node("%FactDetailOverlay").visible, "Fact detail closes")
    scene.free()


func test_main_scene_bundles_audible_music_and_confirm_sfx() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var music: AudioStreamPlayer = scene.get_node("%MusicPlayer")
    var sfx: AudioStreamPlayer = scene.get_node("%UiSfxPlayer")
    check(not music.autoplay, "Web-safe music waits for a user gesture")
    equal(music.stream.resource_path, "res://audio/music/backround_music.ogg", "Music asset")
    equal(sfx.stream.resource_path, "res://audio/sfx/button.mp3", "Button SFX asset")
    equal(music.bus, "Music", "Music uses its volume bus")
    equal(sfx.bus, "SFX", "UI sounds use their volume bus")
    equal(
        scene.get_node("%AnswerSfxPlayer").stream.resource_path,
        "res://audio/sfx/Menu_Select_00.wav",
        "Answer selection sound"
    )
    equal(
        scene.get_node("%PageSfxPlayer").stream.resource_path,
        "res://audio/sfx/turn_page.wav",
        "Screen transition sound"
    )
    equal(
        scene.get_node("%MilestoneSfxPlayer").stream.resource_path,
        "res://audio/sfx/level_up_chime.mp3",
        "Mastery milestone level-up sound"
    )
    equal(
        scene.get_node("%CoinSfxPlayer").stream.resource_path,
        "res://audio/sfx/coin2.wav",
        "Mastery milestone coin sound"
    )
    check(music.volume_db > -20.0, "Music is not effectively silent")
    scene.free()


func test_the_cheer_picks_a_different_clip_each_time() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var cheer: AudioStreamPlayer = scene.get_node("%CheerSfxPlayer")
    var randomizer := cheer.stream as AudioStreamRandomizer
    check(randomizer != null, "The cheer draws from a pool, not a single clip")
    if randomizer == null:
        scene.free()
        return
    equal(randomizer.streams_count, 4, "All four cheer takes are in the pool")
    equal(
        randomizer.playback_mode,
        AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,
        "The same cheer never lands twice in a row"
    )
    var clips: Array[String] = []
    for index in randomizer.streams_count:
        clips.append(randomizer.get_stream(index).resource_path)
    clips.sort()
    equal(
        clips,
        [
            "res://audio/sfx/cheers_wee_1.mp3",
            "res://audio/sfx/cheers_wee_2.mp3",
            "res://audio/sfx/cheers_yeah.mp3",
            "res://audio/sfx/cheers_yoho.mp3",
        ],
        "Cheer pool contents"
    )
    equal(cheer.bus, "SFX", "The cheer follows the sound-effects volume")
    scene.free()


func test_celebration_sounds_never_start_on_the_same_frame() -> void:
    # A milestone fires four sounds. They are meant to overlap at the tails and read as
    # one celebration, but starting together just sounds like a single noisy blast.
    var main: GDScript = load("res://scripts/ui/Main.gd")
    var offsets: Array[float] = [
        0.0,  # the answer click, played the instant an answer is submitted
        main.MILESTONE_CHIME_DELAY_SECONDS,
        main.MILESTONE_CHEER_DELAY_SECONDS,
        main.MILESTONE_COIN_DELAY_SECONDS,
    ]
    for index in range(1, offsets.size()):
        check(
            offsets[index] - offsets[index - 1] >= 0.1,
            "Milestone sound %d starts clear of the one before it" % index
        )
    check(
        main.CORRECT_SFX_DELAY_SECONDS >= 0.1,
        "An ordinary correct answer does not stack two sounds on one frame"
    )
    var reward: GDScript = load("res://scripts/ui/RewardScreen.gd")
    check(
        reward.PAYOUT_SFX_DELAY_SECONDS >= 0.1,
        "The coin payout starts clear of the experience sound"
    )


func test_main_scene_defers_streamed_music_until_web_audio_is_unlocked() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var music_player: AudioStreamPlayer = scene.get_node("%MusicPlayer")
    var ui_sfx_player: AudioStreamPlayer = scene.get_node("%UiSfxPlayer")
    check(not music_player.autoplay, "Music does not autoplay before a web gesture")
    equal(
        music_player.playback_type,
        AudioServer.PLAYBACK_TYPE_STREAM,
        "Long background music uses streamed web playback"
    )
    equal(
        ui_sfx_player.playback_type,
        AudioServer.PLAYBACK_TYPE_DEFAULT,
        "Short UI feedback keeps the default low-latency web playback"
    )

    var touch_down := InputEventScreenTouch.new()
    touch_down.pressed = true
    var touch_up := InputEventScreenTouch.new()
    touch_up.pressed = false
    check(not scene._is_audio_unlock_event(touch_down), "Touch start does not unlock web audio")
    check(scene._is_audio_unlock_event(touch_up), "Completed tap can unlock web audio")
    scene.free()


func test_main_scene_drops_pointer_highlights_on_touchscreens() -> void:
    # Android emulates a mouse from touch and leaves that pointer parked where the finger
    # lifted, so whatever was tapped keeps drawing its hover face -- and the theme draws focus
    # with the hover box too. On a touchscreen those states have to look like the resting one.
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var shared_theme: Theme = load("res://ui/theme.tres")
    var desktop_hover: StyleBox = scene.theme.get_stylebox("hover", "Button")
    var desktop_focus: StyleBox = scene.theme.get_stylebox("focus", "Button")
    scene._neutralize_pointer_states(false)
    check(
        scene.theme.get_stylebox("hover", "Button") == desktop_hover
        and scene.theme.get_stylebox("focus", "Button") == desktop_focus,
        "A real pointer keeps its hover and focus highlights"
    )

    scene._neutralize_pointer_states(true)
    var normal: StyleBox = scene.theme.get_stylebox("normal", "Button")
    equal(scene.theme.get_stylebox("hover", "Button"), normal, "Touch hover rests like normal")
    equal(scene.theme.get_stylebox("focus", "Button"), normal, "Touch focus rests like normal")
    equal(
        scene.theme.get_stylebox("hover_pressed", "Button"),
        scene.theme.get_stylebox("pressed", "Button"),
        "A held-looking touch button is not also hover-lit"
    )
    check(
        shared_theme.get_stylebox("hover", "Button") == desktop_hover,
        "The touch look is a copy, so the shared theme resource is left alone"
    )
    scene.free()


func test_settings_toggles_keep_their_colour_under_a_parked_touch_pointer() -> void:
    # The lit tile sits in `hover_pressed` for as long as Android's emulated pointer stays on
    # it, which is forever. Letting the theme own that slot painted the tile dark green and it
    # stayed that way after the tap -- the setting looked stuck rather than switched.
    var toggle := IconToggle.new()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(toggle)
    toggle.button_pressed = true
    toggle.refresh()
    var normal := toggle.get_theme_stylebox("normal") as StyleBoxFlat
    check(normal != null, "A lit tile draws its own resting box")
    for state in ["hover", "pressed", "hover_pressed", "focus", "disabled"]:
        var style := toggle.get_theme_stylebox(state) as StyleBoxFlat
        check(
            normal != null and style != null and style.bg_color == normal.bg_color,
            "Lit tile keeps its colour while %s" % state
        )
    tree.root.remove_child(toggle)
    toggle.free()


func test_settings_screen_has_language_audio_mute_and_safe_exit_controls() -> void:
    var packed: PackedScene = load("res://scenes/screens/SettingsScreen.tscn")
    check(packed != null, "Settings scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("refresh_from_settings"), "Settings can refresh persisted state")
    check(scene.has_signal("home_requested"), "Settings footer can return home")
    check(scene.has_signal("exit_requested"), "Settings exposes confirmed exit")
    check(scene.get_node_or_null("%BackButton") == null, "Settings has no top back arrow")
    check(
        scene.get_node_or_null("%EnglishLabel") == null
        and scene.get_node_or_null("%CzechLabel") == null,
        "Language names are tooltips, not printed captions"
    )
    for slider_name in ["MusicSlider", "SfxSlider"]:
        var slider: HSlider = scene.get_node("%%%s" % slider_name)
        check(slider.custom_minimum_size.y >= 48.0, "Audio slider touch target")
        equal(slider.max_value, 100.0, "Audio percent range")
    # Both settings are icon tiles rather than switches: at 390 wide a CheckButton stretched
    # into a full-width green bar that read as another action, with its state in a small knob.
    for toggle_name in ["MuteButton", "HapticsButton"]:
        var toggle: IconToggle = scene.get_node("%%%s" % toggle_name)
        check(toggle.toggle_mode, "%s holds a state" % toggle_name)
        check(toggle.custom_minimum_size.y >= 48.0, "%s touch target" % toggle_name)
        check(toggle.icon_on != null and toggle.icon_off != null, "%s has both faces" % toggle_name)
        check(toggle.icon_on != toggle.icon_off, "%s looks different when off" % toggle_name)
    check(scene.get_node("%SoundCaption") is Label, "Sound tile is captioned")
    check(scene.get_node("%HapticsCaption") is Label, "Vibration tile is captioned")
    check(scene.get_node("%PrivacyButton").custom_minimum_size.y >= 48.0, "Privacy touch target")
    equal(
        SettingsScreen.PRIVACY_POLICY_URL,
        "https://lordlobotom.github.io/Numblop/privacy/",
        "Settings opens the published policy URL"
    )
    check(scene.get_node("%ExitButton").custom_minimum_size.y >= 48.0, "Exit touch target")
    check(scene.get_node("%ExitDialog") is Control, "Custom exit confirmation overlay")
    check(scene.has_method("show_exit_confirmation"), "Settings can open the exit confirmation")
    check(
        scene.has_method("close_exit_confirmation_if_open"),
        "Back can close the exit confirmation first"
    )
    check(scene.get_node("%DialogPanel") is PanelContainer, "Modern rounded dialog panel")
    check(scene.get_node("%DialogButtons") is BoxContainer, "Responsive dialog button layout")
    check(
        scene.get_node("%CancelExitButton").custom_minimum_size.y >= 48.0,
        "Cancel exit touch target"
    )
    check(
        scene.get_node("%ConfirmExitButton").custom_minimum_size.y >= 48.0,
        "Confirm exit touch target"
    )
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    equal(
        scene.get_node("%PrivacyButton").text,
        tr("SETTINGS_PRIVACY"),
        "The privacy policy is reachable in the current language"
    )
    # The flags are generated from LanguageCatalog once the screen enters the tree, so there is
    # nothing to inspect before this point. They are the only label the language row has, so the
    # picture is drawn at 38 px inside a 48 px button: the finger still gets its touch target.
    for language in LanguageCatalog.LANGUAGES:
        var locale := String(language["locale"])
        var language_button: TextureButton = scene.language_button(locale)
        check(language_button != null, "%s has a flag button" % locale)
        if language_button == null:
            continue
        check(language_button.custom_minimum_size.y >= 48.0, "%s touch target" % locale)
        var flag: TextureRect = language_button.get_node("Flag")
        equal(
            flag.texture.resource_path,
            LanguageCatalog.flag_path(locale),
            "%s shows its own flag" % locale
        )
        equal(flag.custom_minimum_size, Vector2(38.0, 38.0), "Flag picture size")
        check(
            flag.custom_minimum_size.y < language_button.custom_minimum_size.y,
            "The flag is smaller than the touch target it sits in"
        )
        check(language_button.get_node("Check") is CheckmarkIcon, "%s drawn checkmark" % locale)
    var version_label: Label = scene.get_node("%VersionLabel")
    var app_version := str(ProjectSettings.get_setting("application/config/version"))
    check(version_label.text.contains(app_version), "Settings shows the configured app version")
    check(
        not scene.get_node("SafeArea/Content/Header").is_ancestor_of(version_label),
        "Version sits in its own card below the settings list"
    )
    check(scene.get_node_or_null("%SubtitleLabel") == null, "Settings header carries only its title")
    scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
    scene.size = Vector2(390.0, 844.0)
    scene._update_exit_dialog_layout()
    check(scene.get_node("%DialogButtons").vertical, "Small dialog stacks its actions")
    check(
        scene.get_node("%DialogPanel").custom_minimum_size.x <= 350.0,
        "Small dialog keeps safe side margins"
    )
    scene.size = Vector2(450.0, 900.0)
    scene._update_exit_dialog_layout()
    check(not scene.get_node("%DialogButtons").vertical, "Wide dialog uses one action row")
    check(not scene.close_exit_confirmation_if_open(), "Closed dialog does not consume Back")
    scene.get_node("%ExitDialog").visible = true
    check(scene.close_exit_confirmation_if_open(), "Open dialog consumes Back")
    check(not scene.get_node("%ExitDialog").visible, "Back hides only the exit dialog")
    equal(
        _nav_button(scene, "SettingsButton").texture_normal.resource_path,
        "res://ui/crests/crest_settings.png",
        "Settings crest"
    )
    equal(
        _nav_button(scene, "HomeButton").texture_normal.resource_path,
        "res://ui/crests/crest_home.png",
        "Home crest"
    )
    scene.free()


func test_cosmetics_screen_has_previewing_shop_purchase_and_navigation_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/CosmeticsScreen.tscn")
    check(packed != null, "Cosmetics scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("refresh_from_state"), "Cosmetics reads app presentation state")
    check(scene.has_method("set_presentation_state"), "Cosmetics supports deterministic previews")
    check(scene.has_method("preview_item"), "Cosmetics previews a tapped item")

    var preview_blob := scene.get_node_or_null("%PreviewBlob") as BlobCharacter
    check(preview_blob != null, "Fixed dock previews the tapped item on Numblop")
    check(
        preview_blob != null and preview_blob.preview_mode,
        "Dock preview is not pettable"
    )
    check(
        preview_blob != null and preview_blob.custom_minimum_size.y <= 160.0,
        "Dock preview stays compact beside the item details"
    )

    var scroll: ScrollContainer = scene.get_node("%Scroll")
    check(scene.get_node("%Dock") is PanelContainer, "Fixed preview dock")
    check(not scroll.is_ancestor_of(scene.get_node("%Dock")), "Dock never scrolls away")
    check(
        not scroll.is_ancestor_of(scene.get_node("%PurchaseButton")),
        "Buy action stays reachable without scrolling"
    )
    check(
        not scroll.is_ancestor_of(scene.get_node("%CoinsLabel")),
        "Coin balance stays pinned in the header"
    )
    check(scene.get_node("%ItemNameLabel") is Label, "Dock names the selected item")
    check(scene.get_node("%PriceLabel") is Label, "Dock prices the selected item")

    for tab_name in ["ColorTab", "HatsTab", "GlassesTab", "NecklacesTab"]:
        var tab: BaseButton = scene.get_node("%%%s" % tab_name)
        check(tab.custom_minimum_size.y >= 48.0, "%s touch target" % tab_name)
        check(tab.toggle_mode, "%s behaves as a category tab" % tab_name)
    check(scene.get_node("%ColorPage").visible, "Body color opens first")
    for hidden_page in ["HatsPage", "GlassesPage", "NecklacesPage"]:
        check(
            not scene.get_node("%%%s" % hidden_page).visible,
            "%s starts hidden behind its tab" % hidden_page
        )

    check(scene.get_node("%ColorGrid") is GridContainer, "Body-color swatch grid")
    # Body and belly are the same kind of choice, so they wrap on the same grid: same
    # column count, same separations, both centered.
    equal(scene.get_node("%ColorGrid").columns, 4, "Body colors wrap like the belly row")
    equal(
        scene.get_node("%ColorGrid").get_theme_constant("h_separation"),
        scene.get_node("%BellyGrid").get_theme_constant("h_separation"),
        "Both color grids space their swatches alike"
    )
    equal(
        scene.get_node("%ColorGrid").size_flags_horizontal,
        scene.get_node("%BellyGrid").size_flags_horizontal,
        "Both color grids align alike"
    )
    check(scene.get_node("%BellyGrid") is GridContainer, "Belly-color swatch grid")
    # Seven 48 px swatches in one row are 348 wide, which is wider than the readable
    # column. A hidden page costs nothing, but while the color page was open that pushed
    # the header, tab bar, dock and footer out past both display edges.
    equal(scene.get_node("%BellyGrid").columns, 4, "Belly shades wrap inside the column")
    check(scene.get_node("%BellyLabel") is Label, "Belly row is labeled")
    check(scene.get_node("%HatsGrid") is GridContainer, "Hat shop grid")
    equal(scene.get_node("%HatsGrid").columns, 3, "Hats use three identifiable cards per row")
    check(scene.get_node("%GlassesGrid") is GridContainer, "Glasses shop grid")
    check(scene.get_node("%NecklacesGrid") is GridContainer, "Necklace shop grid")
    equal(
        scene.get_node("%NecklacesGrid").columns,
        3,
        "Necklaces use three identifiable cards per row"
    )
    for grid_name in [
        "ColorGrid", "BellyGrid", "HatsGrid", "GlassesGrid", "NecklacesGrid", "FootwearGrid"
    ]:
        var grid: GridContainer = scene.get_node("%%%s" % grid_name)
        check(
            grid.size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
            "%s stays centered in wide layouts" % grid_name
        )
    check(scene.get_node("%PurchaseButton").custom_minimum_size.y >= 48.0, "Buy touch target")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button := _nav_button(scene, button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    scene.free()


func test_no_cosmetics_page_pushes_the_screen_past_the_display_edge() -> void:
    # A hidden page contributes no minimum width, so one over-wide row stays invisible
    # until its tab is opened -- and then stretches the header, tab bar, dock and footer
    # off both edges of a 390 px display at once.
    var packed: PackedScene = load("res://scenes/screens/CosmeticsScreen.tscn")
    check(packed != null, "Cosmetics scene must load")
    if packed == null:
        return
    var scene: CosmeticsScreen = packed.instantiate()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    for category in [
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        CosmeticCatalog.CATEGORY_HAT,
        CosmeticCatalog.CATEGORY_GLASSES,
        CosmeticCatalog.CATEGORY_NECKLACE,
        CosmeticCatalog.CATEGORY_FOOTWEAR,
    ]:
        scene._show_category(category)
        check(
            scene.get_combined_minimum_size().x <= 390.0,
            "%s page fits the narrowest display: %s" % [
                category, scene.get_combined_minimum_size().x
            ]
        )
    _release_audio_streams(scene)
    scene_tree.root.remove_child(scene)
    scene.free()


func test_cosmetics_buy_button_prices_items_with_a_number_and_a_coin() -> void:
    # A price is a number and a coin, not a sentence: "Koupit za 250" overflows a
    # 52 px button far sooner than "250" does.
    var packed: PackedScene = load("res://scenes/screens/CosmeticsScreen.tscn")
    check(packed != null, "Cosmetics scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var purchase_button: Button = scene.get_node("%PurchaseButton")
    var buy_content: HBoxContainer = scene.get_node("%BuyContent")
    var buy_price_label: Label = scene.get_node("%BuyPriceLabel")
    var buy_coin_icon: TextureRect = scene.get_node("%BuyCoinIcon")
    check(
        purchase_button.is_ancestor_of(buy_content),
        "Price overlay lives inside the action button"
    )
    check(
        buy_content.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "Price overlay never eats the button press"
    )
    equal(buy_content.alignment, BoxContainer.ALIGNMENT_CENTER, "Price sits centered")
    var order: Array[String] = []
    for child in buy_content.get_children():
        order.append(str(child.name))
    equal(order, ["BuyPriceLabel", "BuyCoinIcon"], "Number reads before the coin")
    equal(
        buy_coin_icon.texture.resource_path,
        "res://ui/crests/crest_coin.png",
        "Buy button uses the shared coin crest"
    )
    check(buy_price_label is Label, "Price is a plain number label")
    scene.free()


func test_cosmetics_catalog_no_longer_ships_sentence_priced_buy_strings() -> void:
    var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
    check(file != null, "Localization catalog must open")
    if file == null:
        return
    var catalog := file.get_as_text()
    check(not catalog.contains("COSMETICS_BUY,"), "Sentence buy string is retired")
    check(not catalog.contains("COSMETICS_NEED_COINS,"), "Sentence afford string is retired")


func test_trophy_screen_lists_achievements_under_the_best_streak() -> void:
    var packed: PackedScene = load("res://scenes/screens/TrophyScreen.tscn")
    check(packed != null, "Trophy scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("refresh_from_state"), "Trophies read persisted achievement state")
    check(scene.has_method("set_presentation_state"), "Trophies support deterministic captures")
    check(scene.get_node("%AchievementList") is VBoxContainer, "Achievement card list")
    check(scene.get_node("%BestLabel") is Label, "Best streak summary")
    check(not scene.has_node("%MilestoneList"), "Milestone history is replaced by achievements")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button := _nav_button(scene, button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    scene.free()


func test_trophy_screen_builds_one_card_per_catalog_achievement() -> void:
    var packed: PackedScene = load("res://scenes/screens/TrophyScreen.tscn")
    check(packed != null, "Trophy scene must load")
    if packed == null:
        return
    var scene: TrophyScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    var entries: Array[Dictionary] = AchievementCatalog.evaluate(LearningProfile.new(), {
        "completed_sessions": 1,
        "best_streak": 12,
    })
    scene.set_presentation_state({"best_streak": 12, "achievements": entries})
    var list: VBoxContainer = scene.get_node("%AchievementList")
    equal(list.get_child_count(), entries.size(), "One card per achievement")
    tree.root.remove_child(scene)
    scene.free()


func test_only_one_treasure_chest_exists_in_the_whole_game() -> void:
    var chest_screens: Array[String] = []
    for scene_path in [
        "res://scenes/screens/HomeScreen.tscn",
        "res://scenes/screens/MapScreen.tscn",
        "res://scenes/screens/CosmeticsScreen.tscn",
        "res://scenes/screens/TrophyScreen.tscn",
        "res://scenes/screens/SettingsScreen.tscn",
        "res://scenes/screens/PracticeScreen.tscn",
        "res://scenes/screens/RewardScreen.tscn",
    ]:
        var packed: PackedScene = load(scene_path)
        check(packed != null, "Scene loads: %s" % scene_path)
        if packed == null:
            continue
        var scene := packed.instantiate()
        if _uses_chest_art(scene):
            chest_screens.append(scene_path)
        scene.free()
    equal(
        chest_screens,
        ["res://scenes/screens/RewardScreen.tscn"],
        "The reward screen owns the only chest"
    )


func _uses_chest_art(node: Node) -> bool:
    for property_name in ["texture", "texture_normal"]:
        var texture: Variant = node.get(property_name)
        if texture is Texture2D and String(texture.resource_path).contains("/chest/"):
            return true
    for child in node.get_children():
        if _uses_chest_art(child):
            return true
    return false


func test_home_nickname_button_and_dialog_have_touch_ready_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/HomeScreen.tscn")
    check(packed != null, "Home scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var nickname_button: Button = scene.get_node("%NameButton")
    check(nickname_button is Button, "Nickname button exists")
    check(nickname_button.custom_minimum_size.y >= 48.0, "Nickname button touch target")
    var dialog: Control = scene.get_node("%NameDialog")
    check(dialog is Control, "Name dialog overlay exists")
    check(not dialog.visible, "Name dialog starts hidden")
    var name_input: LineEdit = scene.get_node("%NameInput")
    check(name_input is LineEdit, "Name input is a virtual-keyboard LineEdit")
    equal(name_input.max_length, 16, "Nickname length matches LocalNickname.MAX_LENGTH")
    check(
        scene.get_node("%NameSaveButton").custom_minimum_size.y >= 48.0,
        "Save touch target"
    )
    check(
        scene.get_node("%NameCancelButton").custom_minimum_size.y >= 48.0,
        "Cancel touch target"
    )
    check(scene.has_method("show_name_dialog"), "Home can open the name dialog")
    check(scene.has_method("close_name_dialog_if_open"), "Android Back can close the dialog")
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(scene)
    check(not scene.close_name_dialog_if_open(), "Closed dialog does not consume Back")
    dialog.visible = true
    check(scene.close_name_dialog_if_open(), "Open dialog consumes Back")
    check(not dialog.visible, "Back hides only the name dialog")
    scene.free()


func test_home_screen_displays_progress_without_calculating_it() -> void:
    var packed: PackedScene = load("res://scenes/screens/HomeScreen.tscn")
    check(packed != null, "Home scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("set_progress_totals"), "Home accepts progression state")
    check(scene.get_node("%CoinsLabel") is Label, "Coin total")
    check(scene.get_node("%XpLabel") is Label, "Experience total")
    check(scene.get_node("%LevelLabel") is Label, "Level total")
    equal(scene.get_node("%CoinsLabel").text, "0", "Initial coins")
    equal(scene.get_node("%XpLabel").text, "0", "Initial experience")
    equal(scene.get_node("%LevelLabel").text, "HOME_LEVEL", "Localized level key")
    scene.free()


func test_blob_home_has_idle_pet_and_heart_reactions() -> void:
    var packed: PackedScene = load("res://scenes/components/BlobCharacter.tscn")
    check(packed != null, "Blob scene must load")
    if packed == null:
        return
    var blob := packed.instantiate()
    check(blob.custom_minimum_size.x >= 48.0, "Blob pet target width")
    check(blob.custom_minimum_size.y >= 48.0, "Blob pet target height")
    check(blob.has_signal("petted"), "Blob pet signal")
    check(blob.has_method("react_to_pet"), "Blob pet reaction")
    check(blob.get_node("%IdleTimer").autostart, "Blob idle timer")
    check(blob.has_node("HeartLayer"), "Heart reaction layer")
    # Petting is now a stroke a child repeats, so one clip on a loop would wear out fast.
    var pet_voice := blob.get_node("%PetVoicePlayer").stream as AudioStreamRandomizer
    check(pet_voice != null, "Petting draws from a pool, not a single clip")
    if pet_voice != null:
        equal(
            pet_voice.playback_mode,
            AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,
            "The same pet sound never lands twice in a row"
        )
        var pet_clips: Array[String] = []
        for index in pet_voice.streams_count:
            pet_clips.append(pet_voice.get_stream(index).resource_path)
        pet_clips.sort()
        equal(
            pet_clips,
            [
                "res://audio/sfx/cheers_wee_1.mp3",
                "res://audio/sfx/cheers_wee_2.mp3",
                "res://audio/sfx/giggle.mp3",
            ],
            "Numblop giggles or cheers when stroked"
        )
    equal(blob.get_node("%PetVoicePlayer").bus, "SFX", "Pet sounds follow the SFX volume")
    equal(
        blob.get_node("%Body").texture.resource_path,
        "res://assets/characters/numblop/body/body.png",
        "Blob body asset"
    )
    check(blob.has_method("set_body_color"), "Blob accepts shader-based body colors")
    check(blob.has_method("set_belly_color"), "Blob accepts shader-based belly colors")
    check(blob.has_method("set_hat"), "Blob accepts 768 px hat overlays")
    check(blob.has_method("set_glasses"), "Blob accepts 768 px glasses overlays")
    check(blob.has_method("set_necklace"), "Blob accepts 768 px necklace overlays")
    equal(blob.get_node("%HatAccessory").anchor_left, -0.25, "Hat canvas x offset")
    equal(blob.get_node("%HatAccessory").anchor_right, 1.25, "Hat canvas width")
    check(
        is_equal_approx(blob.get_node("%HatAccessory").anchor_top, -175.0 / 512.0),
        "Hat canvas uses the tuned 175 px vertical offset"
    )
    check(
        is_equal_approx(blob.get_node("%GlassesAccessory").anchor_top, -175.0 / 512.0),
        "Glasses canvas uses the tuned 175 px vertical offset"
    )
    check(
        is_equal_approx(blob.get_node("%GlassesAccessory").anchor_bottom, 593.0 / 512.0),
        "Glasses canvas keeps its 768 px height"
    )
    check(
        is_equal_approx(blob.get_node("%NecklaceAccessory").anchor_top, -175.0 / 512.0),
        "Necklace shares the tuned accessory offset"
    )
    check(
        is_equal_approx(blob.get_node("%NecklaceAccessory").anchor_bottom, 593.0 / 512.0),
        "Necklace canvas keeps its 768 px height"
    )
    var necklace_material := blob.get_node("%NecklaceAccessory").material as ShaderMaterial
    check(necklace_material != null, "Necklace artifact-clipping material")
    if necklace_material != null:
        equal(
            necklace_material.shader.resource_path,
            "res://ui/shaders/necklace_artifact_clip.gdshader",
            "Necklace source artifacts are clipped"
        )
    check(load("res://ui/shaders/numblop_body_color.gdshader") is Shader, "Body-color shader")
    equal(blob.HEART_TEXTURE.resource_path, "res://assets/vfx/hearh.png", "Heart asset")
    blob.free()


func test_theme_bundles_baloo2_with_czech_glyphs() -> void:
    var theme: Theme = load("res://ui/theme.tres")
    check(theme != null, "Theme must load")
    if theme == null:
        return
    check(theme.default_font != null, "Baloo 2 must be the default font")
    if theme.default_font == null:
        return
    # Every letter the ten shipped languages need beyond plain ASCII. Baloo 2 does not carry
    # them all on its own -- Baloo2WithCzechFallback puts Noto Sans behind it for the rest.
    var required_glyphs := {
        "Czech": "áčďéěíňóřšťúůýž",
        "Slovak": "áäčďéíĺľňóôŕšťúýž",
        "German": "äöüß",
        "Spanish": "áéíñóúü¡¿",
        "Finnish": "äöå",
        "French": "àâçèéêëîïôùûüœ",
        "Norwegian": "æøå",
        "Polish": "ąćęłńóśźż",
        "Swedish": "åäö",
    }
    for language in required_glyphs:
        var glyphs := String(required_glyphs[language])
        for index in glyphs.length():
            var codepoint := glyphs.unicode_at(index)
            check(
                theme.default_font.has_char(codepoint),
                "Font is missing a %s glyph: %s" % [language, char(codepoint)]
            )


func test_opening_screen_uses_wordmark_and_touch_ready_language_choices() -> void:
    var packed: PackedScene = load("res://scenes/screens/OpeningScreen.tscn")
    check(packed != null, "Opening scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    var logo: TextureRect = scene.get_node("%Logo")
    equal(scene.OPENING_LOCALE, "en", "Opening screen language")
    check(logo.texture != null, "Opening screen must show the Numblop wordmark")
    if logo.texture != null:
        equal(
            logo.texture.resource_path,
            "res://ui/branding/numblop_wordmark.png",
            "Opening wordmark path"
        )
    # Ten flags cannot sit in one row at 390 px, so they wrap. Whatever the arrangement, the
    # very first screen a child touches must not offer anything under the touch minimum.
    var buttons: HFlowContainer = scene.get_node("%LanguageButtons")
    equal(
        buttons.get_child_count(),
        LanguageCatalog.LANGUAGES.size(),
        "Every shipped language is offered on first launch"
    )
    for language in LanguageCatalog.LANGUAGES:
        var locale := String(language["locale"])
        var flag_button: TextureButton = scene.language_button(locale)
        check(flag_button != null, "%s has a flag button" % locale)
        if flag_button == null:
            continue
        check(flag_button.custom_minimum_size.y >= 48.0, "%s touch target" % locale)
        var flag: TextureRect = flag_button.get_node("Flag")
        equal(
            flag.texture.resource_path,
            LanguageCatalog.flag_path(locale),
            "%s flag path" % locale
        )
        check(
            flag.custom_minimum_size.y < flag_button.custom_minimum_size.y,
            "The flag is smaller than the touch target it sits in"
        )
        check(flag_button.get_node("Check") is CheckmarkIcon, "%s drawn checkmark" % locale)
        check(flag_button.disabled, "%s waits for the panel to be revealed" % locale)
    # Ten flags read as 5 + 5. They first shipped at a 76 px pitch, which overflowed the column
    # by ten pixels and silently rearranged itself into a lopsided 4 + 4 + 2.
    var flags_per_row := 5
    var separation := float(buttons.get_theme_constant("h_separation"))
    var flag_width: float = (scene.FLAG_SIZE as Vector2).x
    var row_width := float(flags_per_row) * (flag_width + separation) - separation
    var narrowest_column := 390.0 - 2.0 * 16.0
    check(
        row_width <= narrowest_column,
        "Five flags fit one row at the narrowest width (needs %d of %d)" % [
            int(row_width), int(narrowest_column)
        ]
    )
    # Choosing a language is two steps: mark a flag, then confirm. Nothing may commit on the first
    # tap, so Continue stays inert and the name line stays empty until something is picked.
    var continue_button: Button = scene.get_node("%ContinueButton")
    var selected_label: Label = scene.get_node("%SelectedLanguageLabel")
    check(continue_button.disabled, "Continue waits for a language")
    check(continue_button.custom_minimum_size.y >= 48.0, "Continue touch target")
    check(selected_label.text.is_empty(), "No language name before a choice is made")
    var panel: VBoxContainer = scene.get_node("%LanguagePanel")
    equal(
        [
            panel.get_child(1).name,
            panel.get_child(2).name,
            panel.get_child(3).name,
        ],
        [&"LanguageButtons", &"SelectedLanguageLabel", &"ContinueButton"],
        "Panel reads flags, then the chosen name, then Continue"
    )
    # Selecting no longer writes a save file, so the round trip is safe to exercise here.
    scene._on_language_selected("cs")
    check(scene.language_button("cs").get_node("Check").visible, "Chosen flag is marked")
    check(not scene.language_button("de").get_node("Check").visible, "Other flags are unmarked")
    check(not continue_button.disabled, "Continue wakes up once a language is chosen")
    equal(selected_label.text, "Čeština", "The chosen language names itself")
    equal(continue_button.text, "Pokračovat", "Continue speaks the chosen language")
    TranslationServer.set_locale("en")
    tree.root.remove_child(scene)
    scene.free()


func test_every_shipped_language_has_a_flag_and_a_registered_catalog() -> void:
    # A language is only real when all three line up: a row in the catalog, a flag on disk, and
    # a compiled .translation the project actually loads. Missing any one fails silently at
    # runtime -- an untranslated screen shows raw keys like MAP_TITLE.
    var registered := PackedStringArray(
        ProjectSettings.get_setting("internationalization/locale/translations")
    )
    for language in LanguageCatalog.LANGUAGES:
        var locale := String(language["locale"])
        check(
            ResourceLoader.exists(LanguageCatalog.flag_path(locale)),
            "%s flag exists: %s" % [locale, LanguageCatalog.flag_path(locale)]
        )
        check(
            not LanguageCatalog.name_key(locale).is_empty(),
            "%s names itself through the catalog" % locale
        )
        var translation_path := "res://localization/strings.%s.translation" % locale
        check(
            registered.has(translation_path),
            "%s is registered in project.godot" % locale
        )
