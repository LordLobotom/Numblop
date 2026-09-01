class_name NavBar
extends PanelContainer

## The five-item footer shared by Home, Map, Cosmetics, Trophy and Settings, and reused by
## secondary pages such as free-practice setup with no item highlighted.
##
## Which item is active is a single property here. Each screen used to encode it twice
## and by convention only -- sizing one crest 62x62 instead of 56x56, and swapping that
## item's label to the bold font in a per-screen colour -- with nothing keeping the two
## halves in step and nothing stopping a screen from highlighting the wrong item.

signal outfit_requested
signal map_requested
signal home_requested
signal trophy_requested
signal settings_requested

enum Item {NONE = -1, OUTFIT = 0, MAP = 1, HOME = 2, TROPHY = 3, SETTINGS = 4}

const IDLE_CREST_SIZE := Vector2(56.0, 56.0)
const ACTIVE_CREST_SIZE := Vector2(62.0, 62.0)
const IDLE_LABEL_COLOR := Color(0.2, 0.33, 0.27)
const BOLD_FONT: Font = preload("res://ui/fonts/Baloo2Bold.tres")

## The item this screen represents; its crest grows and its label goes bold.
@export var active_item: Item = Item.HOME:
    set(value):
        active_item = value
        if is_node_ready():
            _apply_active_item()

## Highlight colour for the active label. Trophy overrides the default green with the
## amber of its own crest.
@export var active_color := Color(0.28, 0.58, 0.09):
    set(value):
        active_color = value
        if is_node_ready():
            _apply_active_item()

@onready var _items: Dictionary = {
    Item.OUTFIT: {
        "button": %OutfitButton, "label": %OutfitLabel, "key": "NAV_OUTFIT",
        "signal": outfit_requested,
    },
    Item.MAP: {
        "button": %MapButton, "label": %MapLabel, "key": "NAV_MAP",
        "signal": map_requested,
    },
    Item.HOME: {
        "button": %HomeButton, "label": %HomeLabel, "key": "NAV_HOME",
        "signal": home_requested,
    },
    Item.TROPHY: {
        "button": %TrophyButton, "label": %TrophyLabel, "key": "NAV_TROPHY",
        "signal": trophy_requested,
    },
    Item.SETTINGS: {
        "button": %SettingsButton, "label": %SettingsLabel, "key": "NAV_SETTINGS",
        "signal": settings_requested,
    },
}


func _ready() -> void:
    for item in _items:
        var entry: Dictionary = _items[item]
        var emit: Signal = entry["signal"]
        # The screen already showing an item still emits, so a stray tap is a no-op
        # rather than a reload; screens decide what to do with their own signal.
        (entry["button"] as BaseButton).pressed.connect(func() -> void: emit.emit())
    _refresh_text()
    _apply_active_item()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func _refresh_text() -> void:
    for item in _items:
        var entry: Dictionary = _items[item]
        var caption := tr(String(entry["key"]))
        (entry["label"] as Label).text = caption
        (entry["button"] as Control).tooltip_text = caption


func _apply_active_item() -> void:
    for item in _items:
        var entry: Dictionary = _items[item]
        var is_active: bool = item == active_item
        var button: Control = entry["button"]
        var label: Label = entry["label"]
        button.custom_minimum_size = ACTIVE_CREST_SIZE if is_active else IDLE_CREST_SIZE
        label.add_theme_color_override(
            "font_color",
            active_color if is_active else IDLE_LABEL_COLOR
        )
        if is_active:
            label.add_theme_font_override("font", BOLD_FONT)
        else:
            label.remove_theme_font_override("font")
