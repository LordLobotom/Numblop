class_name BlobCharacter
extends Control

signal petted

const HEART_TEXTURE: Texture2D = preload("res://assets/vfx/hearh.png")

@onready var visual: Control = %Visual
@onready var left_eye_open: TextureRect = %LeftEyeOpen
@onready var right_eye_open: TextureRect = %RightEyeOpen
@onready var left_eye_closed: TextureRect = %LeftEyeClosed
@onready var right_eye_closed: TextureRect = %RightEyeClosed
@onready var happy_cheeks: TextureRect = %HappyCheeks
@onready var shy_cheeks: TextureRect = %ShyCheeks
@onready var smile_closed: TextureRect = %SmileClosed
@onready var smile_open: TextureRect = %SmileOpen
@onready var left_hand_idle: TextureRect = %LeftHandIdle
@onready var left_hand_wave: TextureRect = %LeftHandWave
@onready var idle_timer: Timer = %IdleTimer
@onready var giggle_player: AudioStreamPlayer = %GigglePlayer

var _idle_tween: Tween
var _reaction_tween: Tween
var _reacting := false
var _heart_direction := 1.0


func _ready() -> void:
    gui_input.connect(_on_gui_input)
    idle_timer.timeout.connect(_blink)
    resized.connect(_update_pivot)
    _update_pivot()
    _start_idle_animation()


func _on_gui_input(event: InputEvent) -> void:
    var pressed: bool = (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ) or (event is InputEventScreenTouch and event.pressed)
    if pressed:
        accept_event()
        react_to_pet()


func react_to_pet() -> void:
    if _reacting:
        return
    _reacting = true
    petted.emit()
    _set_happy_face(true)
    _spawn_heart()
    giggle_player.play()
    if _idle_tween != null:
        _idle_tween.kill()
    if _reaction_tween != null:
        _reaction_tween.kill()
    _reaction_tween = create_tween()
    _reaction_tween.tween_property(visual, "scale", Vector2(1.07, 0.95), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _reaction_tween.parallel().tween_property(visual, "rotation", 0.045, 0.12)
    _reaction_tween.tween_property(visual, "scale", Vector2.ONE, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _reaction_tween.parallel().tween_property(visual, "rotation", 0.0, 0.3)
    await _reaction_tween.finished
    if not is_inside_tree():
        return
    _set_happy_face(false)
    _reacting = false
    _start_idle_animation()


func _blink() -> void:
    if _reacting:
        return
    _set_eyes_closed(true)
    await get_tree().create_timer(0.14).timeout
    if is_inside_tree():
        _set_eyes_closed(false)


func _start_idle_animation() -> void:
    visual.scale = Vector2.ONE
    visual.rotation = 0.0
    _idle_tween = create_tween().set_loops()
    _idle_tween.tween_property(visual, "scale", Vector2(1.015, 0.985), 1.2) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _idle_tween.parallel().tween_property(visual, "rotation", -0.012, 1.2)
    _idle_tween.tween_property(visual, "scale", Vector2.ONE, 1.2) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _idle_tween.parallel().tween_property(visual, "rotation", 0.012, 1.2)


func _set_eyes_closed(closed: bool) -> void:
    left_eye_open.visible = not closed
    right_eye_open.visible = not closed
    left_eye_closed.visible = closed
    right_eye_closed.visible = closed


func _set_happy_face(happy: bool) -> void:
    happy_cheeks.visible = not happy
    shy_cheeks.visible = happy
    smile_closed.visible = not happy
    smile_open.visible = happy
    left_hand_idle.visible = not happy
    left_hand_wave.visible = happy


func _spawn_heart() -> void:
    var heart := TextureRect.new()
    heart.texture = HEART_TEXTURE
    heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heart.size = Vector2(52.0, 52.0)
    heart.position = Vector2(size.x * 0.66, size.y * 0.16)
    heart.pivot_offset = heart.size / 2.0
    heart.scale = Vector2(0.35, 0.35)
    %HeartLayer.add_child(heart)

    var target := heart.position + Vector2(28.0 * _heart_direction, -72.0)
    _heart_direction *= -1.0
    var tween := create_tween().set_parallel(true)
    tween.tween_property(heart, "position", target, 0.75) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(heart, "scale", Vector2.ONE, 0.25) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(heart, "modulate:a", 0.0, 0.75) \
        .set_delay(0.35).set_trans(Tween.TRANS_SINE)
    tween.chain().tween_callback(heart.queue_free)


func _update_pivot() -> void:
    visual.pivot_offset = visual.size / 2.0
