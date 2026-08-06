extends NumblopTestCase


func test_reward_chest_opens_with_one_large_tap() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    check(packed != null, "Reward scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    equal(scene.REQUIRED_TAPS, 1, "Required chest tap")
    check(scene.has_signal("return_home_requested"), "Return-home signal")
    var chest: TextureButton = scene.get_node("%ChestButton")
    check(chest.custom_minimum_size.x >= 48.0, "Chest tap width")
    check(chest.custom_minimum_size.y >= 48.0, "Chest tap height")
    equal(
        chest.texture_normal.resource_path,
        "res://assets/props/chest/closed_treasure.png",
        "Closed chest asset"
    )
    equal(
        scene.get_node("%OpenedChest").texture.resource_path,
        "res://assets/props/chest/opened_treasure.png",
        "Opened chest asset"
    )
    scene.free()


func test_reward_screen_has_count_up_totals_and_returns_automatically() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene := packed.instantiate()
    check(scene.get_node("%CoinsEarned") is Label, "Coin count-up")
    check(scene.get_node("%XpEarned") is Label, "Experience count-up")
    check(scene.get_node("%CoinsTotal") is Label, "Updated coin total")
    check(scene.get_node("%XpTotal") is Label, "Updated experience total")
    check(scene.get_node("%LevelTotal") is Label, "Updated level")
    check(scene.get_node("%BreakdownList") is VBoxContainer, "Reward breakdown lines")
    check(scene.get_node("%TotalRewardLabel") is Label, "Total reward line")
    check(scene.get_node_or_null("%ContinueButton") == null, "No continue button")
    # No hint tells a child to tap, so the hold is the only thing giving them time to read.
    check(scene.AUTO_RETURN_DELAY_SECONDS >= 12.0, "The finished page is held long enough to read")
    check(scene.AUTO_RETURN_DELAY_SECONDS <= 20.0, "Nobody has to wait forever")
    scene.free()


func test_the_finished_page_is_held_and_a_tap_anywhere_skips_the_wait() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    var skip: Button = scene.get_node("%SkipButton")
    check(skip.flat, "The skip surface never covers the page with a visible button")

    scene.start_reward(_reward_with_gains())
    check(not skip.visible, "No skip surface while the chest is still closed")

    scene.preview_opened_state(_reward_with_gains())
    check(skip.visible, "A tap anywhere works once everything is revealed")
    # The prompt used to sit under the summary and pulled children off the page before they
    # had read it. Tapping still works; it is simply no longer advertised.
    check(not scene.get_node("%TapHint").visible, "The finished page carries no continue prompt")
    var returned := [false]
    scene.return_home_requested.connect(func() -> void: returned[0] = true)
    skip.pressed.emit()
    check(returned[0], "Tapping returns home immediately")

    skip.pressed.emit()
    equal(scene.get_node("%SkipButton").visible, false, "A second tap cannot return twice")
    tree.root.remove_child(scene)
    scene.free()


func test_mastery_summary_stays_hidden_until_the_chest_is_open() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)
    var panel: PanelContainer = scene.get_node("%MasteryPanel")

    scene.start_reward(_reward_with_gains())
    check(not panel.visible, "Summary waits for the chest to open")

    scene.preview_opened_state(_reward_with_gains())
    check(panel.visible, "Summary appears once the chest is open")
    var list: VBoxContainer = scene.get_node("%MasteryList")
    equal(list.get_child_count(), 2, "One row per improved fact")
    tree.root.remove_child(scene)
    scene.free()


func test_mastery_rows_leave_a_gutter_for_the_scrollbar() -> void:
    # With enough improved facts the list scrolls, and the "+N" column is right-aligned
    # against the very edge of the scroll area. Godot reserves the bar's width, so the
    # number is not clipped, but it ends up flush against the bar with no daylight.
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    check(packed != null, "Reward scene must load")
    if packed == null:
        return
    var scene := packed.instantiate()
    var gutter: MarginContainer = scene.get_node(
        "SafeArea/Content/MasteryPanel/MasteryRows/MasteryScroll/MasteryListMargin"
    )
    check(
        gutter.get_theme_constant("margin_right") >= 8,
        "Mastery gains clear the scrollbar"
    )
    check(gutter.is_ancestor_of(scene.get_node("%MasteryList")), "Gutter wraps the list")
    scene.free()


func test_mastery_rows_show_a_dot_scale_rather_than_a_numeric_jump() -> void:
    # "45 -> 53" is unreadable to the child the screen is for. The numbers survive as the
    # tooltip so nothing is lost for anyone who wants them.
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)

    scene.preview_opened_state(_reward_with_gains())
    var list: VBoxContainer = scene.get_node("%MasteryList")
    var row: HBoxContainer = list.get_child(0)
    var meters := row.find_children("", "MasteryMeter", true, false)
    equal(meters.size(), 1, "Each improved fact carries one mastery meter")
    equal(
        meters[0].tooltip_text,
        tr("REWARD_MASTERY_CHANGE").format({"before": 45, "after": 53}),
        "The exact scores stay reachable as a tooltip"
    )
    for child in row.get_children():
        if child is Label:
            check(
                not (child as Label).text.contains("->")
                and not (child as Label).text.contains("→"),
                "No row still prints the numeric jump"
            )

    var gain_label: Label = row.get_child(row.get_child_count() - 1)
    equal(gain_label.text, tr("REWARD_MASTERY_GAIN").format({"gained": 8}), "The +N stays")
    tree.root.remove_child(scene)
    scene.free()


func test_the_mastery_meter_fills_its_boundary_dot_proportionally() -> void:
    # Ten dots over a 0-100 score means most gains land inside a single dot. If a dot only
    # ever snapped full or empty, those rounds would look like no progress at all.
    var meter := MasteryMeter.new()
    check(is_equal_approx(meter._fill_of_dot(4, 45.0), 0.5), "45 half-fills the fifth dot")
    check(is_equal_approx(meter._fill_of_dot(4, 53.0), 1.0), "53 fills the fifth dot")
    check(is_equal_approx(meter._fill_of_dot(5, 53.0), 0.3), "53 part-fills the sixth")
    check(is_equal_approx(meter._fill_of_dot(3, 45.0), 1.0), "Everything below is solid")
    check(is_equal_approx(meter._fill_of_dot(9, 53.0), 0.0), "Everything above is empty")

    # A gain wholly inside one dot still moves the waterline.
    check(
        meter._fill_of_dot(8, 84.0) > meter._fill_of_dot(8, 82.0),
        "82 -> 84 still advances the ninth dot"
    )
    meter.free()


func test_a_round_without_mastery_gains_shows_no_summary_panel() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)

    scene.preview_opened_state({"coins": 1, "experience": 1, "mastery_gains": []})
    check(not scene.get_node("%MasteryPanel").visible, "Nothing improved means no panel")
    tree.root.remove_child(scene)
    scene.free()


func test_reward_breakdown_names_every_earning_and_sums_to_the_total() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)

    var reward := _reward_with_gains()
    reward["bonus_coins"] = 10
    reward["achievements"] = [
        AchievementCatalog.definition(AchievementCatalog.island_id(3)),
    ]
    reward["achievement_coins"] = 50
    reward["total_reward_coins"] = 68
    scene.preview_opened_state(reward)

    var list: VBoxContainer = scene.get_node("%BreakdownList")
    equal(list.get_child_count(), 3, "Round reward plus mastery bonus plus one achievement")
    check(scene.get_node("%BreakdownSeparator").visible, "Total is separated from the lines")
    equal(scene.get_node("%CoinsEarned").text, "+68", "Total matches the summed lines")
    tree.root.remove_child(scene)
    scene.free()


func test_a_plain_round_shows_only_the_round_reward_line() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene: RewardScreen = packed.instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(scene)

    scene.preview_opened_state({
        "coins": 9,
        "experience": 9,
        "bonus_coins": 0,
        "achievements": [],
        "achievement_coins": 0,
        "total_reward_coins": 9,
        "total_coins": 9,
        "total_experience": 9,
        "level": 1,
    })
    equal(scene.get_node("%BreakdownList").get_child_count(), 1, "Only the round reward")
    equal(scene.get_node("%CoinsEarned").text, "+9", "Total equals the round reward")
    tree.root.remove_child(scene)
    scene.free()


func _reward_with_gains() -> Dictionary:
    return {
        "coins": 8,
        "experience": 8,
        "total_coins": 108,
        "total_experience": 208,
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
        ],
    }


func test_reward_screen_bundles_celebration_audio() -> void:
    var packed: PackedScene = load("res://scenes/screens/RewardScreen.tscn")
    var scene := packed.instantiate()
    check(scene.get_node("%FanfarePlayer").stream != null, "Chest fanfare")
    check(scene.get_node("%RewardPlayer").stream != null, "Chest open sound")
    check(scene.get_node("%XpPlayer").stream != null, "Count-up sound")
    equal(
        scene.get_node("%FanfarePlayer").stream.resource_path,
        "res://audio/sfx/level_victor_famfare.mp3",
        "Replacement fanfare"
    )
    equal(
        scene.get_node("%RewardPlayer").stream.resource_path,
        "res://audio/sfx/game-bonus.mp3",
        "Chest opening sound"
    )
    equal(
        scene.get_node("%ChestTapPlayer").stream.resource_path,
        "res://audio/sfx/button.mp3",
        "Chest tap sound"
    )
    equal(
        scene.get_node("%CoinPlayer").stream.resource_path,
        "res://audio/sfx/coin2.wav",
        "Coin count sound"
    )
    for player_name in ["FanfarePlayer", "RewardPlayer", "XpPlayer", "ChestTapPlayer", "CoinPlayer"]:
        equal(scene.get_node("%%%s" % player_name).bus, "SFX", "%s bus" % player_name)
    scene.free()
