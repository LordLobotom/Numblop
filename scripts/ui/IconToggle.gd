class_name IconToggle
extends Button

## A big two-state tile: an icon that says what the setting is, and a colour that says
## whether it is on.
##
## The settings screen used CheckButtons here. At 390 wide they stretched into full-width
## green bars indistinguishable from the "Close game" action below them, and the state lived
## in a small low-contrast knob at the far right. A child reads a loud speaker and a crossed
## speaker instantly; they do not read a knob.
##
## The caption sits outside this control, in the owning VBox, so the tile stays square-ish
## and the whole item still reads as one thing.

const CORNER_RADIUS := 22
const BORDER_WIDTH := 3

@export var icon_on: Texture2D:
    set = set_icon_on
@export var icon_off: Texture2D:
    set = set_icon_off

## Lit state: the same green the primary buttons use, so "on" means one thing everywhere.
@export var on_fill := Color(0.88, 0.97, 0.82)
@export var on_border := Color(0.35, 0.76, 0.16)

## Off is deliberately colourless rather than red -- nothing here is a warning.
@export var off_fill := Color(0.93, 0.93, 0.91)
@export var off_border := Color(0.76, 0.78, 0.74)

## Godot multiplies the icon by its colour, and this artwork is near-black, so a hue would
## multiply straight back to black. Opacity is the only lever the art leaves, and fading the
## glyph is what makes the off tile read as switched off rather than merely differently framed.
@export_range(0.0, 1.0, 0.01) var on_glyph_opacity := 1.0
@export_range(0.0, 1.0, 0.01) var off_glyph_opacity := 0.4


func _init() -> void:
    toggle_mode = true


func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    expand_icon = true
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
    toggled.connect(_on_toggled)
    _apply_state()


func set_icon_on(value: Texture2D) -> void:
    icon_on = value
    if is_node_ready():
        _apply_state()


func set_icon_off(value: Texture2D) -> void:
    icon_off = value
    if is_node_ready():
        _apply_state()


## Called by the owner after it sets `button_pressed` without emitting `toggled`.
func refresh() -> void:
    if is_node_ready():
        _apply_state()


func _on_toggled(_pressed: bool) -> void:
    _apply_state()


func _apply_state() -> void:
    var lit := button_pressed
    icon = icon_on if lit else icon_off
    var fill := on_fill if lit else off_fill
    var border := on_border if lit else off_border
    var glyph := Color(1.0, 1.0, 1.0, on_glyph_opacity if lit else off_glyph_opacity)
    for slot in [
        "icon_normal_color",
        "icon_hover_color",
        "icon_pressed_color",
        "icon_hover_pressed_color",
        "icon_focus_color",
    ]:
        add_theme_color_override(slot, glyph)
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        add_theme_stylebox_override(state, _tile_style(fill, border))


func _tile_style(fill: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_width_left = BORDER_WIDTH
    style.border_width_top = BORDER_WIDTH
    style.border_width_right = BORDER_WIDTH
    style.border_width_bottom = BORDER_WIDTH
    style.border_color = border
    style.corner_radius_top_left = CORNER_RADIUS
    style.corner_radius_top_right = CORNER_RADIUS
    style.corner_radius_bottom_right = CORNER_RADIUS
    style.corner_radius_bottom_left = CORNER_RADIUS
    style.content_margin_left = 14.0
    style.content_margin_top = 14.0
    style.content_margin_right = 14.0
    style.content_margin_bottom = 14.0
    return style
