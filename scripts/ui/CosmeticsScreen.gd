class_name CosmeticsScreen
extends Control

signal home_requested
signal map_requested
signal trophy_requested
signal settings_requested

const COIN_TEXTURE: Texture2D = preload("res://ui/crests/crest_coin.png")
const ACCESSORY_CARD_SIZE := 96.0

const CATEGORY_STATE_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "colors",
    CosmeticCatalog.CATEGORY_BELLY_COLOR: "belly_colors",
    CosmeticCatalog.CATEGORY_HAT: "hats",
    CosmeticCatalog.CATEGORY_GLASSES: "glasses",
    CosmeticCatalog.CATEGORY_NECKLACE: "necklaces",
}
const CATEGORY_SELECTED_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "selected_body_color",
    CosmeticCatalog.CATEGORY_BELLY_COLOR: "selected_belly_color",
    CosmeticCatalog.CATEGORY_HAT: "selected_hat",
    CosmeticCatalog.CATEGORY_GLASSES: "selected_glasses",
    CosmeticCatalog.CATEGORY_NECKLACE: "selected_necklace",
}
const CATEGORY_DEFAULT_IDS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: CosmeticCatalog.DEFAULT_BODY_COLOR_ID,
    CosmeticCatalog.CATEGORY_BELLY_COLOR: CosmeticCatalog.DEFAULT_BELLY_COLOR_ID,
    CosmeticCatalog.CATEGORY_HAT: CosmeticCatalog.DEFAULT_HAT_ID,
    CosmeticCatalog.CATEGORY_GLASSES: CosmeticCatalog.DEFAULT_GLASSES_ID,
    CosmeticCatalog.CATEGORY_NECKLACE: CosmeticCatalog.DEFAULT_NECKLACE_ID,
}
const CATEGORY_TAB_KEYS := {
    CosmeticCatalog.CATEGORY_BODY_COLOR: "COSMETICS_TAB_COLOR",
    CosmeticCatalog.CATEGORY_HAT: "COSMETICS_TAB_HATS",
    CosmeticCatalog.CATEGORY_GLASSES: "COSMETICS_TAB_GLASSES",
    CosmeticCatalog.CATEGORY_NECKLACE: "COSMETICS_TAB_NECKLACES",
}

@onready var title_label: Label = %TitleLabel
@onready var coins_label: Label = %CoinsLabel
@onready var color_tab: Button = %ColorTab
@onready var hats_tab: Button = %HatsTab
@onready var glasses_tab: Button = %GlassesTab
@onready var necklaces_tab: Button = %NecklacesTab
@onready var scroll: ScrollContainer = %Scroll
@onready var color_page: Control = %ColorPage
@onready var hats_page: Control = %HatsPage
@onready var glasses_page: Control = %GlassesPage
@onready var necklaces_page: Control = %NecklacesPage
@onready var color_grid: GridContainer = %ColorGrid
@onready var belly_grid: GridContainer = %BellyGrid
@onready var body_color_label: Label = %BodyColorLabel
@onready var belly_label: Label = %BellyLabel
@onready var hats_grid: GridContainer = %HatsGrid
@onready var glasses_grid: GridContainer = %GlassesGrid
@onready var necklaces_grid: GridContainer = %NecklacesGrid
@onready var preview_blob: BlobCharacter = %PreviewBlob
@onready var item_name_label: Label = %ItemNameLabel
@onready var price_label: Label = %PriceLabel
@onready var price_coin_icon: TextureRect = %PriceCoinIcon
@onready var purchase_button: Button = %PurchaseButton
@onready var status_label: Label = %StatusLabel
@onready var outfit_button: TextureButton = %OutfitButton
@onready var map_button: TextureButton = %MapButton
@onready var home_button: TextureButton = %HomeButton
@onready var trophy_button: TextureButton = %TrophyButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var outfit_label: Label = %OutfitLabel
@onready var map_label: Label = %MapLabel
@onready var home_label: Label = %HomeLabel
@onready var trophy_label: Label = %TrophyLabel
@onready var settings_label: Label = %SettingsLabel
@onready var selection_player: AudioStreamPlayer = %SelectionPlayer
@onready var purchase_player: AudioStreamPlayer = %PurchasePlayer

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
    }
    _page_nodes = {
        CosmeticCatalog.CATEGORY_BODY_COLOR: color_page,
        CosmeticCatalog.CATEGORY_HAT: hats_page,
        CosmeticCatalog.CATEGORY_GLASSES: glasses_page,
        CosmeticCatalog.CATEGORY_NECKLACE: necklaces_page,
    }
    _grids = {
        CosmeticCatalog.CATEGORY_BODY_COLOR: color_grid,
        CosmeticCatalog.CATEGORY_HAT: hats_grid,
        CosmeticCatalog.CATEGORY_GLASSES: glasses_grid,
        CosmeticCatalog.CATEGORY_NECKLACE: necklaces_grid,
    }
    var tab_group := ButtonGroup.new()
    for category in _tab_buttons:
        var tab: Button = _tab_buttons[category]
        tab.button_group = tab_group
        tab.pressed.connect(_on_tab_pressed.bind(category))
    price_coin_icon.texture = COIN_TEXTURE
    preview_blob.set_preview_mode(true)
    map_button.pressed.connect(_request_screen.bind(map_requested))
    home_button.pressed.connect(_request_screen.bind(home_requested))
    trophy_button.pressed.connect(_request_screen.bind(trophy_requested))
    settings_button.pressed.connect(_request_screen.bind(settings_requested))
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
        tab.text = tr(CATEGORY_TAB_KEYS[category])
        tab.tooltip_text = tab.text
    body_color_label.text = tr("COSMETICS_BODY_COLOR")
    belly_label.text = tr("COSMETICS_BELLY")
    outfit_label.text = tr("NAV_OUTFIT")
    map_label.text = tr("NAV_MAP")
    home_label.text = tr("NAV_HOME")
    trophy_label.text = tr("NAV_TROPHY")
    settings_label.text = tr("NAV_SETTINGS")
    outfit_button.tooltip_text = tr("NAV_OUTFIT")
    map_button.tooltip_text = tr("NAV_MAP")
    home_button.tooltip_text = tr("NAV_HOME")
    trophy_button.tooltip_text = tr("NAV_TROPHY")
    settings_button.tooltip_text = tr("NAV_SETTINGS")
    _show_status("")


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
    var price := int(item["price"])
    if bool(item["owned"]):
        price_label.text = tr("COSMETICS_OWNED")
        price_coin_icon.visible = false
    elif price <= 0:
        price_label.text = tr("COSMETICS_FREE")
        price_coin_icon.visible = false
    else:
        price_label.text = str(price)
        price_coin_icon.visible = true


func _refresh_action_button(item: Dictionary) -> void:
    var owned := bool(item["owned"])
    var worn := _equipped_id(_selected_category) == _selected_item_id
    var is_color := _selected_category in [
        CosmeticCatalog.CATEGORY_BODY_COLOR,
        CosmeticCatalog.CATEGORY_BELLY_COLOR,
    ]
    purchase_button.visible = true
    if not owned:
        var price := int(item["price"])
        var can_afford := int(_state.get("coins", 0)) >= price
        purchase_button.disabled = not can_afford
        purchase_button.text = (
            tr("COSMETICS_BUY").format({"price": price})
            if can_afford
            else tr("COSMETICS_NEED_COINS").format({"price": price})
        )
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
