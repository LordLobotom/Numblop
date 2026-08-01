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
    check(scene.get_node_or_null("%ContinueButton") == null, "No continue button")
    check(scene.AUTO_RETURN_DELAY_SECONDS >= 1.0, "Reward totals remain readable")
    check(scene.AUTO_RETURN_DELAY_SECONDS <= 3.0, "Automatic return stays prompt")
    scene.free()


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
