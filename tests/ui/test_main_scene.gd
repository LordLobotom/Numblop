extends NumblopTestCase


func test_main_scene_has_touch_ready_portrait_controls() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    var scene := packed.instantiate()
    var home: HomeScreen = scene.get_node("HomeScreen")
    var play_button: TextureButton = home.get_node("%PlayButton")
    check(play_button.custom_minimum_size.y >= 48.0, "Play touch target")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var crest_button: TextureButton = home.get_node("%%%s" % button_name)
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
        var button: TextureButton = scene.get_node("%%%s" % button_name)
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
        safe_area._update_side_margins()
        equal(safe_area.get_theme_constant("margin_left"), 14, "Phone left margin")
        equal(safe_area.get_theme_constant("margin_right"), 14, "Phone right margin")

        safe_area.size = Vector2(900.0, 900.0)
        safe_area._update_side_margins()
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
    equal(scene.get_node("%MapCanvas").custom_minimum_size.x, 350.0, "Readable map width")
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
        var button: BaseButton = scene.get_node("%%%s" % button_name)
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
        "res://audio/sfx/level_up.wav",
        "Mastery milestone level-up sound"
    )
    equal(
        scene.get_node("%CoinSfxPlayer").stream.resource_path,
        "res://audio/sfx/coin2.wav",
        "Mastery milestone coin sound"
    )
    check(music.volume_db > -20.0, "Music is not effectively silent")
    scene.free()


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
    for language_button_name in ["EnglishButton", "CzechButton"]:
        var language_button: TextureButton = scene.get_node("%%%s" % language_button_name)
        check(language_button.custom_minimum_size.y >= 48.0, "Language crest touch target")
    check(scene.get_node("%EnglishCheck") is CheckmarkIcon, "English uses a drawn checkmark")
    check(scene.get_node("%CzechCheck") is CheckmarkIcon, "Czech uses a drawn checkmark")
    for slider_name in ["MusicSlider", "SfxSlider"]:
        var slider: HSlider = scene.get_node("%%%s" % slider_name)
        check(slider.custom_minimum_size.y >= 48.0, "Audio slider touch target")
        equal(slider.max_value, 100.0, "Audio percent range")
    check(scene.get_node("%MuteButton") is CheckButton, "Global mute control")
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
    var version_label: Label = scene.get_node("%VersionLabel")
    var app_version := str(ProjectSettings.get_setting("application/config/version"))
    check(version_label.text.contains(app_version), "Settings shows the configured app version")
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
        scene.get_node("%SettingsButton").texture_normal.resource_path,
        "res://ui/crests/crest_settings.png",
        "Settings crest"
    )
    equal(
        scene.get_node("%HomeButton").texture_normal.resource_path,
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
    equal(scene.get_node("%ColorGrid").columns, 6, "Six colors share one compact row")
    check(scene.get_node("%BellyGrid") is GridContainer, "Belly-color swatch grid")
    equal(scene.get_node("%BellyGrid").columns, 7, "Seven belly shades share one compact row")
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
    for grid_name in ["ColorGrid", "BellyGrid", "HatsGrid", "GlassesGrid", "NecklacesGrid"]:
        var grid: GridContainer = scene.get_node("%%%s" % grid_name)
        check(
            grid.size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
            "%s stays centered in wide layouts" % grid_name
        )
    check(scene.get_node("%PurchaseButton").custom_minimum_size.y >= 48.0, "Buy touch target")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button: BaseButton = scene.get_node("%%%s" % button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    scene.free()


func test_trophy_screen_lists_timestamped_record_milestones() -> void:
    var packed: PackedScene = load("res://scenes/screens/TrophyScreen.tscn")
    check(packed != null, "Trophy scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("refresh_from_state"), "Trophies read persisted streak state")
    check(scene.has_method("set_presentation_state"), "Trophies support deterministic captures")
    check(scene.get_node("%MilestoneList") is VBoxContainer, "Record milestone list")
    check(scene.get_node("%CurrentLabel") is Label, "Current streak summary")
    check(scene.get_node("%BestLabel") is Label, "All-time high summary")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button: BaseButton = scene.get_node("%%%s" % button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    scene.free()


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
    equal(
        blob.get_node("%GigglePlayer").stream.resource_path,
        "res://audio/sfx/giggle.mp3",
        "Numblop giggle"
    )
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
    var czech_glyphs := "áčďéěíňóřšťúůýž"
    for index in czech_glyphs.length():
        var codepoint := czech_glyphs.unicode_at(index)
        check(theme.default_font.has_char(codepoint), "Baloo 2 missing Czech glyph: %s" % codepoint)


func test_opening_screen_uses_wordmark_and_touch_ready_language_choices() -> void:
    var packed: PackedScene = load("res://scenes/screens/OpeningScreen.tscn")
    check(packed != null, "Opening scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var logo: TextureRect = scene.get_node("%Logo")
    var english_button: TextureButton = scene.get_node("%EnglishButton")
    var czech_button: TextureButton = scene.get_node("%CzechButton")
    equal(scene.OPENING_LOCALE, "en", "Opening screen language")
    check(logo.texture != null, "Opening screen must show the Numblop wordmark")
    if logo.texture != null:
        equal(
            logo.texture.resource_path,
            "res://ui/branding/numblop_wordmark.png",
            "Opening wordmark path"
        )
    check(english_button.custom_minimum_size.y >= 48.0, "English touch target")
    check(czech_button.custom_minimum_size.y >= 48.0, "Czech touch target")
    equal(
        english_button.texture_normal.resource_path,
        "res://ui/buttons/button_language_english.png",
        "English flag path"
    )
    equal(
        czech_button.texture_normal.resource_path,
        "res://ui/buttons/button_language_czech.png",
        "Czech flag path"
    )
    scene.free()
