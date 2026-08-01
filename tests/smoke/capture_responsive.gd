extends Node

const CAPTURE_SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(450, 900)]
const LOCALES: Array[String] = ["en", "cs"]
const SCREENS: Array[String] = ["home", "map", "settings", "choice", "keypad", "reward"]
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
    elif screen_name == "map":
        scene_path = "res://scenes/screens/MapScreen.tscn"
    elif screen_name == "settings":
        scene_path = "res://scenes/screens/SettingsScreen.tscn"
    elif screen_name == "reward":
        scene_path = "res://scenes/screens/RewardScreen.tscn"
    var packed: PackedScene = load(scene_path)
    return packed.instantiate()


func _configure_screen(screen: Control, screen_name: String, locale: String) -> void:
    match screen_name:
        "home":
            var home := screen as HomeScreen
            home.set_progress_totals(120, 240, 3)
        "map":
            var map_screen := screen as MapScreen
            var stage_states: Array[Dictionary] = []
            for index in LearningRules.TABLES.size():
                stage_states.append({
                    "table": LearningRules.TABLES[index],
                    "unlocked": index <= 2,
                    "current": index == 2,
                    "completed": index < 2,
                    "mastered_facts": 10 if index < 2 else (4 if index == 2 else 0),
                })
            map_screen.set_stage_states(stage_states)
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
