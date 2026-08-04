class_name CosmeticsScreen
extends Control

signal home_requested
signal map_requested
signal trophy_requested
signal settings_requested

const COIN_TEXTURE: Texture2D = preload("res://ui/crests/crest_coin.png")
const ACCESSORY_CARD_SIZE := 96.0
# Price shown on the action button; matches the button's own font_disabled_color so a
# price the player cannot afford reads as dimmed rather than as a separate message.
const CAN_AFFORD_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CANNOT_AFFORD_COLOR := Color(0.94, 0.94, 0.92, 1.0)

const CATEGORY_STATE_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "colors",
    CosmeticCatalog.CATEGORY_BELLY_COLOR: "belly_colors",
    CosmeticCatalog.CATEGORY_HAT: "hats",
    CosmeticCatalog.CATEGORY_GLASSES: "glasses",
    CosmeticCatalog.CATEGORY_NECKLACE: "necklaces",
    CosmeticCatalog.CATEGORY_FOOTWEAR: "footwear",
}
const CATEGORY_SELECTED_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "selected_body_color",
    CosmeticCatalog.CATEGORY_BELLY_COLOR: "selected_belly_color",
    CosmeticCatalog.CATEGORY_HAT: "selected_hat",
    CosmeticCatalog.CATEGORY_GLASSES: "selected_glasses",
    CosmeticCatalog.CATEGORY_NECKLACE: "selected_necklace",
    CosmeticCatalog.CATEGORY_FOOTWEAR: "selected_footwear",
}
const CATEGORY_DEFAULT_IDS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
    CosmeticCatalog.CATEGORY_BELLY_COLOR: CosmeticCatalog.DEFAULT_BELLY_COLOR_ID,
    CosmeticCatalog.CATEGORY_HAT: CosmeticCatalog.DEFAULT_HAT_ID,
    CosmeticCatalog.CATEGORY_GLASSES: CosmeticCatalog.DEFAULT_GLASSES_ID,
    CosmeticCatalog.CATEGORY_NECKLACE: CosmeticCatalog.DEFAULT_NECKLACE_ID,
    CosmeticCatalog.CATEGORY_FOOTWEAR: CosmeticCatalog.DEFAULT_FOOTWEAR_ID,
}
## The item whose artwork stands in for each category on its tab.
const TAB_ICON_ITEM_IDS := {
    CosmeticCatalog.CATEGORY_HAT: "hat_pirat",
    CosmeticCatalog.CATEGORY_GLASSES: "glasses_star",
    CosmeticCatalog.CATEGORY_NECKLACE: "necklace_crown",
    CosmeticCatalog.CATEGORY_FOOTWEAR: "footwear_sneakers",
}
const CATEGORY_TAB_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "COSMETICS_TAB_COLOR",
    CosmeticCatalog.CATEGORY_HAT: "COSMETICS_TAB_HATS",
    CosmeticCatalog.CATEGORY_GLASSES: "COSMETICS_TAB_GLASSES",
    CosmeticCatalog.CATEGORY_NECKLACE: "COSMETICS_TAB_NECKLACES",
    CosmeticCatalog.CATEGORY_FOOTWEAR: "COSMETICS_TAB_FOOTWEAR",
}

@onready var title_label: Label = %TitleLabel
@onready var coins_label: Label = %CoinsLabel
@onready var color_tab: Button = %ColorTab
@onready var hats_tab: Button = %HatsTab
@onready var glasses_tab: Button = %GlassesTab
@onready var necklaces_tab: Button = %NecklacesTab
@onready var footwear_tab: Button = %FootwearTab
@onready var scroll: ScrollContainer = %Scroll
@onready var color_page: Control = %ColorPage
@onready var hats_page: Control = %HatsPage
@onready var glasses_page: Control = %GlassesPage
@onready var necklaces_page: Control = %NecklacesPage
@onready var footwear_page: Control = %FootwearPage
@onready var color_grid: GridContainer = %ColorGrid
@onready var belly_grid: GridContainer = %BellyGrid
@onready var body_color_label: Label = %BodyColorLabel
@onready var belly_label: Label = %BellyLabel
@onready var hats_grid: GridContainer = %HatsGrid
@onready var glasses_grid: GridContainer = %GlassesGrid
@onready var necklaces_grid: GridContainer = %NecklacesGrid
@onready var footwear_grid: GridContainer = %FootwearGrid
@onready var preview_blob: BlobCharacter = %PreviewBlob
@onready var item_name_label: Label = %ItemNameLabel
@onready var price_row: HBoxContainer = %PriceRow
@onready var price_label: Label = %PriceLabel
@onready var price_coin_icon: TextureRect = %PriceCoinIcon
@onready var purchase_button: Button = %PurchaseButton
@onready var buy_content: HBoxContainer = %BuyContent
@onready var buy_price_label: Label = %BuyPriceLabel
@onready var buy_coin_icon: TextureRect = %BuyCoinIcon
@onready var status_label: Label = %StatusLabel
@onready var selection_player: AudioStreamPlayer = %SelectionPlayer
@onready var purchase_player: AudioStreamPlayer = %PurchasePlayer
@onready var navigation: NavBar = $SafeArea/Content/Navigation

var _state: Dictionary = {}
var _active_category := CosmeticCatalog.CATEGORY_BODY_COLOR
var _selected_category := CosmeticCatalog.CATEGORY_BODY_COLOR
var _selected_item_id := CosmeticCatalog.DEFAULT_BODY_COLOR_ID
var _tab_buttons: Dictionary = {}
var _page_nodes: Dictionary = {}
var _grids: Dictionary = {}
var _cards: Dictionary = {}


func _ready() -> void:
    _tab_buttons = {
        CosmeticCatalog.CATEGORY_BODY_COLOR: color_tab,
        CosmeticCatalog.CATEGORY_HAT: hats_tab,
        CosmeticCatalog.CATEGORY_GLASSES: glasses_tab,
        CosmeticCatalog.CATEGORY_NECKLACE: necklaces_tab,
        CosmeticCatalog.CATEGORY_FOOTWEAR: footwear_tab,
    }
    _page_nodes = {
        CosmeticCatalog.CATEGORY_BODY_COLOR: color_page,
        CosmeticCatalog.CATEGORY_HAT: hats_page,
        CosmeticCatalog.CATEGORY_GLASSES: glasses_page,
        CosmeticCatalog.CATEGORY_NECKLACE: necklaces_page,
        CosmeticCatalog.CATEGORY_FOOTWEAR: footwear_page,
    }
    _grids = {
        CosmeticCatalog.CATEGORY_BODY_COLOR: color_grid,
        CosmeticCatalog.CATEGORY_HAT: hats_grid,
        CosmeticCatalog.CATEGORY_GLASSES: glasses_grid,
        CosmeticCatalog.CATEGORY_NECKLACE: necklaces_grid,
        CosmeticCatalog.CATEGORY_FOOTWEAR: footwear_grid,
    }
    var tab_group := ButtonGroup.new()
    for category in _tab_buttons:
        var tab: Button = _tab_buttons[category]
        tab.button_group = tab_group
        tab.pressed.connect(_on_tab_pressed.bind(category))
    price_coin_icon.texture = COIN_TEXTURE
    _apply_tab_icons()
    preview_blob.set_preview_mode(true)
    navigation.map_requested.connect(_request_screen.bind(map_requested))
    navigation.home_requested.connect(_request_screen.bind(home_requested))
    navigation.trophy_requested.connect(_request_screen.bind(trophy_requested))
    navigation.settings_requested.connect(_request_screen.bind(settings_requested))
    purchase_button.pressed.connect(_on_action_pressed)
    refresh_from_state()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _rebuild_catalog()
        _refresh_dock()


func refresh_from_state() -> void:
    set_presentation_state(AppState.cosmetics_state())


func set_presentation_state(state: Dictionary) -> void:
    _state = state.duplicate(true)
    _restore_selection()
    if not is_node_ready():
        return
    _refresh_text()
    _rebuild_catalog()
    _show_category(_active_category)
    _refresh_dock()


func show_future_feature() -> void:
    _show_status(tr("HOME_FEATURE_LATER"))


func preview_body_color(color_id: String) -> void:
    preview_item(CosmeticCatalog.CATEGORY_BODY_COLOR, color_id)


func preview_item(category: String, item_id: String) -> void:
    if _state_item(category, item_id).is_empty():
        return
    _selected_category = category
    _selected_item_id = item_id
    if _active_category != category:
        _show_category(category)
    _refresh_dock()


func _restore_selection() -> void:
    if not CATEGORY_STATE_KEYS.has(_active_category):
        _active_category = CosmeticCatalog.CATEGORY_BODY_COLOR
    if not _state_item(_selected_category, _selected_item_id).is_empty():
        return
    _selected_category = _active_category
    _selected_item_id = _equipped_id(_active_category)


func _equipped_id(category: String) -> String:
    return String(_state.get(
        CATEGORY_SELECTED_KEYS[category],
        CATEGORY_DEFAULT_IDS[category]
    ))


func _show_category(category: String) -> void:
    if category == CosmeticCatalog.CATEGORY_BELLY_COLOR:
        category = CosmeticCatalog.CATEGORY_BODY_COLOR
    _active_category = category
    for page_category in _page_nodes:
        var page: Control = _page_nodes[page_category]
        page.visible = page_category == category
    for tab_category in _tab_buttons:
        var tab: Button = _tab_buttons[tab_category]
        tab.set_pressed_no_signal(tab_category == category)
    scroll.scroll_vertical = 0


func _refresh_text() -> void:
    title_label.text = tr("COSMETICS_TITLE")
    coins_label.text = str(int(_state.get("coins", 0)))
    for category in _tab_buttons:
        var tab: Button = _tab_buttons[category]
        # Five tabs no longer fit a word each at 390 px wide, so the caption moves to
        # the tooltip and the tab shows an item from its own category instead.
        tab.tooltip_text = tr(CATEGORY_TAB_KEYS[category])
    body_color_label.text = tr("COSMETICS_BODY_COLOR")
    belly_label.text = tr("COSMETICS_BELLY")
    _show_status("")


## Gives each tab an icon cropped from one of its own items.
##
## Reusing the catalog artwork keeps the tabs honest -- the picture on a tab is a thing
## the child can actually buy inside it -- and means no separate icon set to keep in
## step. The colour tab has no artwork, so it gets a swatch of the body colours instead.
func _apply_tab_icons() -> void:
    for category in TAB_ICON_ITEM_IDS:
        var tab: Button = _tab_buttons.get(category)
        if tab == null:
            continue
        tab.icon = _category_icon(category, String(TAB_ICON_ITEM_IDS[category]))
    color_tab.icon = _body_color_swatch()


func _category_icon(category: String, item_id: String) -> Texture2D:
    var item := CosmeticCatalog.item(category, item_id)
    var texture_path := String(item.get("texture_path", ""))
    if texture_path.is_empty():
        return null
    var region: Rect2 = item.get("display_region", Rect2())
    var source := load(texture_path) as Texture2D
    if source == null or region.size.length_squared() <= 0.0:
        return source
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    atlas.region = region
    return atlas


func _body_color_swatch() -> Texture2D:
    # Laid out as a block rather than a strip: a six-by-one image stretches to a thin
    # bar once the button scales it to fit, which reads as a rule, not a palette.
    var colors := CosmeticCatalog.body_colors()
    var columns := 3
    var rows := int(ceil(colors.size() / float(columns)))
    var image := Image.create(columns, rows, false, Image.FORMAT_RGBA8)
    for index in colors.size():
        image.set_pixel(
            index % columns,
            index / columns,
            Color(colors[index]["color"])
        )
    return ImageTexture.create_from_image(image)


func _rebuild_catalog() -> void:
    _cards.clear()
    _rebuild_swatches(
        color_grid,
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        _state.get("colors", [])
    )
    _rebuild_swatches(
        belly_grid,
        CosmeticCatalog.CATEGORY_BELLY_COLOR,
        _state.get("belly_colors", [])
    )
    _rebuild_accessories(
        hats_grid,
        CosmeticCatalog.CATEGORY_HAT,
        _state.get("hats", [])
    )
    _rebuild_accessories(
        glasses_grid,
        CosmeticCatalog.CATEGORY_GLASSES,
        _state.get("glasses", [])
    )
    _rebuild_accessories(
        necklaces_grid,
        CosmeticCatalog.CATEGORY_NECKLACE,
        _state.get("necklaces", [])
    )
    _rebuild_accessories(
        footwear_grid,
        CosmeticCatalog.CATEGORY_FOOTWEAR,
        _state.get("footwear", [])
    )
    _refresh_card_marks()


func _rebuild_swatches(
    grid: GridContainer,
    category: String,
    items: Array
) -> void:
    _clear_grid(grid)
    for item_value in items:
        var item: Dictionary = item_value
        var item_id := String(item["id"])
        var swatch := CosmeticSwatch.new()
        swatch.configure(
            item_id,
            Color(item["color"]),
            not bool(item["owned"]),
            bool(item["selected"])
        )
        swatch.tooltip_text = tr(String(item["name_key"]))
        swatch.pressed.connect(_on_item_pressed.bind(category, item_id))
        grid.add_child(swatch)
        _cards[_card_key(category, item_id)] = swatch


func _rebuild_accessories(
    grid: GridContainer,
    category: String,
    items: Array
) -> void:
    _clear_grid(grid)
    for item_value in items:
        var item: Dictionary = item_value
        var item_id := String(item["id"])
        var card := CosmeticItemCard.new()
        card.card_size = ACCESSORY_CARD_SIZE
        card.configure(item, not bool(item["owned"]), bool(item["selected"]))
        card.tooltip_text = tr(String(item["name_key"]))
        card.pressed.connect(_on_item_pressed.bind(category, item_id))
        grid.add_child(card)
        _cards[_card_key(category, item_id)] = card


func _card_key(category: String, item_id: String) -> String:
    return "%s|%s" % [category, item_id]


func _clear_grid(grid: GridContainer) -> void:
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()


func _refresh_card_marks() -> void:
    var selected_key := _card_key(_selected_category, _selected_item_id)
    for card_key in _cards:
        var card: Control = _cards[card_key]
        if is_instance_valid(card):
            card.set_previewed(card_key == selected_key)


func _refresh_dock() -> void:
    var item := _state_item(_selected_category, _selected_item_id)
    if item.is_empty():
        return
    preview_blob.apply_cosmetics(_preview_cosmetics_state())
    item_name_label.text = tr(String(item["name_key"]))
    _refresh_price_row(item)
    _refresh_action_button(item)
    _refresh_card_marks()


func _preview_cosmetics_state() -> Dictionary:
    var previewed := _state.duplicate(true)
    previewed[CATEGORY_SELECTED_KEYS[_selected_category]] = _selected_item_id
    return previewed


func _refresh_price_row(item: Dictionary) -> void:
    # Only owned items get a row of their own. While an item is still for sale the
    # action button carries the cost, so repeating it here would print the same
    # figure twice in one dock.
    var owned := bool(item["owned"])
    price_row.visible = owned
    if owned:
        price_label.text = tr("COSMETICS_OWNED")
        price_coin_icon.visible = false


func _refresh_action_button(item: Dictionary) -> void:
    var owned := bool(item["owned"])
    var worn := _equipped_id(_selected_category) == _selected_item_id
    var is_color := _selected_category in [
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        CosmeticCatalog.CATEGORY_BELLY_COLOR,
    ]
    purchase_button.visible = true
    var price := int(item["price"])
    var shows_price := not owned and price > 0
    buy_content.visible = shows_price
    if shows_price:
        var can_afford := int(_state.get("coins", 0)) >= price
        purchase_button.disabled = not can_afford
        # The button's own text stays empty: BuyContent draws "<price> (coin)" on top.
        # Affordability is carried by the disabled style plus a dimmed number, because
        # a disabled Button cannot recolor a child Label for us.
        purchase_button.text = ""
        buy_price_label.text = str(price)
        buy_price_label.add_theme_color_override(
            "font_color",
            CAN_AFFORD_COLOR if can_afford else CANNOT_AFFORD_COLOR
        )
        buy_coin_icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if can_afford else 0.6)
    elif not owned:
        purchase_button.disabled = false
        purchase_button.text = tr("COSMETICS_FREE")
    elif worn:
        purchase_button.disabled = true
        purchase_button.text = tr(
            "COSMETICS_WORN_COLOR" if is_color else "COSMETICS_WORN"
        )
    else:
        purchase_button.disabled = false
        purchase_button.text = tr(
            "COSMETICS_WEAR_COLOR" if is_color else "COSMETICS_WEAR"
        )


func _on_item_pressed(category: String, item_id: String) -> void:
    selection_player.play()
    preview_item(category, item_id)


func _on_tab_pressed(category: String) -> void:
    if _active_category == category:
        return
    selection_player.play()
    _show_category(category)
    _selected_category = category
    _selected_item_id = _equipped_id(category)
    _refresh_dock()


func _on_action_pressed() -> void:
    var item := _state_item(_selected_category, _selected_item_id)
    if item.is_empty():
        return
    if not bool(item["owned"]):
        if not AppState.purchase_cosmetic(_selected_category, _selected_item_id):
            _show_status(tr("COSMETICS_NOT_ENOUGH"))
            return
        purchase_player.play()
        refresh_from_state()
        _show_status(tr("COSMETICS_PURCHASED"))
        return
    if _equipped_id(_selected_category) == _selected_item_id:
        return
    if AppState.equip_cosmetic(_selected_category, _selected_item_id):
        selection_player.play()
        refresh_from_state()
        _show_status(tr("COSMETICS_EQUIPPED"))


func _state_item(category: String, item_id: String) -> Dictionary:
    if not CATEGORY_STATE_KEYS.has(category):
        return {}
    for item in _state.get(CATEGORY_STATE_KEYS[category], []):
        if String(item["id"]) == item_id:
            return item
    return {}


func _show_status(message: String) -> void:
    status_label.text = message
    status_label.visible = not message.is_empty()


func _request_screen(screen_signal: Signal) -> void:
    screen_signal.emit()
