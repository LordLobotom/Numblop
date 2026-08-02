class_name CosmeticsScreen
extends Control

signal home_requested
signal map_requested
signal trophy_requested
signal settings_requested

const COIN_TEXTURE: Texture2D = preload("res://ui/crests/crest_coin.png")

@onready var title_label: Label = %TitleLabel
@onready var coins_label: Label = %CoinsLabel
@onready var color_label: Label = %ColorLabel
@onready var color_grid: GridContainer = %ColorGrid
@onready var hats_label: Label = %HatsLabel
@onready var hats_grid: GridContainer = %HatsGrid
@onready var glasses_label: Label = %GlassesLabel
@onready var glasses_grid: GridContainer = %GlassesGrid
@onready var necklaces_label: Label = %NecklacesLabel
@onready var necklaces_grid: GridContainer = %NecklacesGrid
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
var _preview_category := CosmeticCatalog.CATEGORY_BODY_COLOR
var _preview_item_id := CosmeticCatalog.DEFAULT_BODY_COLOR_ID


func _ready() -> void:
    map_button.pressed.connect(_request_screen.bind(map_requested))
    home_button.pressed.connect(_request_screen.bind(home_requested))
    trophy_button.pressed.connect(_request_screen.bind(trophy_requested))
    settings_button.pressed.connect(_request_screen.bind(settings_requested))
    purchase_button.pressed.connect(_purchase_previewed_item)
    refresh_from_state()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _rebuild_catalog()
        _refresh_purchase_action()


func refresh_from_state() -> void:
    set_presentation_state(AppState.cosmetics_state())


func set_presentation_state(state: Dictionary) -> void:
    _state = state.duplicate(true)
    _preview_category = CosmeticCatalog.CATEGORY_BODY_COLOR
    _preview_item_id = String(_state.get(
        "selected_body_color",
        CosmeticCatalog.DEFAULT_BODY_COLOR_ID
    ))
    if not is_node_ready():
        return
    _refresh_text()
    _rebuild_catalog()
    _refresh_purchase_action()


func show_future_feature() -> void:
    _show_status(tr("HOME_FEATURE_LATER"))


func preview_body_color(color_id: String) -> void:
    _preview_item(CosmeticCatalog.CATEGORY_BODY_COLOR, color_id)


func _preview_item(category: String, item_id: String) -> void:
    var item := _state_item(category, item_id)
    if item.is_empty():
        return
    _preview_category = category
    _preview_item_id = item_id
    if bool(item["owned"]):
        if AppState.equip_cosmetic(category, item_id):
            refresh_from_state()
            _show_status(tr("COSMETICS_EQUIPPED"))
    else:
        _show_status(tr("COSMETICS_TAP_BUY"))
        _refresh_purchase_action()


func _refresh_text() -> void:
    title_label.text = tr("COSMETICS_TITLE")
    coins_label.text = str(int(_state.get("coins", 0)))
    color_label.text = tr("COSMETICS_BODY_COLOR")
    hats_label.text = tr("COSMETICS_HATS")
    glasses_label.text = tr("COSMETICS_GLASSES")
    necklaces_label.text = tr("COSMETICS_NECKLACES")
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
    _clear_grid(color_grid)
    for item in _state.get("colors", []):
        var item_id := String(item["id"])
        var item_column := _item_column(Vector2(48.0, 68.0))
        color_grid.add_child(item_column)

        var swatch := CosmeticSwatch.new()
        swatch.configure(
            item_id,
            Color(item["color"]),
            not bool(item["owned"]),
            bool(item["selected"])
        )
        swatch.tooltip_text = tr(String(item["name_key"]))
        swatch.pressed.connect(_on_item_pressed.bind(
            CosmeticCatalog.CATEGORY_BODY_COLOR,
            item_id
        ))
        item_column.add_child(swatch)
        _add_price_row(item_column, item)

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


func _rebuild_accessories(
    grid: GridContainer,
    category: String,
    items: Array
) -> void:
    _clear_grid(grid)
    for item_value in items:
        var item: Dictionary = item_value
        var item_id := String(item["id"])
        var item_column := _item_column(Vector2(58.0, 78.0))
        grid.add_child(item_column)

        var card := CosmeticItemCard.new()
        card.configure(item, not bool(item["owned"]), bool(item["selected"]))
        card.tooltip_text = tr(String(item["name_key"]))
        card.pressed.connect(_on_item_pressed.bind(category, item_id))
        item_column.add_child(card)
        _add_price_row(item_column, item)


func _item_column(minimum_size: Vector2) -> VBoxContainer:
    var item_column := VBoxContainer.new()
    item_column.custom_minimum_size = minimum_size
    item_column.alignment = BoxContainer.ALIGNMENT_CENTER
    item_column.add_theme_constant_override("separation", 0)
    return item_column


func _add_price_row(parent: VBoxContainer, item: Dictionary) -> void:
    var price_center := CenterContainer.new()
    price_center.custom_minimum_size = Vector2(0.0, 18.0)
    parent.add_child(price_center)
    if bool(item["owned"]) or int(item["price"]) <= 0:
        return

    var price_row := HBoxContainer.new()
    price_row.add_theme_constant_override("separation", 1)
    price_row.alignment = BoxContainer.ALIGNMENT_CENTER
    price_center.add_child(price_row)

    var price_label := Label.new()
    price_label.add_theme_font_size_override("font_size", 13)
    price_label.add_theme_color_override("font_color", Color(0.34, 0.27, 0.12))
    price_label.text = str(int(item["price"]))
    price_row.add_child(price_label)

    var coin_icon := TextureRect.new()
    coin_icon.custom_minimum_size = Vector2(14.0, 14.0)
    coin_icon.texture = COIN_TEXTURE
    coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    price_row.add_child(coin_icon)


func _clear_grid(grid: GridContainer) -> void:
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()


func _on_item_pressed(category: String, item_id: String) -> void:
    selection_player.play()
    _preview_item(category, item_id)


func _purchase_previewed_item() -> void:
    if not AppState.purchase_cosmetic(_preview_category, _preview_item_id):
        _show_status(tr("COSMETICS_NOT_ENOUGH"))
        return
    purchase_player.play()
    refresh_from_state()
    _show_status(tr("COSMETICS_PURCHASED"))


func _refresh_purchase_action() -> void:
    var item := _state_item(_preview_category, _preview_item_id)
    if item.is_empty() or bool(item["owned"]):
        purchase_button.visible = false
        return
    var price := int(item["price"])
    var can_afford := int(_state.get("coins", 0)) >= price
    purchase_button.visible = true
    purchase_button.disabled = not can_afford
    purchase_button.text = (
        tr("COSMETICS_BUY").format({"price": price})
        if can_afford
        else tr("COSMETICS_NEED_COINS").format({"price": price})
    )


func _state_item(category: String, item_id: String) -> Dictionary:
    var state_key := "colors"
    match category:
        CosmeticCatalog.CATEGORY_HAT:
            state_key = "hats"
        CosmeticCatalog.CATEGORY_GLASSES:
            state_key = "glasses"
        CosmeticCatalog.CATEGORY_NECKLACE:
            state_key = "necklaces"
    for item in _state.get(state_key, []):
        if String(item["id"]) == item_id:
            return item
    return {}


func _show_status(message: String) -> void:
    status_label.text = message
    status_label.visible = not message.is_empty()


func _request_screen(screen_signal: Signal) -> void:
    screen_signal.emit()
