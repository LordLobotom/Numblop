extends SceneTree
## Regenerates every launcher and application icon from the supplied icon artwork.
##
## Run through tools/generate-app-icons.ps1. Deterministic and idempotent: it overwrites the
## committed PNGs in place, so their paths, UIDs and .import files stay valid.
##
## Only the three files below are inputs. Everything under ui/branding/android/, the desktop icon
## and the Play listing icon are derived, which keeps the adaptive layers, the legacy square icon,
## the themed glyph, the Windows icon and the store page showing the same drawing.

## Hand-authored, opaque 512x512 composition used wherever the platform does not assemble layers.
const FULL_ICON_PATH := "res://ui/branding/numblop_mascot_full_512.png"

## Hand-authored, transparent 512x512 foreground used for Android adaptive icons.
const FOREGROUND_PATH := "res://ui/branding/numblop_mascot_512.png"

## The plate behind the mascot, supplied as artwork so the palette and its detail live with the
## drawing rather than as a colour constant here.
const BACKGROUND_PATH := "res://ui/branding/numblop_mascot_bg_512.png"

const ADAPTIVE_SIZE := 432
const LEGACY_SIZE := 192
const LARGE_SIZE := 512

## Android draws a 108dp canvas, cuts everything outside the centre 72dp, and only guarantees the
## centre 66dp survives every launcher mask. The drawing therefore has to be re-fitted rather than
## dropped in at its authored scale -- the mascot fills ~78% of its own canvas, so a circular mask
## would cut off the top of the head and the feet.
##
## The limit is radial, not a bounding box: what gets clipped is the pixel furthest from the
## centre, which for this mascot is a head or foot tip, not a bbox corner. 66dp of a 108dp canvas
## is 132px of 432.
const SAFE_ZONE_RADIUS := 132.0

## Matches the rounded-square look Windows taskbars and the Godot editor showed before.
const DESKTOP_CORNER_RADIUS := 112

## A pixel counts as drawing rather than padding above this alpha. Just high enough to ignore the
## stray antialiasing the export leaves outside the outline.
const BBOX_ALPHA_THRESHOLD := 8.0 / 255.0

## Android tints the themed icon and keeps only its alpha, so anything drawn in the artwork itself
## is thrown away -- a fully opaque drawing renders as one featureless blob. The detail therefore
## has to live in the alpha: light areas (the belly, the eye whites) are knocked out so the tint
## shows them as negative space.
##
## The band between these two luminances fades rather than snapping, which keeps the drawing's
## antialiasing instead of speckling every edge.
const MONOCHROME_CUT_LOW := 205.0 / 255.0
const MONOCHROME_CUT_HIGH := 240.0 / 255.0

var _has_run := false


func _process(_delta: float) -> bool:
    if _has_run:
        return true
    _has_run = true
    _generate()
    return true


func _generate() -> void:
    var full_icon := _load(FULL_ICON_PATH)
    var foreground_source := _load(FOREGROUND_PATH)
    var background := _load(BACKGROUND_PATH)
    if full_icon == null or foreground_source == null or background == null:
        quit(1)
        return

    var foreground := _fitted_to_radius(foreground_source, ADAPTIVE_SIZE, SAFE_ZONE_RADIUS)
    if foreground == null:
        quit(1)
        return
    var adaptive_background := _scaled(background, ADAPTIVE_SIZE)

    _save(foreground, "res://ui/branding/android/icon_numblop_front.png")
    _save(adaptive_background, "res://ui/branding/android/icon_numblop_back.png")
    _save(_themed_glyph(foreground), "res://ui/branding/android/icon_monochrome_432.png")
    _save(_scaled(full_icon, LEGACY_SIZE), "res://ui/branding/android/icon_main_192.png")
    _save(_rounded(full_icon, DESKTOP_CORNER_RADIUS), "res://ui/branding/numblop_ico.png")
    _save(full_icon, "res://store/icon_512.png")

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


## Scales the artwork so no drawn pixel sits further than `radius` from the centre, then centres
## it. This is the fit that has to hold for the adaptive foreground: a circular launcher mask cuts
## by distance, so bounding the box is not the same as bounding what gets clipped.
func _fitted_to_radius(source: Image, canvas: int, radius: float) -> Image:
    var bounds := _drawn_bounds(source)
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        push_error("%s is fully transparent" % FOREGROUND_PATH)
        return null
    var drawn := _drawn_radius(source, bounds)
    if drawn <= 0.0:
        push_error("%s has no measurable extent" % FOREGROUND_PATH)
        return null
    return _fitted(source, bounds, canvas, radius / drawn)


## Crops the artwork to what it actually draws, scales that by `scale`, and centres it on a
## transparent `canvas` square. Fitting the ink rather than the authored canvas is what makes the
## safe zone a guarantee instead of an estimate.
func _fitted(source: Image, bounds: Rect2i, canvas: int, scale: float) -> Image:
    var cropped := source.get_region(bounds)
    cropped.resize(
        maxi(1, roundi(bounds.size.x * scale)),
        maxi(1, roundi(bounds.size.y * scale)),
        Image.INTERPOLATE_LANCZOS
    )

    var image := Image.create_empty(canvas, canvas, false, Image.FORMAT_RGBA8)
    image.blit_rect(
        cropped,
        Rect2i(Vector2i.ZERO, cropped.get_size()),
        (Vector2i(canvas, canvas) - cropped.get_size()) / 2
    )
    return image


## The tightest rectangle containing every pixel the artwork actually paints.
func _drawn_bounds(source: Image) -> Rect2i:
    var min_x := source.get_width()
    var min_y := source.get_height()
    var max_x := -1
    var max_y := -1
    for y in source.get_height():
        for x in source.get_width():
            if source.get_pixel(x, y).a <= BBOX_ALPHA_THRESHOLD:
                continue
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if max_x < 0:
        return Rect2i()
    return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Distance from the centre of `bounds` to the furthest pixel the artwork paints -- the extent a
## circular mask actually measures against once the drawing is centred on its canvas.
func _drawn_radius(source: Image, bounds: Rect2i) -> float:
    var centre := Vector2(bounds.position) + Vector2(bounds.size) * 0.5
    var radius := 0.0
    for y in range(bounds.position.y, bounds.end.y):
        for x in range(bounds.position.x, bounds.end.x):
            if source.get_pixel(x, y).a <= BBOX_ALPHA_THRESHOLD:
                continue
            radius = maxf(radius, (Vector2(x, y) + Vector2(0.5, 0.5) - centre).length())
    return radius


## Knocks the corners off a square image, antialiasing the arc so the edge does not look chewed
## at the small sizes Windows actually renders the icon at.
func _rounded(source: Image, radius: int) -> Image:
    var size := source.get_width()
    var image := source.duplicate() as Image
    for y in size:
        for x in size:
            var coverage := _corner_coverage(x, y, size, radius)
            if coverage >= 1.0:
                continue
            var pixel := image.get_pixel(x, y)
            pixel.a *= coverage
            image.set_pixel(x, y, pixel)
    return image


## How much of the pixel at (x, y) survives the rounded rectangle, 0 outside and 1 well inside.
func _corner_coverage(x: int, y: int, size: int, radius: int) -> float:
    # Distance past the straight edges, i.e. how far into a corner arc this pixel sits.
    var dx := maxf(radius - (x + 0.5), (x + 0.5) - (size - radius))
    var dy := maxf(radius - (y + 0.5), (y + 0.5) - (size - radius))
    if dx <= 0.0 or dy <= 0.0:
        return 1.0
    return 1.0 - smoothstep(radius - 1.0, radius + 1.0, Vector2(dx, dy).length())


## Turns the fitted artwork into the alpha-only glyph Android actually renders: dark and mid tones
## become the solid body, light tones become holes the system tint shows through. The colour is
## fixed white because only the alpha channel survives tinting.
func _themed_glyph(source: Image) -> Image:
    var image := Image.create_empty(
        ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8
    )
    for y in mini(ADAPTIVE_SIZE, source.get_height()):
        for x in mini(ADAPTIVE_SIZE, source.get_width()):
            var pixel := source.get_pixel(x, y)
            var lightness := smoothstep(
                MONOCHROME_CUT_LOW,
                MONOCHROME_CUT_HIGH,
                pixel.get_luminance()
            )
            image.set_pixel(x, y, Color(1.0, 1.0, 1.0, (1.0 - lightness) * pixel.a))
    return image


func _save(image: Image, path: String) -> void:
    var error := image.save_png(ProjectSettings.globalize_path(path))
    if error != OK:
        push_error("Could not write %s (%d)" % [path, error])
        quit(1)
        return
    print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
