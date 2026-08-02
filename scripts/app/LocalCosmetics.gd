class_name LocalCosmetics
extends RefCounted

var unlocked_body_colors: Array[String] = [CosmeticCatalog.DEFAULT_BODY_COLOR_ID]
var selected_body_color := CosmeticCatalog.DEFAULT_BODY_COLOR_ID
var unlocked_belly_colors: Array[String] = [CosmeticCatalog.DEFAULT_BELLY_COLOR_ID]
var selected_belly_color := CosmeticCatalog.DEFAULT_BELLY_COLOR_ID
var unlocked_hats: Array[String] = [CosmeticCatalog.DEFAULT_HAT_ID]
var selected_hat := CosmeticCatalog.DEFAULT_HAT_ID
var unlocked_glasses: Array[String] = [CosmeticCatalog.DEFAULT_GLASSES_ID]
var selected_glasses := CosmeticCatalog.DEFAULT_GLASSES_ID
var unlocked_necklaces: Array[String] = [CosmeticCatalog.DEFAULT_NECKLACE_ID]
var selected_necklace := CosmeticCatalog.DEFAULT_NECKLACE_ID


func _init(data: Dictionary = {}) -> void:
    _load_unlocked_items(
        data.get("unlocked_body_colors", []),
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        unlocked_body_colors
    )
    _load_unlocked_items(
        data.get("unlocked_belly_colors", []),
        CosmeticCatalog.CATEGORY_BELLY_COLOR,
        unlocked_belly_colors
    )
    _load_unlocked_items(
        data.get("unlocked_hats", []),
        CosmeticCatalog.CATEGORY_HAT,
        unlocked_hats
    )
    _load_unlocked_items(
        data.get("unlocked_glasses", []),
        CosmeticCatalog.CATEGORY_GLASSES,
        unlocked_glasses
    )
    _load_unlocked_items(
        data.get("unlocked_necklaces", []),
        CosmeticCatalog.CATEGORY_NECKLACE,
        unlocked_necklaces
    )
    var loaded_selected := String(data.get(
        "selected_body_color",
        CosmeticCatalog.DEFAULT_BODY_COLOR_ID
    ))
    if owns_item(CosmeticCatalog.CATEGORY_BODY_COLOR, loaded_selected):
        selected_body_color = loaded_selected
    loaded_selected = String(data.get(
        "selected_belly_color",
        CosmeticCatalog.DEFAULT_BELLY_COLOR_ID
    ))
    if owns_item(CosmeticCatalog.CATEGORY_BELLY_COLOR, loaded_selected):
        selected_belly_color = loaded_selected
    loaded_selected = String(data.get("selected_hat", CosmeticCatalog.DEFAULT_HAT_ID))
    if owns_item(CosmeticCatalog.CATEGORY_HAT, loaded_selected):
        selected_hat = loaded_selected
    loaded_selected = String(data.get(
        "selected_glasses",
        CosmeticCatalog.DEFAULT_GLASSES_ID
    ))
    if owns_item(CosmeticCatalog.CATEGORY_GLASSES, loaded_selected):
        selected_glasses = loaded_selected
    loaded_selected = String(data.get(
        "selected_necklace",
        CosmeticCatalog.DEFAULT_NECKLACE_ID
    ))
    if owns_item(CosmeticCatalog.CATEGORY_NECKLACE, loaded_selected):
        selected_necklace = loaded_selected


func _load_unlocked_items(
    loaded_unlocked: Variant,
    category: String,
    destination: Array[String]
) -> void:
    if loaded_unlocked is Array:
        for raw_id in loaded_unlocked:
            var item_id := String(raw_id)
            if CosmeticCatalog.has_item(category, item_id) and not destination.has(item_id):
                destination.append(item_id)


func owns_body_color(color_id: String) -> bool:
    return owns_item(CosmeticCatalog.CATEGORY_BODY_COLOR, color_id)


func equip_body_color(color_id: String) -> bool:
    return equip_item(CosmeticCatalog.CATEGORY_BODY_COLOR, color_id)


func purchase_and_equip_body_color(color_id: String, available_coins: int) -> int:
    return purchase_and_equip_item(
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        color_id,
        available_coins
    )


func owns_item(category: String, item_id: String) -> bool:
    match category:
        CosmeticCatalog.CATEGORY_BODY_COLOR:
            return unlocked_body_colors.has(item_id)
        CosmeticCatalog.CATEGORY_BELLY_COLOR:
            return unlocked_belly_colors.has(item_id)
        CosmeticCatalog.CATEGORY_HAT:
            return unlocked_hats.has(item_id)
        CosmeticCatalog.CATEGORY_GLASSES:
            return unlocked_glasses.has(item_id)
        CosmeticCatalog.CATEGORY_NECKLACE:
            return unlocked_necklaces.has(item_id)
    return false


func equip_item(category: String, item_id: String) -> bool:
    if not owns_item(category, item_id):
        return false
    match category:
        CosmeticCatalog.CATEGORY_BODY_COLOR:
            selected_body_color = item_id
        CosmeticCatalog.CATEGORY_BELLY_COLOR:
            selected_belly_color = item_id
        CosmeticCatalog.CATEGORY_HAT:
            selected_hat = item_id
        CosmeticCatalog.CATEGORY_GLASSES:
            selected_glasses = item_id
        CosmeticCatalog.CATEGORY_NECKLACE:
            selected_necklace = item_id
        _:
            return false
    return true


func purchase_and_equip_item(
    category: String,
    item_id: String,
    available_coins: int
) -> int:
    var catalog_item := CosmeticCatalog.item(category, item_id)
    if catalog_item.is_empty():
        return -1
    if owns_item(category, item_id):
        equip_item(category, item_id)
        return 0
    var price := int(catalog_item["price"])
    if available_coins < price:
        return -1
    match category:
        CosmeticCatalog.CATEGORY_BODY_COLOR:
            unlocked_body_colors.append(item_id)
        CosmeticCatalog.CATEGORY_BELLY_COLOR:
            unlocked_belly_colors.append(item_id)
        CosmeticCatalog.CATEGORY_HAT:
            unlocked_hats.append(item_id)
        CosmeticCatalog.CATEGORY_GLASSES:
            unlocked_glasses.append(item_id)
        CosmeticCatalog.CATEGORY_NECKLACE:
            unlocked_necklaces.append(item_id)
        _:
            return -1
    equip_item(category, item_id)
    return price


func to_dictionary() -> Dictionary:
    return {
        "unlocked_body_colors": unlocked_body_colors.duplicate(),
        "selected_body_color": selected_body_color,
        "unlocked_belly_colors": unlocked_belly_colors.duplicate(),
        "selected_belly_color": selected_belly_color,
        "unlocked_hats": unlocked_hats.duplicate(),
        "selected_hat": selected_hat,
        "unlocked_glasses": unlocked_glasses.duplicate(),
        "selected_glasses": selected_glasses,
        "unlocked_necklaces": unlocked_necklaces.duplicate(),
        "selected_necklace": selected_necklace,
    }
