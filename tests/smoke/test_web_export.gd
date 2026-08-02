extends NumblopTestCase


func test_web_export_is_adaptive_threadless_and_uses_the_numblop_icon() -> void:
    var presets := _read("res://export_presets.cfg")
    check(presets.contains('name="Web"'), "Web export preset")
    check(presets.contains('platform="Web"'), "Godot Web platform")
    check(presets.contains('export_path="build/web/index.html"'), "Index export path")
    check(presets.contains("html/canvas_resize_policy=2"), "Adaptive browser canvas")
    check(presets.contains("variant/thread_support=false"), "Portable threadless export")
    check(presets.contains("html/export_icon=true"), "Numblop Web icon")
    check(presets.contains("vram_texture_compression/for_mobile=true"), "Mobile Web textures")


func test_web_commands_install_export_serve_and_validate_real_artifacts() -> void:
    var export_script := _read("res://tools/export.ps1")
    var installer := _read("res://tools/install-web-templates.ps1")
    var server := _read("res://tools/serve-web.ps1")
    var launcher := _read("res://tools/start-web.cmd")
    var smoke := _read("res://tools/web-smoke.ps1")
    check(export_script.contains('"web"'), "Scripted Web export target")
    check(export_script.contains('"Web"'), "Web preset invocation")
    check(export_script.contains('".gdignore"'), "Build directory is excluded from imports")
    check(export_script.contains("Remove-Item -LiteralPath"), "Web output is cleaned before export")
    check(installer.contains("web_nothreads_debug.zip"), "Debug Web template installer")
    check(installer.contains("web_nothreads_release.zip"), "Release Web template installer")
    check(server.contains('"application/wasm"'), "Correct WASM MIME type")
    check(server.contains('"application/octet-stream"'), "Correct pack MIME type")
    check(server.contains("[switch]$Open"), "Server can open the correct HTTP URL")
    check(launcher.contains("serve-web.ps1"), "Explorer-friendly Web launcher")
    check(smoke.contains("NUMBLOP_WEB_HTTP_SMOKE_OK"), "Web HTTP smoke marker")


func test_web_layout_keeps_phone_fit_and_adds_a_double_width_reference() -> void:
    var capture_script := _read("res://tests/smoke/capture_responsive.gd")
    check(capture_script.contains("Vector2i(390, 844)"), "Phone Web reference")
    check(capture_script.contains("Vector2i(900, 900)"), "Double-width desktop Web reference")
    equal(
        ProjectSettings.get_setting("display/window/stretch/mode"),
        "canvas_items",
        "Responsive canvas-item scaling"
    )
    equal(
        ProjectSettings.get_setting("display/window/stretch/aspect"),
        "expand",
        "Browser viewport expands without distortion"
    )


func _read(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    check(file != null, "File must open: %s" % path)
    return "" if file == null else file.get_as_text()
