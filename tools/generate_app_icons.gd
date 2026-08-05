extends SceneTree
## Regenerates the derived launcher icons from the hand-authored Android artwork.
##
## Run through tools/generate-app-icons.ps1. Deterministic and idempotent: it overwrites the
## committed PNGs in place, so their paths, UIDs and .import files stay valid.
##
## The two adaptive layers are drawn by hand and are inputs here, never outputs -- this script
## must not overwrite them. What it derives from them is the themed-icon silhouette and the
## legacy square icon, both of which have to track the artwork exactly or the launcher shows a
## glyph that does not match its own icon.

## Hand-authored, 432x432, and the source of truth for the launcher's look.
const FOREGROUND_PATH := "res://ui/branding/android/icon_numblop_front.png"
const BACKGROUND_PATH := "res://ui/branding/android/icon_numblop_back.png"

## The Windows executable icon still comes from the avatar artwork.
const DESKTOP_SOURCE_PATH := "res://ui/branding/numblop_head_icon.png"

const ADAPTIVE_SIZE := 432
const LEGACY_SIZE := 192
const DESKTOP_SIZE := 512

## Android tints the themed icon itself and reads only its alpha, so the glyph is a flat cut of
## the foreground's own alpha rather than anything derived from its colours. Half coverage is
## the cut: it keeps the antialiased rim from smearing the silhouette outwards.
const SILHOUETTE_ALPHA_CUT := 0.5

var _has_run := false


func _process(_delta: float) -> bool:
    if _has_run:
        return true
    _has_run = true
    _generate()
    return true


func _generate() -> void:
    var foreground := _load(FOREGROUND_PATH)
    var background := _load(BACKGROUND_PATH)
    var desktop_source := _load(DESKTOP_SOURCE_PATH)
    if foreground == null or background == null or desktop_source == null:
        quit(1)
        return
    if foreground.get_width() != ADAPTIVE_SIZE or foreground.get_height() != ADAPTIVE_SIZE:
        push_error("%s must be %dx%d" % [FOREGROUND_PATH, ADAPTIVE_SIZE, ADAPTIVE_SIZE])
        quit(1)
        return

    _save(
        _silhouette(foreground),
        "res://ui/branding/android/icon_monochrome_432.png"
    )
    _save(
        _scaled(_flattened(background, foreground), LEGACY_SIZE),
        "res://ui/branding/android/icon_main_192.png"
    )
    _save(_scaled(desktop_source, DESKTOP_SIZE), "res://ui/branding/numblop_ico.png")

    print("NUMBLOP_ICONS_OK")
    quit()


func _load(path: String) -> Image:
    var image := Image.load_from_file(ProjectSettings.globalize_path(path))
    if image == null:
        push_error("Could not load %s" % path)
        return null
    image.convert(Image.FORMAT_RGBA8)
    return image


func _scaled(source: Image, size: int) -> Image:
    var image := source.duplicate() as Image
    image.resize(size, size, Image.INTERPOLATE_LANCZOS)
    return image


## The legacy square icon is what the adaptive pair looks like with no mask applied.
func _flattened(background: Image, foreground: Image) -> Image:
    var image := background.duplicate() as Image
    image.blend_rect(
        foreground,
        Rect2i(Vector2i.ZERO, foreground.get_size()),
        Vector2i.ZERO
    )
    return image


## Flat white cut of the foreground's alpha; Android tints it for themed icons.
func _silhouette(foreground: Image) -> Image:
    var image := Image.create_empty(
        ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8
    )
    for y in ADAPTIVE_SIZE:
        for x in ADAPTIVE_SIZE:
            var opaque := foreground.get_pixel(x, y).a >= SILHOUETTE_ALPHA_CUT
            image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if opaque else 0.0))
    return image


func _save(image: Image, path: String) -> void:
    var error := image.save_png(ProjectSettings.globalize_path(path))
    if error != OK:
        push_error("Could not write %s (%d)" % [path, error])
        quit(1)
        return
    print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
