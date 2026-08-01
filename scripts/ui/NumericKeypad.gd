class_name NumericKeypad
extends VBoxContainer

signal value_submitted(value: int)

const MAX_DIGITS := 2

@onready var display_label: Label = %InputDisplay
@onready var button_grid: GridContainer = %ButtonGrid
@onready var delete_button: Button = %DeleteButton
@onready var submit_button: Button = %SubmitButton
@onready var key_sfx_player: AudioStreamPlayer = %KeySfxPlayer

var _digits := ""
var _buttons: Array[Button] = []


func _ready() -> void:
    for child in button_grid.get_children():
        if child is not Button:
            continue
        var button := child as Button
        _buttons.append(button)
        if button.has_meta("digit"):
            button.pressed.connect(_on_digit_pressed.bind(int(button.get_meta("digit"))))
    delete_button.pressed.connect(_on_delete_pressed)
    submit_button.pressed.connect(_on_submit_pressed)
    _refresh_text()
    reset()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()


func reset() -> void:
    _digits = ""
    if is_node_ready():
        _refresh_display()


func set_input_enabled(enabled: bool) -> void:
    for button in _buttons:
        button.disabled = not enabled
    submit_button.disabled = not enabled or _digits.is_empty()


func _on_digit_pressed(digit: int) -> void:
    if _digits.length() >= MAX_DIGITS:
        return
    _digits += str(digit)
    key_sfx_player.play()
    _refresh_display()


func _on_delete_pressed() -> void:
    key_sfx_player.play()
    if not _digits.is_empty():
        _digits = _digits.left(_digits.length() - 1)
    _refresh_display()


func _on_submit_pressed() -> void:
    if _digits.is_empty():
        return
    set_input_enabled(false)
    value_submitted.emit(int(_digits))


func _refresh_display() -> void:
    display_label.text = "?" if _digits.is_empty() else _digits
    submit_button.disabled = _digits.is_empty()


func _refresh_text() -> void:
    delete_button.tooltip_text = tr("KEYPAD_DELETE")
    submit_button.tooltip_text = tr("KEYPAD_SUBMIT")
