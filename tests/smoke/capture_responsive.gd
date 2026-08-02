extends Node

const CAPTURE_SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(450, 900)]
const LOCALES: Array[String] = ["en", "cs"]
const SCREENS: Array[String] = [
    "home",
    "home_accessories",
    "home_duck",
    "cosmetics",
    "cosmetics_color",
    "cosmetics_buy",
    "trophy",
    "map",
    "map_detail",
    "map_unlock",
    "settings",
    "choice",
    "keypad",
    "reward",
]
const OUTPUT_DIRECTORY := "res://artifacts/responsive"

var _failed := false


func _ready() -> void:
    call_deferred("_capture_all")


func _capture_all() -> void:
    var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
    if directory_error != OK:
        push_error("Could not create responsive capture directory")
        get_tree().quit(1)
        return

    for locale in LOCALES:
        TranslationServer.set_locale(locale)
        for capture_size in CAPTURE_SIZES:
            for screen_name in SCREENS:
                await _capture_screen(locale, capture_size, screen_name)

    if _failed:
        get_tree().quit(1)
        return
    print("NUMBLOP_RESPONSIVE_CAPTURES_OK")
    get_tree().quit(0)


func _capture_screen(locale: String, capture_size: Vector2i, screen_name: String) -> void:
    var viewport := SubViewport.new()
    viewport.size = capture_size
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    get_tree().root.add_child(viewport)

    var screen := _create_screen(screen_name)
    screen.theme = load("res://ui/theme.tres")
    viewport.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    await get_tree().process_frame
    _configure_screen(screen, screen_name, locale)
    await get_tree().process_frame
    await get_tree().process_frame
    if screen_name == "map_unlock":
        await get_tree().create_timer(0.7).timeout
    RenderingServer.force_draw()
    await get_tree().process_frame

    var image := viewport.get_texture().get_image()
    var file_name := "%s_%dx%d_%s.png" % [
        locale,
        capture_size.x,
        capture_size.y,
        screen_name,
    ]
    var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
    if image.is_empty() or image.get_size() != capture_size:
        push_error("Invalid responsive capture: %s" % file_name)
        _failed = true
    elif image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
        push_error("Could not save responsive capture: %s" % file_name)
        _failed = true
    else:
        print("CAPTURED %s" % output_path)

    viewport.queue_free()
    await get_tree().process_frame


func _create_screen(screen_name: String) -> Control:
    var scene_path := "res://scenes/screens/HomeScreen.tscn"
    if screen_name == "choice" or screen_name == "keypad":
        scene_path = "res://scenes/screens/PracticeScreen.tscn"
    elif screen_name in ["cosmetics", "cosmetics_color", "cosmetics_buy"]:
        scene_path = "res://scenes/screens/CosmeticsScreen.tscn"
    elif screen_name == "trophy":
        scene_path = "res://scenes/screens/TrophyScreen.tscn"
    elif screen_name in ["map", "map_detail", "map_unlock"]:
        scene_path = "res://scenes/screens/MapScreen.tscn"
    elif screen_name == "settings":
        scene_path = "res://scenes/screens/SettingsScreen.tscn"
    elif screen_name == "reward":
        scene_path = "res://scenes/screens/RewardScreen.tscn"
    var packed: PackedScene = load(scene_path)
    return packed.instantiate()


func _configure_screen(screen: Control, screen_name: String, locale: String) -> void:
    match screen_name:
        "home", "home_accessories", "home_duck":
            var home := screen as HomeScreen
            home.set_progress_totals(120, 240, 3)
            home.set_streak(18)
            var home_colors := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_BODY_COLOR,
                CosmeticCatalog.DEFAULT_BODY_COLOR_ID
            )
            home.blob.apply_cosmetics({
                "selected_body_color": CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
                "selected_hat": CosmeticCatalog.DEFAULT_HAT_ID,
                "selected_glasses": CosmeticCatalog.DEFAULT_GLASSES_ID,
                "selected_necklace": CosmeticCatalog.DEFAULT_NECKLACE_ID,
                "colors": home_colors,
            })
            if screen_name == "home_accessories":
                home.blob.apply_cosmetics({
                    "selected_body_color": CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
                    "selected_hat": "hat_crown",
                    "selected_glasses": "glasses_green",
                    "selected_necklace": CosmeticCatalog.DEFAULT_NECKLACE_ID,
                    "colors": home_colors,
                })
            elif screen_name == "home_duck":
                home.blob.apply_cosmetics({
                    "selected_body_color": CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
                    "selected_hat": "hat_duck",
                    "selected_glasses": CosmeticCatalog.DEFAULT_GLASSES_ID,
                    "selected_necklace": "necklace_duck",
                    "colors": home_colors,
                })
        "cosmetics", "cosmetics_color", "cosmetics_buy":
            var cosmetics_screen := screen as CosmeticsScreen
            var selected_id := (
                "blue" if screen_name == "cosmetics_color" else "green"
            )
            var colors: Array[Dictionary] = []
            for catalog_item in CosmeticCatalog.body_colors():
                var item := catalog_item.duplicate(true)
                var color_id := String(item["id"])
                item["owned"] = color_id == "green" or color_id == selected_id
                item["selected"] = color_id == selected_id
                colors.append(item)
            var hats := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_HAT,
                CosmeticCatalog.DEFAULT_HAT_ID
            )
            var glasses := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_GLASSES,
                CosmeticCatalog.DEFAULT_GLASSES_ID
            )
            var necklaces := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_NECKLACE,
                CosmeticCatalog.DEFAULT_NECKLACE_ID
            )
            cosmetics_screen.set_presentation_state({
                "coins": 240,
                "selected_body_color": selected_id,
                "selected_hat": CosmeticCatalog.DEFAULT_HAT_ID,
                "selected_glasses": CosmeticCatalog.DEFAULT_GLASSES_ID,
                "selected_necklace": CosmeticCatalog.DEFAULT_NECKLACE_ID,
                "colors": colors,
                "hats": hats,
                "glasses": glasses,
                "necklaces": necklaces,
            })
            if screen_name == "cosmetics_buy":
                cosmetics_screen.preview_body_color("pink")
        "trophy":
            var trophy_screen := screen as TrophyScreen
            trophy_screen.set_presentation_state({
                "current_count": 18,
                "all_time_high": 37,
                "milestones": [
                    {"count": 8, "ended_at_unix": 1785592800, "utc_offset_minutes": 120},
                    {"count": 21, "ended_at_unix": 1785679200, "utc_offset_minutes": 120},
                    {"count": 37, "ended_at_unix": 1785765600, "utc_offset_minutes": 120},
                ],
            })
        "map", "map_detail", "map_unlock":
            var map_screen := screen as MapScreen
            var stage_states: Array[Dictionary] = []
            var progress_max := LearningRules.UNLOCK_MASTERY * LearningRules.MULTIPLIERS.size()
            for index in LearningRules.TABLES.size():
                var facts := _map_capture_facts(index)
                var progress_points := 0
                var mastered_facts := 0
                for fact in facts:
                    progress_points += mini(int(fact["mastery"]), LearningRules.UNLOCK_MASTERY)
                    if int(fact["mastery"]) >= LearningRules.UNLOCK_MASTERY:
                        mastered_facts += 1
                stage_states.append({
                    "table": LearningRules.TABLES[index],
                    "unlocked": index <= 2,
                    "current": index == 2,
                    "completed": index < 2,
                    "mastered_facts": mastered_facts,
                    "progress_points": progress_max if index < 2 else progress_points,
                    "progress_max": progress_max,
                    "progress_percent": (
                        100 if index < 2
                        else int(round(100.0 * progress_points / progress_max))
                    ),
                    "facts": facts,
                })
            if screen_name == "map_unlock":
                map_screen.show_table_unlocked(4)
            map_screen.set_stage_states(stage_states)
            if screen_name == "map_detail":
                map_screen.show_table_details(4)
        "settings":
            SettingsManager.locale_preference = locale
            var settings_screen := screen as SettingsScreen
            settings_screen.refresh_from_settings()
        "choice":
            var practice := screen as PracticeScreen
            practice.show_question(
                PracticeQuestion.new(
                    7,
                    4,
                    LearningRules.QuestionMode.CHOICE_SIX,
                    [14, 21, 28, 32, 35, 42]
                ),
                3,
                LearningRules.SESSION_LENGTH
            )
        "keypad":
            var practice := screen as PracticeScreen
            practice.show_question(
                PracticeQuestion.new(9, 8, LearningRules.QuestionMode.NUMBER_INPUT, []),
                8,
                LearningRules.SESSION_LENGTH
            )
        "reward":
            var reward_screen := screen as RewardScreen
            reward_screen.start_reward({
                "coins": 10,
                "experience": 10,
                "total_coins": 130,
                "total_experience": 250,
                "level": 3,
            })


func _cosmetic_capture_items(category: String, selected_id: String) -> Array[Dictionary]:
    var items: Array[Dictionary] = []
    for catalog_item in CosmeticCatalog.items(category):
        var item := catalog_item.duplicate(true)
        var item_id := String(item["id"])
        item["owned"] = item_id == selected_id
        item["selected"] = item_id == selected_id
        items.append(item)
    return items


func _map_capture_facts(stage_index: int) -> Array[Dictionary]:
    var values: Array[int] = []
    if stage_index < 2:
        values = [90, 92, 95, 100, 88, 94, 91, 86, 97, 90]
    elif stage_index == 2:
        values = [12, 30, 59, 60, 68, 79, 80, 84, 90, 100]
    else:
        values = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var facts: Array[Dictionary] = []
    for multiplier in LearningRules.MULTIPLIERS:
        var mastery := values[multiplier]
        var status := &"building"
        if mastery >= LearningRules.AUTOMATED_MASTERY:
            status = &"automated"
        elif mastery >= LearningRules.UNLOCK_MASTERY:
            status = &"mastered"
        elif LearningRules.mode_for_mastery(mastery) == LearningRules.QuestionMode.CHOICE_SIX:
            status = &"practicing"
        facts.append({
            "multiplier": multiplier,
            "mastery": mastery,
            "status": status,
        })
    return facts
