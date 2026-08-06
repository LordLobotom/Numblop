class_name TouchScrollContainer
extends ScrollContainer

## A ScrollContainer whose content can be dragged from anywhere, including from a button.
##
## `scroll_deadzone` alone is not enough on a screen made of islands, cards and swatches. A
## pressed control keeps the gesture for as long as the finger is down, so every drag that
## started on one of them was delivered to that control and the page refused to move --
## which is most of the page on Map, Trophy, Settings and Cosmetics.
##
## This watches the gesture in `_input`, which runs before the pressed control's own
## handling, and takes it over once the finger has travelled past the deadzone. The press
## is then canceled rather than released, so the control the child started on lights up for
## the touch but never fires. Below the deadzone nothing is intercepted at all and a short
## tap behaves exactly as before.
##
## Sliders are the one exception. Dragging one sideways is how it is set, so a gesture that
## started on a slider is only claimed when the finger is clearly heading up or down; a
## sideways drag is left to the slider and the volume follows the finger the whole way.

## Identifies the mouse as a pointer alongside the numbered touch indices.
const MOUSE_POINTER_INDEX := -1
## A fling below this many pixels per second is treated as a stop, not as a throw.
const MINIMUM_FLING_SPEED := 60.0
## Share of the fling speed kept per second while coasting.
const FLING_FRICTION := 0.12
## Speed at which coasting ends, in pixels per second.
const FLING_STOP_SPEED := 8.0

var _pointer_index := MOUSE_POINTER_INDEX
var _tracking := false
var _dragging := false
var _origin := Vector2.ZERO
var _last_position := Vector2.ZERO
var _last_motion_msec := 0
## Sub-pixel remainder, because the scroll offsets themselves are whole pixels.
var _scroll_remainder := Vector2.ZERO
var _fling_velocity := Vector2.ZERO
## Set while the synthetic cancel below is being dispatched, so this node does not read
## its own cancel as the finger having been lifted.
var _canceling_child_press := false
## The gesture began on a slider, so it has to prove it is a scroll before being claimed.
var _started_on_slider := false
## Latched once a slider's gesture is judged sideways: the rest of it belongs to the slider,
## so a wobble later in the drag can never yank it away mid-adjustment.
var _declined := false


func _ready() -> void:
    set_process(false)


## True while a drag has been taken over from a child control.
func is_gesture_scrolling() -> bool:
    return _dragging


func _input(event: InputEvent) -> void:
    var viewport := get_viewport()
    if viewport == null or not is_visible_in_tree():
        return
    # A ScrollContainer nested inside another one sees the event first and claims it.
    if viewport.is_input_handled():
        return

    if event is InputEventScreenTouch:
        _handle_pointer_press(event.position, event.pressed, event.index)
    elif event is InputEventScreenDrag:
        _handle_pointer_motion(event.position, event.index)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_pointer_press(event.position, event.pressed, MOUSE_POINTER_INDEX)
    elif event is InputEventMouseMotion:
        if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
            _handle_pointer_motion(event.position, MOUSE_POINTER_INDEX)


func _handle_pointer_press(position: Vector2, pressed: bool, pointer_index: int) -> void:
    if _canceling_child_press:
        return
    if pressed:
        # Android also emulates a mouse from every touch; the touch got here first.
        if _tracking:
            return
        if not get_global_rect().has_point(position) or not _can_scroll():
            return
        _pointer_index = pointer_index
        _tracking = true
        _dragging = false
        _declined = false
        _started_on_slider = _find_range_at(self, position) != null
        _origin = position
        _last_position = position
        _last_motion_msec = Time.get_ticks_msec()
        _scroll_remainder = Vector2.ZERO
        _stop_fling()
        return

    if not _tracking or pointer_index != _pointer_index:
        return
    var was_dragging := _dragging
    _tracking = false
    _dragging = false
    _declined = false
    _started_on_slider = false
    if was_dragging:
        # The child's press was already canceled; swallowing the release too keeps the
        # lift-off from counting as a tap on whatever ended up under the finger.
        get_viewport().set_input_as_handled()
        _start_fling()


func _handle_pointer_motion(position: Vector2, pointer_index: int) -> void:
    if not _tracking or pointer_index != _pointer_index:
        return
    if _declined:
        return
    var motion := position - _last_position
    var elapsed_msec := Time.get_ticks_msec() - _last_motion_msec
    _last_position = position

    if not _dragging:
        if _origin.distance_to(position) < float(scroll_deadzone):
            return
        # A slider keeps its own gesture unless the finger is clearly leaving it vertically,
        # so the page can still be scrolled from the band a slider sits in.
        if _started_on_slider:
            var travel := position - _origin
            if absf(travel.y) <= absf(travel.x):
                _declined = true
                return
        _dragging = true
        _cancel_child_press()

    _scroll_by(-motion)
    if elapsed_msec > 0:
        _fling_velocity = -motion * (1000.0 / float(elapsed_msec))
    _last_motion_msec = Time.get_ticks_msec()
    get_viewport().set_input_as_handled()


## Releases the control the finger started on without letting it fire.
##
## A canceled release is what a native list does: the button stops looking held, and no
## tap is reported, because the child never finished the press it started.
func _cancel_child_press() -> void:
    var viewport := get_viewport()
    _canceling_child_press = true
    if _pointer_index == MOUSE_POINTER_INDEX:
        var mouse_cancel := InputEventMouseButton.new()
        mouse_cancel.button_index = MOUSE_BUTTON_LEFT
        mouse_cancel.position = _origin
        mouse_cancel.global_position = _origin
        mouse_cancel.pressed = false
        mouse_cancel.canceled = true
        viewport.push_input(mouse_cancel, true)
        _canceling_child_press = false
        return
    var touch_cancel := InputEventScreenTouch.new()
    touch_cancel.index = _pointer_index
    touch_cancel.position = _origin
    touch_cancel.pressed = false
    touch_cancel.canceled = true
    viewport.push_input(touch_cancel, true)
    _canceling_child_press = false


## The deepest editable slider under the point, or null. Sliders are the only `Range` on these
## pages and there are two of them, so the walk is cheap and stops at the first hit.
func _find_range_at(node: Node, position: Vector2) -> Range:
    for child in node.get_children():
        var control := child as Control
        if control == null or not control.is_visible_in_tree():
            continue
        if not control.get_global_rect().has_point(position):
            continue
        var range_control := control as Range
        if range_control != null and range_control.editable:
            return range_control
        var nested := _find_range_at(control, position)
        if nested != null:
            return nested
    return null


func _scroll_by(amount: Vector2) -> void:
    var requested := amount + _scroll_remainder
    var applied := Vector2(
        float(int(requested.x)) if _scrolls_horizontally() else 0.0,
        float(int(requested.y)) if _scrolls_vertically() else 0.0
    )
    _scroll_remainder = Vector2(
        requested.x - applied.x if _scrolls_horizontally() else 0.0,
        requested.y - applied.y if _scrolls_vertically() else 0.0
    )
    if _scrolls_horizontally():
        scroll_horizontal += int(applied.x)
    if _scrolls_vertically():
        scroll_vertical += int(applied.y)


func _process(delta: float) -> void:
    if _fling_velocity.length() <= FLING_STOP_SPEED:
        _stop_fling()
        return
    _scroll_by(_fling_velocity * delta)
    _fling_velocity *= pow(FLING_FRICTION, delta)


func _start_fling() -> void:
    if _fling_velocity.length() < MINIMUM_FLING_SPEED:
        _fling_velocity = Vector2.ZERO
        return
    set_process(true)


func _stop_fling() -> void:
    _fling_velocity = Vector2.ZERO
    set_process(false)


func _can_scroll() -> bool:
    return _scrolls_vertically() or _scrolls_horizontally()


func _scrolls_vertically() -> bool:
    return (
        vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
        and get_v_scroll_bar().max_value > get_v_scroll_bar().page
    )


func _scrolls_horizontally() -> bool:
    return (
        horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
        and get_h_scroll_bar().max_value > get_h_scroll_bar().page
    )
