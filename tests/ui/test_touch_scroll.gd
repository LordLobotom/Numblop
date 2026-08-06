extends NumblopTestCase

## The screens a child scrolls are packed with controls that consume a touch, so these
## exercise the real input pipeline over real frames rather than the component's internals.

const SCROLL_SIZE := Vector2(300.0, 300.0)
const ROW_SIZE := Vector2(280.0, 80.0)
const ROW_COUNT := 12

var _presses := 0


func test_a_drag_that_starts_on_a_button_scrolls_instead_of_pressing_it() -> void:
    var scroll := _build_scroll()
    await _settle()
    check(
        scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,
        "The list is long enough to scroll"
    )

    _presses = 0
    _touch(Vector2(150.0, 200.0), true)
    await _settle()
    for step in 5:
        _drag(Vector2(150.0, 200.0 - float(step + 1) * 20.0))
        await _settle()
    check(scroll.is_gesture_scrolling(), "The drag was taken over from the button")
    check(scroll.scroll_vertical > 0, "The page followed the finger")
    _touch(Vector2(150.0, 100.0), false)
    await _settle()

    equal(_presses, 0, "A drag never fires the control it started on")
    var first_row: Button = scroll.get_node("Column").get_child(0)
    check(not first_row.button_pressed, "The control does not stay held after the drag")
    check(not scroll.is_gesture_scrolling(), "Lifting the finger ends the gesture")
    _free_scroll(scroll)


func test_a_short_tap_still_activates_the_control_under_it() -> void:
    var scroll := _build_scroll()
    await _settle()

    _presses = 0
    # A few pixels of jitter is a tap, not a scroll: a child's finger is never still.
    _click(Vector2(150.0, 40.0), true)
    await _settle()
    _move(Vector2(153.0, 43.0))
    await _settle()
    _click(Vector2(153.0, 43.0), false)
    await _settle()

    equal(_presses, 1, "A tap under the deadzone activates the control")
    equal(scroll.scroll_vertical, 0, "A tap does not move the page")
    _free_scroll(scroll)


func test_a_sideways_drag_on_a_slider_sets_it_instead_of_scrolling() -> void:
    # The takeover treated a volume slider like any other control and canceled its press after
    # 12 px, so the settings sliders could only be tapped at a position, never dragged.
    # Driven with mouse events, because that is what a finger becomes: Godot emulates a mouse
    # from every touch, and `Range` only reads the emulated events, never the raw ones.
    var scroll := _build_scroll_with_slider()
    var slider: HSlider = scroll.get_node("Column").get_child(0)
    await _settle()

    _click(Vector2(40.0, 40.0), true)
    await _settle()
    for step in 5:
        _move(Vector2(40.0 + float(step + 1) * 30.0, 42.0))
        await _settle()

    check(not scroll.is_gesture_scrolling(), "The page never claims a slider's own gesture")
    equal(scroll.scroll_vertical, 0, "Setting the volume does not move the page")
    check(slider.value > 0.0, "The slider followed the finger")
    _click(Vector2(190.0, 42.0), false)
    await _settle()
    _free_scroll(scroll)


func test_an_upward_drag_that_starts_on_a_slider_still_scrolls_the_page() -> void:
    # The sliders are full-width 48 px bands, so refusing every gesture that begins on one
    # would leave a dead stripe the page cannot be scrolled from.
    var scroll := _build_scroll_with_slider()
    await _settle()

    _touch(Vector2(150.0, 40.0), true)
    await _settle()
    for step in 5:
        _drag(Vector2(152.0, 40.0 - float(step + 1) * 20.0))
        await _settle()

    check(scroll.is_gesture_scrolling(), "A vertical drag off a slider is still a scroll")
    check(scroll.scroll_vertical > 0, "The page followed the finger")
    _touch(Vector2(152.0, -60.0), false)
    await _settle()
    _free_scroll(scroll)


func test_every_scrolling_screen_can_be_dragged_from_anywhere() -> void:
    # Each of these is a page of islands, cards or swatches; without the shared container a
    # drag that began on one of them was delivered to that control alone. Sliders are the
    # documented exception -- see the two tests above.
    for entry in [
        ["res://scenes/screens/MapScreen.tscn", "%Scroll"],
        ["res://scenes/screens/TrophyScreen.tscn", "SafeArea/Content/AchievementsPanel/Scroll"],
        ["res://scenes/screens/SettingsScreen.tscn", "SafeArea/Content/SettingsPanel/Scroll"],
        ["res://scenes/screens/CosmeticsScreen.tscn", "%Scroll"],
        ["res://scenes/screens/RewardScreen.tscn", "SafeArea/Content/MasteryPanel/MasteryRows/MasteryScroll"],
    ]:
        var packed: PackedScene = load(entry[0])
        check(packed != null, "Scrollable scene loads: %s" % entry[0])
        if packed == null:
            continue
        var scene := packed.instantiate()
        var scroll := scene.get_node(entry[1]) as ScrollContainer
        check(
            scroll is TouchScrollContainer,
            "%s drags from anywhere" % entry[0].get_file()
        )
        equal(
            scroll.vertical_scroll_mode,
            ScrollContainer.SCROLL_MODE_SHOW_NEVER,
            "%s scrolls without a scrollbar" % entry[0].get_file()
        )
        _release_audio_streams(scene)
        scene.free()


func test_the_takeover_distance_comes_from_the_project_setting() -> void:
    var expected_deadzone := int(
        ProjectSettings.get_setting("gui/common/default_scroll_deadzone")
    )
    check(expected_deadzone > 0, "Touch drags must be claimable")
    var scroll := TouchScrollContainer.new()
    equal(
        scroll.scroll_deadzone,
        expected_deadzone,
        "The container inherits the project-wide takeover distance"
    )
    scroll.free()


func _build_scroll() -> TouchScrollContainer:
    var scroll := TouchScrollContainer.new()
    scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
    scroll.position = Vector2.ZERO
    scroll.size = SCROLL_SIZE
    scroll.custom_minimum_size = SCROLL_SIZE
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
    (Engine.get_main_loop() as SceneTree).root.add_child(scroll)

    var column := VBoxContainer.new()
    column.name = "Column"
    scroll.add_child(column)
    for index in ROW_COUNT:
        var row := Button.new()
        row.custom_minimum_size = ROW_SIZE
        row.pressed.connect(func() -> void: _presses += 1)
        column.add_child(row)
    return scroll


## The same list, but with a full-width slider as its first row.
func _build_scroll_with_slider() -> TouchScrollContainer:
    var scroll := _build_scroll()
    var column: VBoxContainer = scroll.get_node("Column")
    var slider := HSlider.new()
    slider.custom_minimum_size = Vector2(ROW_SIZE.x, 48.0)
    slider.max_value = 100.0
    slider.step = 1.0
    slider.value = 0.0
    column.add_child(slider)
    column.move_child(slider, 0)
    return scroll


func _free_scroll(scroll: TouchScrollContainer) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.remove_child(scroll)
    scroll.free()


func _settle() -> void:
    var tree := Engine.get_main_loop() as SceneTree
    await tree.process_frame
    await tree.process_frame


func _touch(position: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = position
    event.pressed = pressed
    _push(event)


func _drag(position: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = 0
    event.position = position
    _push(event)


func _click(position: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.global_position = position
    event.pressed = pressed
    _push(event)


func _move(position: Vector2) -> void:
    var event := InputEventMouseMotion.new()
    event.position = position
    event.global_position = position
    event.button_mask = MOUSE_BUTTON_MASK_LEFT
    _push(event)


func _push(event: InputEvent) -> void:
    ((Engine.get_main_loop() as SceneTree).root as Viewport).push_input(event, true)


func _release_audio_streams(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stream = null
    for child in node.get_children():
        _release_audio_streams(child)
