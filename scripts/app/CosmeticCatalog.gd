class_name CosmeticCatalog
extends RefCounted

const CATEGORY_BODY_COLOR := "body_color"
const CATEGORY_HAT := "hat"
const CATEGORY_GLASSES := "glasses"
const CATEGORY_NECKLACE := "necklace"
const DEFAULT_BODY_COLOR_ID := "green"
const DEFAULT_HAT_ID := "hat_none"
const DEFAULT_GLASSES_ID := "glasses_none"
const DEFAULT_NECKLACE_ID := "necklace_none"
const BODY_COLOR_PRICE := 100
const ACCESSORY_PRICE := 100


static func body_colors() -> Array[Dictionary]:
    return [
        _body_color(DEFAULT_BODY_COLOR_ID, "COSMETICS_GREEN", Color("c8eb3b"), 0),
        _body_color("blue", "COSMETICS_BLUE", Color("45bde9"), BODY_COLOR_PRICE),
        _body_color("pink", "COSMETICS_PINK", Color("f47fb2"), BODY_COLOR_PRICE),
        _body_color("purple", "COSMETICS_PURPLE", Color("9b78e8"), BODY_COLOR_PRICE),
        _body_color("orange", "COSMETICS_ORANGE", Color("f6a83b"), BODY_COLOR_PRICE),
    ]


static func body_color(color_id: String) -> Dictionary:
    for item in body_colors():
        if String(item["id"]) == color_id:
            return item
    return {}


static func has_body_color(color_id: String) -> bool:
    return not body_color(color_id).is_empty()


static func hats() -> Array[Dictionary]:
    return [
        _accessory(DEFAULT_HAT_ID, "COSMETICS_NONE", "", Rect2(), 0),
        _accessory(
            "hat_crown",
            "COSMETICS_HAT_CROWN",
            "res://assets/cosmetics/hats/hat_crown.png",
            Rect2(214.0, 99.0, 348.0, 221.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "hat_santa",
            "COSMETICS_HAT_SANTA",
            "res://assets/cosmetics/hats/hat_santa.png",
            Rect2(227.0, 92.0, 425.0, 259.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "hat_winter",
            "COSMETICS_HAT_WINTER",
            "res://assets/cosmetics/hats/hat_winter.png",
            Rect2(246.0, 63.0, 320.0, 285.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "hat_duck",
            "COSMETICS_HAT_DUCK",
            "res://assets/cosmetics/hats/hat_duck.png",
            Rect2(200.0, 139.0, 353.0, 239.0),
            ACCESSORY_PRICE
        ),
    ]


static func glasses() -> Array[Dictionary]:
    return [
        _accessory(DEFAULT_GLASSES_ID, "COSMETICS_NONE", "", Rect2(), 0),
        _accessory(
            "glasses_fashion",
            "COSMETICS_GLASSES_FASHION",
            "res://assets/cosmetics/glasses/glasses_fashion.png",
            Rect2(197.0, 279.0, 377.0, 166.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "glasses_green",
            "COSMETICS_GLASSES_GREEN",
            "res://assets/cosmetics/glasses/glasses_green.png",
            Rect2(214.0, 301.0, 346.0, 143.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "glasses_moon",
            "COSMETICS_GLASSES_MOON",
            "res://assets/cosmetics/glasses/glasses_moon.png",
            Rect2(202.0, 288.0, 368.0, 148.0),
            ACCESSORY_PRICE
        ),
    ]


static func necklaces() -> Array[Dictionary]:
    return [
        _accessory(DEFAULT_NECKLACE_ID, "COSMETICS_NONE", "", Rect2(), 0),
        _accessory(
            "necklace_crown",
            "COSMETICS_NECKLACE_CROWN",
            "res://assets/cosmetics/necklaces/necklace_crown.png",
            Rect2(233.0, 397.0, 309.0, 130.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "necklace_duck",
            "COSMETICS_NECKLACE_DUCK",
            "res://assets/cosmetics/necklaces/necklace_duck.png",
            Rect2(227.0, 404.0, 320.0, 136.0),
            ACCESSORY_PRICE
        ),
        _accessory(
            "necklace_moon",
            "COSMETICS_NECKLACE_MOON",
            "res://assets/cosmetics/necklaces/necklace_moon.png",
            Rect2(234.0, 396.0, 303.0, 148.0),
            ACCESSORY_PRICE
        ),
    ]


static func items(category: String) -> Array[Dictionary]:
    match category:
        CATEGORY_BODY_COLOR:
            return body_colors()
        CATEGORY_HAT:
            return hats()
        CATEGORY_GLASSES:
            return glasses()
        CATEGORY_NECKLACE:
            return necklaces()
    return []


static func item(category: String, item_id: String) -> Dictionary:
    for catalog_item in items(category):
        if String(catalog_item["id"]) == item_id:
            return catalog_item
    return {}


static func has_item(category: String, item_id: String) -> bool:
    return not item(category, item_id).is_empty()


static func _body_color(
    color_id: String,
    name_key: String,
    color: Color,
    price: int
) -> Dictionary:
    return {
        "id": color_id,
        "name_key": name_key,
        "color": color,
        "price": price,
    }


static func _accessory(
    item_id: String,
    name_key: String,
    texture_path: String,
    display_region: Rect2,
    price: int
) -> Dictionary:
    return {
        "id": item_id,
        "name_key": name_key,
        "texture_path": texture_path,
        "display_region": display_region,
        "price": price,
    }
