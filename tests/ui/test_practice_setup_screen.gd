extends NumblopTestCase


func test_setup_screen_has_five_lengths_and_smart_review_by_default() -> void:
    var scene := _instance_screen()
    if scene == null:
        return
    scene.present(_setup_state())

    equal(scene.get_node("%QuestionGrid").get_child_count(), 5, "Five length choices")
    for question_count in [10, 20, 30, 40, 50]:
        var card := scene.question_card(question_count)
        check(card != null, "%d-question choice" % question_count)
        check(card.custom_minimum_size.y >= 48.0, "%d-question touch target" % question_count)
    equal(scene.selected_question_count(), 10, "Ten questions by default")
    equal(scene.selected_tables(), [], "No selection means smart review")
    check(not scene.get_node("%StartButton").disabled, "Smart review keeps Start enabled")
    check(scene.get_node("%StartButton").custom_minimum_size.y >= 48.0, "Start touch target")
    check(scene.get_node("%BackButton").custom_minimum_size.y >= 48.0, "Back touch target")
    _free_screen(scene)


func test_setup_uses_the_compact_page_header_and_keeps_start_inside_the_white_panel() -> void:
    var scene := _instance_screen()
    if scene == null:
        return
    var body_panel: PanelContainer = scene.get_node("SafeArea/Content/BodyPanel")
    var start_button: Button = scene.get_node("%StartButton")
    check(body_panel.is_ancestor_of(start_button), "Start belongs to the white body card")

    var practice_header: PanelContainer = scene.get_node("SafeArea/Content/Header")
    var header_content: Control = practice_header.get_node("HeaderContent")
    var shared_header: StyleBox = load("res://ui/styles/header_panel.tres")
    check(
        practice_header.get_theme_stylebox("panel") == shared_header,
        "Practice uses the shared page-header card"
    )
    check(header_content.custom_minimum_size.y <= 32.0, "Practice header row stays compact")
    _free_screen(scene)


func test_setup_reuses_global_navigation_without_claiming_a_primary_tab() -> void:
    var scene := _instance_screen()
    if scene == null:
        return
    var navigation: NavBar = scene.get_node("SafeArea/Content/Navigation")
    equal(navigation.active_item, NavBar.Item.NONE, "Secondary page highlights no primary tab")
    equal(navigation.get_node("NavigationRow").get_child_count(), 5, "Five shared destinations")

    var requested := {"home": false}
    scene.home_requested.connect(func() -> void: requested["home"] = true)
    navigation.get_node("NavigationRow/HomeItem/HomeButton").pressed.emit()
    check(requested["home"], "Global Home navigation is forwarded")
    _free_screen(scene)


func test_only_completed_tables_can_be_selected() -> void:
    var scene := _instance_screen()
    if scene == null:
        return
    scene.present(_setup_state())

    var completed := scene.table_card(2)
    var locked := scene.table_card(3)
    check(not completed.disabled, "Completed table is selectable")
    check(locked.disabled, "Incomplete table is locked")
    check(locked.locked, "Locked card uses the lock treatment")
    completed.pressed.emit()
    equal(scene.selected_tables(), [2], "Eligible table selected")
    check(completed.selected, "Selected table uses a checkmark state")
    completed.pressed.emit()
    equal(scene.selected_tables(), [], "Clearing selection returns to smart review")
    check(not scene.get_node("%StartButton").disabled, "Start remains enabled")
    _free_screen(scene)


func test_table_detail_entry_is_preselected_and_can_mix_other_tables() -> void:
    var state := _setup_state()
    state["tables"][0]["selected"] = true
    state["tables"][1]["practice_eligible"] = true
    var scene := _instance_screen()
    if scene == null:
        return
    scene.present(state)

    equal(scene.selected_tables(), [2], "Origin table is preselected")
    scene.table_card(3).pressed.emit()
    equal(scene.selected_tables(), [2, 3], "Another completed table joins the mix")
    scene.question_card(50).pressed.emit()
    equal(scene.selected_question_count(), 50, "Fifty questions can be selected")
    _free_screen(scene)


func test_home_primary_action_becomes_practice_after_final_completion() -> void:
    var original_profile := AppState.profile
    var profile := LearningProfile.new()
    profile.final_table_completed = true
    AppState.profile = profile
    var packed: PackedScene = load("res://scenes/screens/HomeScreen.tscn")
    var home: HomeScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(home)

    home.refresh_primary_action()
    equal(home.get_node("%PlayLabel").text, tr("HOME_PRACTICE"), "Home action becomes Practice")
    tree.root.remove_child(home)
    home.free()
    AppState.profile = original_profile


func test_completed_map_detail_exposes_practice_entry() -> void:
    var packed: PackedScene = load("res://scenes/screens/MapScreen.tscn")
    var map: MapScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(map)
    var facts: Array[Dictionary] = []
    for multiplier in LearningRules.MULTIPLIERS:
        facts.append({"multiplier": multiplier, "mastery": 80, "status": &"mastered"})
    map.set_stage_states([{
        "table": 2,
        "unlocked": true,
        "current": false,
        "completed": true,
        "progress_percent": 100,
        "facts": facts,
    }])
    map.show_table_details(2)
    var practice_button: Button = map.get_node("%PracticeButton")
    check(practice_button.visible, "Completed detail shows Practice")
    check(practice_button.custom_minimum_size.y >= 48.0, "Detail Practice touch target")

    var requested := {"table": 0}
    map.practice_requested.connect(func(table_value: int) -> void: requested["table"] = table_value)
    practice_button.pressed.emit()
    equal(requested["table"], 2, "Detail forwards its table")
    tree.root.remove_child(map)
    map.free()


func _setup_state() -> Dictionary:
    var tables: Array[Dictionary] = []
    for table_value in LearningRules.TABLES:
        tables.append({
            "table": table_value,
            "practice_eligible": table_value == 2,
            "selected": false,
        })
    return {
        "default_question_count": 10,
        "question_counts": [10, 20, 30, 40, 50],
        "tables": tables,
    }


func _instance_screen() -> PracticeSetupScreen:
    var packed: PackedScene = load("res://scenes/screens/PracticeSetupScreen.tscn")
    check(packed != null, "Practice setup scene loads")
    if packed == null:
        return null
    var scene: PracticeSetupScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    return scene


func _free_screen(scene: PracticeSetupScreen) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.remove_child(scene)
    scene.free()
