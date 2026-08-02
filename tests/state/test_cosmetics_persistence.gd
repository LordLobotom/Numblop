extends NumblopTestCase

const TEST_PATH := "user://numblop_cosmetics_test.json"


func test_body_color_catalog_has_one_free_and_five_paid_colors() -> void:
    var colors := CosmeticCatalog.body_colors()
    equal(colors.size(), 6, "Body-color choices include yellow")
    equal(colors[0]["id"], CosmeticCatalog.DEFAULT_BODY_COLOR_ID, "Default green")
    equal(colors[0]["price"], 0, "Default color is free")
    for index in range(1, colors.size()):
        equal(colors[index]["price"], 100, "Paid body color price")
    equal(colors[5]["id"], "yellow", "Yellow joins the body-color catalog")
    equal(colors[5]["name_key"], "COSMETICS_YELLOW", "Yellow is localized")


func test_belly_color_catalog_has_one_free_cream_and_six_paid_pastels() -> void:
    var belly_colors := CosmeticCatalog.belly_colors()
    equal(belly_colors.size(), 7, "Cream plus six pastel belly shades")
    equal(belly_colors[0]["id"], CosmeticCatalog.DEFAULT_BELLY_COLOR_ID, "Default cream belly")
    equal(belly_colors[0]["price"], 0, "Original belly is free")
    for index in range(1, belly_colors.size()):
        equal(belly_colors[index]["price"], 100, "Paid belly shade price")


func test_belly_color_purchase_equip_and_reload_follow_the_color_contract() -> void:
    _remove_test_file()
    var cosmetics := LocalCosmetics.new()
    equal(cosmetics.selected_belly_color, "cream", "Cream starts selected")
    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink", 99
        ),
        -1,
        "Insufficient coins for a belly shade"
    )
    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink", 100
        ),
        100,
        "Belly shade purchase price"
    )
    equal(cosmetics.selected_belly_color, "pink", "Purchased belly shade equipped")

    equal(
        SaveManager.save_game_state(
            LearningProfile.new(), 5, 9, TEST_PATH, cosmetics.to_dictionary()
        ),
        OK,
        "Belly save"
    )
    var loaded := LocalCosmetics.new(SaveManager.load_cosmetics(TEST_PATH))
    equal(loaded.selected_belly_color, "pink", "Equipped belly shade survives reload")
    check(
        loaded.owns_item(CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink"),
        "Belly ownership survives reload"
    )
    _remove_test_file()


func test_legacy_save_defaults_to_the_cream_belly() -> void:
    var loaded := LocalCosmetics.new({"selected_body_color": "green"})
    equal(loaded.selected_belly_color, "cream", "Legacy profile keeps the original belly")
    check(
        loaded.owns_item(CosmeticCatalog.CATEGORY_BELLY_COLOR, "cream"),
        "Cream belly is always owned"
    )
    check(
        not loaded.owns_item(CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink"),
        "Paid belly shades stay locked in legacy saves"
    )


func test_supplied_accessory_catalog_has_free_empty_slots_and_thirteen_paid_items() -> void:
    var hats := CosmeticCatalog.hats()
    var glasses := CosmeticCatalog.glasses()
    var necklaces := CosmeticCatalog.necklaces()
    equal(hats.size(), 7, "Empty slot plus six hats")
    equal(glasses.size(), 5, "Empty slot plus four glasses")
    equal(necklaces.size(), 4, "Empty slot plus three necklaces")
    equal(hats[0]["price"], 0, "No-hat slot is free")
    equal(glasses[0]["price"], 0, "No-glasses slot is free")
    equal(necklaces[0]["price"], 0, "No-necklace slot is free")
    for item in hats.slice(1) + glasses.slice(1) + necklaces.slice(1):
        equal(item["price"], 100, "Supplied accessory price")
        check(ResourceLoader.exists(String(item["texture_path"])), "Accessory asset exists")
    equal(hats[4]["id"], "hat_duck", "Duck cap joins the hat catalog")
    equal(hats[5]["id"], "hat_dino", "Dino hat joins the hat catalog")
    equal(hats[6]["id"], "hat_pirat", "Pirate hat joins the hat catalog")
    equal(glasses[4]["id"], "glasses_pirat", "Pirate eye patch joins the glasses catalog")
    equal(
        necklaces[2]["display_region"],
        Rect2(227.0, 404.0, 320.0, 136.0),
        "Duck necklace preview ignores stray source pixels"
    )


func test_locked_color_requires_coins_then_unlocks_and_equips() -> void:
    var cosmetics := LocalCosmetics.new()
    equal(cosmetics.selected_body_color, "green", "Green starts selected")
    equal(cosmetics.purchase_and_equip_body_color("blue", 99), -1, "Insufficient coins")
    check(not cosmetics.owns_body_color("blue"), "Failed purchase stays locked")

    equal(cosmetics.purchase_and_equip_body_color("blue", 100), 100, "Blue purchase price")
    check(cosmetics.owns_body_color("blue"), "Purchased color is owned")
    equal(cosmetics.selected_body_color, "blue", "Purchased color is equipped")
    equal(cosmetics.purchase_and_equip_body_color("blue", 0), 0, "Owned color is free to equip")


func test_supplied_hats_glasses_and_necklaces_use_the_same_purchase_contract() -> void:
    var cosmetics := LocalCosmetics.new()
    equal(cosmetics.selected_hat, CosmeticCatalog.DEFAULT_HAT_ID, "No hat by default")
    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_HAT,
            "hat_duck",
            99
        ),
        -1,
        "Locked hat needs enough coins"
    )
    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_HAT,
            "hat_duck",
            100
        ),
        100,
        "Hat price"
    )
    check(cosmetics.owns_item(CosmeticCatalog.CATEGORY_HAT, "hat_duck"), "Duck hat owned")
    equal(cosmetics.selected_hat, "hat_duck", "Purchased duck hat equipped")
    check(
        cosmetics.equip_item(
            CosmeticCatalog.CATEGORY_HAT,
            CosmeticCatalog.DEFAULT_HAT_ID
        ),
        "Free empty slot removes the hat"
    )
    equal(cosmetics.selected_hat, CosmeticCatalog.DEFAULT_HAT_ID, "Hat removed")

    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_GLASSES,
            "glasses_green",
            100
        ),
        100,
        "Glasses price"
    )
    equal(cosmetics.selected_glasses, "glasses_green", "Purchased glasses equipped")

    equal(
        cosmetics.purchase_and_equip_item(
            CosmeticCatalog.CATEGORY_NECKLACE,
            "necklace_duck",
            100
        ),
        100,
        "Necklace price"
    )
    equal(cosmetics.selected_necklace, "necklace_duck", "Purchased necklace equipped")
    check(
        cosmetics.equip_item(
            CosmeticCatalog.CATEGORY_NECKLACE,
            CosmeticCatalog.DEFAULT_NECKLACE_ID
        ),
        "Free empty slot removes the necklace"
    )
    equal(
        cosmetics.selected_necklace,
        CosmeticCatalog.DEFAULT_NECKLACE_ID,
        "Empty necklace slot stays equipped"
    )


func test_cosmetics_round_trip_and_profile_save_preserve_inventory() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    var cosmetics := LocalCosmetics.new()
    cosmetics.purchase_and_equip_body_color("yellow", 100)
    cosmetics.purchase_and_equip_item(
        CosmeticCatalog.CATEGORY_HAT,
        "hat_winter",
        100
    )
    cosmetics.purchase_and_equip_item(
        CosmeticCatalog.CATEGORY_GLASSES,
        "glasses_fashion",
        100
    )
    cosmetics.purchase_and_equip_item(
        CosmeticCatalog.CATEGORY_NECKLACE,
        "necklace_moon",
        100
    )
    equal(
        SaveManager.save_game_state(
            profile,
            25,
            40,
            TEST_PATH,
            cosmetics.to_dictionary()
        ),
        OK,
        "Cosmetic state save"
    )
    var loaded := LocalCosmetics.new(SaveManager.load_cosmetics(TEST_PATH))
    check(loaded.owns_body_color("yellow"), "Purchased yellow survives reload")
    equal(loaded.selected_body_color, "yellow", "Equipped yellow survives reload")
    equal(loaded.selected_hat, "hat_winter", "Equipped hat survives reload")
    equal(loaded.selected_glasses, "glasses_fashion", "Equipped glasses survive reload")
    equal(loaded.selected_necklace, "necklace_moon", "Equipped necklace survives reload")

    profile.set_mastery(2, 4, 25)
    equal(SaveManager.save_profile(profile, TEST_PATH), OK, "Mastery-only save")
    loaded = LocalCosmetics.new(SaveManager.load_cosmetics(TEST_PATH))
    check(loaded.owns_body_color("yellow"), "Per-answer save preserves yellow")
    equal(loaded.selected_body_color, "yellow", "Per-answer save preserves yellow selection")
    equal(loaded.selected_hat, "hat_winter", "Per-answer save preserves hat")
    equal(loaded.selected_glasses, "glasses_fashion", "Per-answer save preserves glasses")
    equal(loaded.selected_necklace, "necklace_moon", "Per-answer save preserves necklace")

    equal(SaveManager.save_game_state(profile, 30, 50, TEST_PATH), OK, "Progress-only save")
    loaded = LocalCosmetics.new(SaveManager.load_cosmetics(TEST_PATH))
    check(loaded.owns_body_color("yellow"), "Progress save preserves yellow")
    equal(loaded.selected_body_color, "yellow", "Progress save preserves yellow selection")
    equal(loaded.selected_hat, "hat_winter", "Progress save preserves hat")
    equal(loaded.selected_glasses, "glasses_fashion", "Progress save preserves glasses")
    equal(loaded.selected_necklace, "necklace_moon", "Progress save preserves necklace")
    _remove_test_file()


func test_legacy_save_receives_safe_default_cosmetics() -> void:
    _remove_test_file()
    var profile := LearningProfile.new()
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(profile.to_dictionary()))
    file = null

    var loaded := LocalCosmetics.new(SaveManager.load_cosmetics(TEST_PATH))
    equal(loaded.unlocked_body_colors, ["green"], "Legacy profile receives free green")
    equal(loaded.selected_body_color, "green", "Legacy profile equips green")
    equal(loaded.selected_hat, CosmeticCatalog.DEFAULT_HAT_ID, "Legacy profile has no hat")
    equal(
        loaded.selected_glasses,
        CosmeticCatalog.DEFAULT_GLASSES_ID,
        "Legacy profile has no glasses"
    )
    equal(
        loaded.selected_necklace,
        CosmeticCatalog.DEFAULT_NECKLACE_ID,
        "Legacy profile has no necklace"
    )
    _remove_test_file()


func _remove_test_file() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
