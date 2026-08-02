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
        "res://ui/fonts/FredokaBold.tres",
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
    check(scene.get_node_or_null("%BackButton") == null, "Map has no top back arrow")
    for button_name in ["OutfitButton", "MapButton", "HomeButton", "TrophyButton", "SettingsButton"]:
        var button: BaseButton = scene.get_node("%%%s" % button_name)
        check(button.custom_minimum_size.y >= 48.0, "%s touch target" % button_name)
    scene.free()


func test_main_scene_bundles_audible_music_and_confirm_sfx() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var music: AudioStreamPlayer = scene.get_node("%MusicPlayer")
    var sfx: AudioStreamPlayer = scene.get_node("%UiSfxPlayer")
    check(music.autoplay, "Background music starts automatically")
    equal(music.stream.resource_path, "res://audio/music/backround_music.wav", "Music asset")
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
    check(music.volume_db > -20.0, "Music is not effectively silent")
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
    for slider_name in ["MusicSlider", "SfxSlider"]:
        var slider: HSlider = scene.get_node("%%%s" % slider_name)
        check(slider.custom_minimum_size.y >= 48.0, "Audio slider touch target")
        equal(slider.max_value, 100.0, "Audio percent range")
    check(scene.get_node("%MuteButton") is CheckButton, "Global mute control")
    check(scene.get_node("%ExitButton").custom_minimum_size.y >= 48.0, "Exit touch target")
    check(scene.get_node("%ExitDialog") is ConfirmationDialog, "Exit confirmation")
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


func test_cosmetics_screen_has_compact_shop_purchase_and_navigation_contracts() -> void:
    var packed: PackedScene = load("res://scenes/screens/CosmeticsScreen.tscn")
    check(packed != null, "Cosmetics scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    check(scene.has_method("refresh_from_state"), "Cosmetics reads app presentation state")
    check(scene.has_method("set_presentation_state"), "Cosmetics supports deterministic previews")
    check(scene.get_node_or_null("%PreviewBlob") == null, "No oversized character preview")
    check(scene.get_node("%ColorGrid") is GridContainer, "Body-color swatch grid")
    equal(scene.get_node("%ColorGrid").columns, 5, "Five colors share one row")
    check(scene.get_node("%HatsGrid") is GridContainer, "Hat shop grid")
    check(scene.get_node("%GlassesGrid") is GridContainer, "Glasses shop grid")
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
    check(blob.has_method("set_hat"), "Blob accepts 768 px hat overlays")
    check(blob.has_method("set_glasses"), "Blob accepts 768 px glasses overlays")
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
    check(load("res://ui/shaders/numblop_body_color.gdshader") is Shader, "Body-color shader")
    equal(blob.HEART_TEXTURE.resource_path, "res://assets/vfx/hearh.png", "Heart asset")
    blob.free()


func test_theme_bundles_fredoka_with_czech_glyphs() -> void:
    var theme: Theme = load("res://ui/theme.tres")
    check(theme != null, "Theme must load")
    if theme == null:
        return
    check(theme.default_font != null, "Fredoka must be the default font")
    if theme.default_font == null:
        return
    var czech_glyphs := "áčďéěíňóřšťúůýž"
    for index in czech_glyphs.length():
        var codepoint := czech_glyphs.unicode_at(index)
        check(theme.default_font.has_char(codepoint), "Fredoka missing Czech glyph: %s" % codepoint)


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
