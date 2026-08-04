extends NumblopTestCase

## Petting drives real input through the avatar, because the whole point of the gesture is
## which pointer events count as petting and which do not.

const BLOB_SIZE := Vector2(220.0, 220.0)

var _pets := 0


func test_a_tap_no_longer_pets_the_avatar() -> void:
    var blob := _build_blob()
    await _settle()

    _pets = 0
    _touch(Vector2(110.0, 110.0), true)
    await _settle()
    # The jitter every real finger leaves behind must not add up to a stroke.
    _touch_drag(Vector2(113.0, 112.0))
    await _settle()
    _touch(Vector2(113.0, 112.0), false)
    await _settle()

    equal(_pets, 0, "A tap leaves Numblop alone")
    _free_blob(blob)


func test_stroking_the_avatar_pets_it() -> void:
    var blob := _build_blob()
    await _settle()

    _pets = 0
    _touch(Vector2(60.0, 110.0), true)
    await _settle()
    for step in 5:
        _touch_drag(Vector2(60.0 + float(step + 1) * 15.0, 110.0))
        await _settle()
    _touch(Vector2(135.0, 110.0), false)
    await _settle()

    equal(_pets, 1, "One stroke pets him once")
    check(blob.get_node("HeartLayer").get_child_count() > 0, "Petting spawns a heart")
    _free_blob(blob)


func test_rubbing_back_and_forth_counts_as_stroking() -> void:
    # A child rubs in place as often as they sweep across, and the path length is what
    # makes both read as petting.
    var blob := _build_blob()
    await _settle()

    _pets = 0
    _touch(Vector2(110.0, 110.0), true)
    await _settle()
    for step in 4:
        _touch_drag(Vector2(110.0 + (15.0 if step % 2 == 0 else -15.0), 110.0))
        await _settle()
    _touch(Vector2(110.0, 110.0), false)
    await _settle()

    check(_pets >= 1, "Rubbing in one place still pets him")
    _free_blob(blob)


func test_a_new_reaction_never_cuts_the_sound_off_mid_clip() -> void:
    # Reactions come faster than a clip finishes, so restarting it on each one chopped the
    # giggle into a stutter.
    var blob := _build_blob()
    await _settle()
    var voice: AudioStreamPlayer = blob.get_node("%PetVoicePlayer")

    voice.play()
    await _settle()
    check(voice.playing, "Numblop has a voice to interrupt")
    var position_before := voice.get_playback_position()
    blob._speak()
    check(
        voice.get_playback_position() >= position_before,
        "A reaction mid-clip does not rewind the sound"
    )

    voice.stop()
    await _settle()
    blob._speak()
    check(voice.playing, "Once he has finished, the next reaction speaks again")
    _free_blob(blob)


func test_a_preview_avatar_ignores_stroking() -> void:
    # The cosmetics dock shows the same avatar as a picture of what is being bought.
    var blob := _build_blob()
    blob.set_preview_mode(true)
    await _settle()

    _pets = 0
    _touch(Vector2(60.0, 110.0), true)
    await _settle()
    for step in 5:
        _touch_drag(Vector2(60.0 + float(step + 1) * 15.0, 110.0))
        await _settle()
    _touch(Vector2(135.0, 110.0), false)
    await _settle()

    equal(_pets, 0, "A preview avatar is not pettable")
    _free_blob(blob)


func _build_blob() -> BlobCharacter:
    var blob: BlobCharacter = load(
        "res://scenes/components/BlobCharacter.tscn"
    ).instantiate()
    blob.set_anchors_preset(Control.PRESET_TOP_LEFT)
    blob.position = Vector2.ZERO
    blob.size = BLOB_SIZE
    blob.custom_minimum_size = BLOB_SIZE
    (Engine.get_main_loop() as SceneTree).root.add_child(blob)
    blob.petted.connect(func() -> void: _pets += 1)
    return blob


func _free_blob(blob: BlobCharacter) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    blob.get_node("%PetVoicePlayer").stream = null
    tree.root.remove_child(blob)
    blob.free()


func _settle() -> void:
    var tree := Engine.get_main_loop() as SceneTree
    await tree.process_frame
    await tree.process_frame


func _touch(position: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = position
    event.pressed = pressed
    _push(event)


func _touch_drag(position: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = 0
    event.position = position
    _push(event)


func _push(event: InputEvent) -> void:
    ((Engine.get_main_loop() as SceneTree).root as Viewport).push_input(event, true)
