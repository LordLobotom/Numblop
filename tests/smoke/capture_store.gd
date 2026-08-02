extends "res://tests/smoke/capture_responsive.gd"

const STORE_SIZE := Vector2i(1080, 1920)
const STORE_SCREENS: Array[String] = [
    "home_accessories",
    "map",
    "choice",
    "keypad",
    "reward",
    "cosmetics",
]
const STORE_OUTPUT_DIRECTORY := "res://store/screenshots"


func _capture_all() -> void:
    for locale in LOCALES:
        var locale_directory := "%s/%s" % [STORE_OUTPUT_DIRECTORY, locale]
        var absolute_output := ProjectSettings.globalize_path(locale_directory)
        if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
            push_error("Could not create store capture directory")
            get_tree().quit(1)
            return
        TranslationServer.set_locale(locale)
        for screen_name in STORE_SCREENS:
            await _capture_store_screen(locale, screen_name)

    if _failed:
        get_tree().quit(1)
        return
    print("NUMBLOP_STORE_CAPTURES_OK")
    get_tree().quit(0)


func _capture_store_screen(locale: String, screen_name: String) -> void:
    var viewport := SubViewport.new()
    viewport.size = STORE_SIZE
    # Mirror the app's canvas_items/expand stretch on a 9:16 phone: the 844-tall
    # design expands sideways to 475 units and upscales to the full 1080x1920.
    viewport.size_2d_override = Vector2i(475, 844)
    viewport.size_2d_override_stretch = true
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
    var output_path := "%s/%s/%s.png" % [STORE_OUTPUT_DIRECTORY, locale, screen_name]
    if image.is_empty() or image.get_size() != STORE_SIZE:
        push_error("Invalid store capture: %s" % output_path)
        _failed = true
    elif image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
        push_error("Could not save store capture: %s" % output_path)
        _failed = true
    else:
        print("CAPTURED %s" % output_path)

    viewport.queue_free()
    await get_tree().process_frame
