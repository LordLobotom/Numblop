extends SceneTree
## Regenerates every launcher icon from the single avatar artwork.
##
## Run through tools/generate-app-icons.ps1. Deterministic and idempotent: it overwrites the
## committed PNGs in place, so their paths, UIDs and .import files stay valid and neither
## export_presets.cfg nor the project contract test has to change.

const SOURCE_PATH := "res://ui/branding/numblop_head_icon.png"

const ADAPTIVE_SIZE := 432
## Android only guarantees the central 66% of an adaptive layer survives the launcher mask.
const ADAPTIVE_SAFE_SIZE := 288
const LEGACY_SIZE := 192
const DESKTOP_SIZE := 512

## Sampled on the card's inner edge midpoints, in source-relative coordinates: background
## gradient only, clear of the crown, the feet and the bright outer rim.
const BACKGROUND_SAMPLES: Array[Vector2] = [
    Vector2(0.10, 0.50),
    Vector2(0.90, 0.50),
    Vector2(0.50, 0.06),
    Vector2(0.50, 0.96),
]

## Luminance window turning the artwork into the themed-icon glyph. The blob's body is lighter
## than the background gradient it sits on, so a bright cut yields a solid silhouette — far more
## legible at launcher size than the dark linework, which thins out to nothing.
const MONOCHROME_LOW := 0.76
const MONOCHROME_HIGH := 0.84

var _has_run := false


func _process(_delta: float) -> bool:
    if _has_run:
        return true
    _has_run = true
    _generate()
    return true


func _generate() -> void:
    var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
    if source == null:
        push_error("Could not load %s" % SOURCE_PATH)
        quit(1)
        return
    source.convert(Image.FORMAT_RGBA8)

    _save(_scaled(source, LEGACY_SIZE), "res://ui/branding/android/icon_main_192.png")
    _save(_scaled(source, DESKTOP_SIZE), "res://ui/branding/numblop_ico.png")

    var safe := _scaled(source, ADAPTIVE_SAFE_SIZE)
    _save(_centered(safe), "res://ui/branding/android/icon_foreground_432.png")
    _save(_background(source), "res://ui/branding/android/icon_background_432.png")
    _save(_centered(_monochrome(safe)), "res://ui/branding/android/icon_monochrome_432.png")

    print("NUMBLOP_ICONS_OK")
    quit()


func _scaled(source: Image, size: int) -> Image:
    var image := source.duplicate() as Image
    image.resize(size, size, Image.INTERPOLATE_LANCZOS)
    return image


## Places a square layer at the centre of a transparent adaptive canvas.
func _centered(layer: Image) -> Image:
    var canvas := Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
    canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
    var offset := (ADAPTIVE_SIZE - layer.get_width()) / 2
    canvas.blit_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i(offset, offset))
    return canvas


## Flat fill in the artwork's own background green, so the card edge blends outward.
func _background(source: Image) -> Image:
    var total := Color(0.0, 0.0, 0.0, 0.0)
    for sample in BACKGROUND_SAMPLES:
        var x := int(sample.x * float(source.get_width() - 1))
        var y := int(sample.y * float(source.get_height() - 1))
        total += source.get_pixel(x, y)
    var average := total / float(BACKGROUND_SAMPLES.size())
    average.a = 1.0

    var image := Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
    image.fill(average)
    return image


## White silhouette of the blob; Android tints it for themed icons.
func _monochrome(layer: Image) -> Image:
    var image := Image.create_empty(
        layer.get_width(), layer.get_height(), false, Image.FORMAT_RGBA8
    )
    for y in layer.get_height():
        for x in layer.get_width():
            var pixel := layer.get_pixel(x, y)
            var luminance := pixel.get_luminance()
            var alpha := smoothstep(MONOCHROME_LOW, MONOCHROME_HIGH, luminance) * pixel.a
            image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
    return image


func _save(image: Image, path: String) -> void:
    var error := image.save_png(ProjectSettings.globalize_path(path))
    if error != OK:
        push_error("Could not write %s (%d)" % [path, error])
        quit(1)
        return
    print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
