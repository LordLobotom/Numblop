extends Node

const CAPTURE_SIZES: Array[Vector2i] = [
    Vector2i(390, 844),
    Vector2i(450, 900),
    Vector2i(900, 900),
]
const LOCALES: Array[String] = ["en", "cs"]
const SCREENS: Array[String] = [
    "home",
    "home_accessories",
    "home_duck",
    "home_name",
    "cosmetics",
    "cosmetics_color",
    "cosmetics_buy",
    "cosmetics_hat",
    "cosmetics_footwear",
    "trophy",
    "trophy_islands",
    "map",
    "map_detail",
    "map_unlock",
    "settings",
    "settings_exit",
    "choice",
    "milestone",
    "correction",
    "correction_max",
    "keypad",
    "reward",
    "reward_opened",
    "reward_scrolling",
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
    if screen_name in ["choice", "milestone", "keypad", "correction", "correction_max"]:
        scene_path = "res://scenes/screens/PracticeScreen.tscn"
    elif screen_name in ["cosmetics", "cosmetics_color", "cosmetics_buy", "cosmetics_hat", "cosmetics_footwear"]:
        scene_path = "res://scenes/screens/CosmeticsScreen.tscn"
    elif screen_name in ["trophy", "trophy_islands"]:
        scene_path = "res://scenes/screens/TrophyScreen.tscn"
    elif screen_name in ["map", "map_detail", "map_unlock"]:
        scene_path = "res://scenes/screens/MapScreen.tscn"
    elif screen_name in ["settings", "settings_exit"]:
        scene_path = "res://scenes/screens/SettingsScreen.tscn"
    elif screen_name in ["reward", "reward_opened", "reward_scrolling"]:
        scene_path = "res://scenes/screens/RewardScreen.tscn"
    var packed: PackedScene = load(scene_path)
    return packed.instantiate()


func _configure_screen(screen: Control, screen_name: String, locale: String) -> void:
    match screen_name:
        "home", "home_accessories", "home_duck", "home_name":
            var home := screen as HomeScreen
            home.set_progress_totals(120, 240, 3)
            home.set_streak(18)
            home.present_nickname("")
            var home_colors := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_BODY_COLOR,
                CosmeticCatalog.DEFAULT_BODY_COLOR_ID
            )
            home.blob.apply_cosmetics({
                "selected_body_color": CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
                "selected_hat": CosmeticCatalog.DEFAULT_HAT_ID,
                "selected_glasses": CosmeticCatalog.DEFAULT_GLASSES_ID,
                "selected_necklace": CosmeticCatalog.DEFAULT_NECKLACE_ID,
                "selected_footwear": CosmeticCatalog.DEFAULT_FOOTWEAR_ID,
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
            elif screen_name == "home_name":
                home.show_name_dialog()
                home.name_input.text = "Anička"
        "cosmetics", "cosmetics_color", "cosmetics_buy", "cosmetics_hat", "cosmetics_footwear":
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
            var footwear := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_FOOTWEAR,
                CosmeticCatalog.DEFAULT_FOOTWEAR_ID
            )
            var belly_colors := _cosmetic_capture_items(
                CosmeticCatalog.CATEGORY_BELLY_COLOR,
                CosmeticCatalog.DEFAULT_BELLY_COLOR_ID
            )
            cosmetics_screen.set_presentation_state({
                "coins": 240,
                "selected_body_color": selected_id,
                "selected_belly_color": CosmeticCatalog.DEFAULT_BELLY_COLOR_ID,
                "belly_colors": belly_colors,
                "selected_hat": CosmeticCatalog.DEFAULT_HAT_ID,
                "selected_glasses": CosmeticCatalog.DEFAULT_GLASSES_ID,
                "selected_necklace": CosmeticCatalog.DEFAULT_NECKLACE_ID,
                "colors": colors,
                "hats": hats,
                "glasses": glasses,
                "necklaces": necklaces,
                "footwear": footwear,
            })
            if screen_name == "cosmetics_buy":
                cosmetics_screen.preview_body_color("pink")
            elif screen_name == "cosmetics_hat":
                cosmetics_screen.preview_item(CosmeticCatalog.CATEGORY_HAT, "hat_crown")
            elif screen_name == "cosmetics_footwear":
                cosmetics_screen.preview_item(
                    CosmeticCatalog.CATEGORY_FOOTWEAR,
                    "footwear_sneakers"
                )
        "trophy", "trophy_islands":
            var trophy_screen := screen as TrophyScreen
            # The island cards sit below the fold, so they get their own capture.
            trophy_screen.set_presentation_state(
                _trophy_capture_state(screen_name == "trophy_islands")
            )
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
        "settings", "settings_exit":
            SettingsManager.locale_preference = locale
            var settings_screen := screen as SettingsScreen
            settings_screen.refresh_from_settings()
            if screen_name == "settings_exit":
                settings_screen.show_exit_confirmation()
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
        "milestone":
            var practice := screen as PracticeScreen
            var question := PracticeQuestion.new(
                7,
                4,
                LearningRules.QuestionMode.CHOICE_SIX,
                [14, 21, 28, 32, 35, 42]
            )
            practice.show_question(question, 3, LearningRules.SESSION_LENGTH)
            var record := SessionResult.AnswerRecord.new(3, question, 28, 1.0, 79)
            practice._present_answer_feedback(record, {
                "table_value": 7,
                "multiplier": 4,
                "status": &"mastered",
                "mastery": 84,
                "reward_coins": 5,
            })
        "correction", "correction_max":
            var practice := screen as PracticeScreen
            # 7x4 is the typical split-face case; 9x9 is the heaviest layout the solver can hit.
            var table_value := 9 if screen_name == "correction_max" else 7
            var multiplier := 9 if screen_name == "correction_max" else 4
            var question := PracticeQuestion.new(
                table_value,
                multiplier,
                LearningRules.QuestionMode.CHOICE_FOUR,
                [table_value * multiplier, table_value * multiplier + 1]
            )
            practice.show_question(question, 3, LearningRules.SESSION_LENGTH)
            practice._present_answer_feedback(
                SessionResult.AnswerRecord.new(
                    3,
                    question,
                    table_value * multiplier + 1,
                    1.0,
                    30
                )
            )
        "keypad":
            var practice := screen as PracticeScreen
            practice.show_question(
                PracticeQuestion.new(9, 8, LearningRules.QuestionMode.NUMBER_INPUT, []),
                8,
                LearningRules.SESSION_LENGTH
            )
        "reward", "reward_opened", "reward_scrolling":
            var reward_screen := screen as RewardScreen
            var reward := {
                "coins": 20,
                "experience": 20,
                "bonus_coins": 10,
                "achievement_coins": 50,
                "achievements": [
                    AchievementCatalog.definition(AchievementCatalog.island_id(3)),
                ],
                "total_reward_coins": 80,
                "total_coins": 220,
                "total_experience": 260,
                "level": 3,
                "mastery_gains": [
                    {
                        "fact_key": "3_x_7",
                        "table_value": 3,
                        "multiplier": 7,
                        "mastery_before": 45,
                        "mastery_after": 53,
                        "mastery_gained": 8,
                    },
                    {
                        "fact_key": "3_x_4",
                        "table_value": 3,
                        "multiplier": 4,
                        "mastery_before": 62,
                        "mastery_after": 68,
                        "mastery_gained": 6,
                    },
                    {
                        "fact_key": "3_x_9",
                        "table_value": 3,
                        "multiplier": 9,
                        "mastery_before": 80,
                        "mastery_after": 82,
                        "mastery_gained": 2,
                    },
                ],
            }
            if screen_name == "reward_scrolling":
                var many: Array = []
                for multiplier in range(2, 10):
                    many.append({
                        "fact_key": "3_x_%d" % multiplier,
                        "table_value": 3,
                        "multiplier": multiplier,
                        "mastery_before": 40 + multiplier,
                        "mastery_after": 48 + multiplier,
                        "mastery_gained": 8,
                    })
                reward["mastery_gains"] = many
                reward_screen.preview_opened_state(reward)
            elif screen_name == "reward_opened":
                reward_screen.preview_opened_state(reward)
            else:
                reward_screen.start_reward(reward)


## A fixed achievement board so captures never depend on the device's real save.
func _trophy_capture_state(islands_only: bool) -> Dictionary:
    var profile := LearningProfile.new()
    for multiplier in LearningRules.MULTIPLIERS:
        profile.set_mastery(2, multiplier, 100)
        profile.set_mastery(3, multiplier, 100)
        profile.set_mastery(4, multiplier, 74)
    var entries: Array[Dictionary] = []
    for entry in AchievementCatalog.evaluate(profile, {
        "completed_sessions": 24,
        "best_streak": 37,
    }):
        if islands_only and String(entry["kind"]) != AchievementCatalog.KIND_ISLAND:
            continue
        entry["granted"] = bool(entry["completed"])
        entries.append(entry)
    return {
        "best_streak": 37,
        "achievements": entries,
    }


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
