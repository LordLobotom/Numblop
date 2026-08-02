# Release Workflow

## Identity and orientation

- Android package: `cz.gutcloud.numblop` — permanent; do not change after publishing.
- Android: portrait-only.
- Windows: x86-64 centered portrait window.
- Web: adaptive static canvas; phone view fits the available viewport and 900×900 is the wide
  desktop QA reference.
- Version starts at code `1`, name `0.1.0`.

## Development artifacts

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target windows
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-debug
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target web
```

Outputs are `build/Numblop.exe` (+ PCK), `build/Numblop-debug.apk`, and `build/web/`. Build products
are ignored. The debug APK uses Godot's local debug keystore and must never be uploaded as a store
release.

## Web export and smoke test

Install the two threadless Godot 4.6.2 Web templates if they are not already present, export, and
verify the static file set and MIME types:

```powershell
powershell -ExecutionPolicy Bypass -File tools/install-web-templates.ps1
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target web
powershell -ExecutionPolicy Bypass -File tools/web-smoke.ps1 -SkipExport
```

For a manual browser check, double-click `tools/start-web.cmd`, or run
`tools/serve-web.ps1 -Open`. Keep its terminal open while playing and press Ctrl+C to stop. Never
open `build/web/index.html` through `file://`: browsers will block the required `.wasm` and `.pck`
fetches. Check at 390×844 and 900×900. The canvas must fill the available mobile viewport; on
desktop the navigation and full-width panels may expand, while the map trail, practice controls,
dialogs, and item grids remain centered and readable.

Deploy the complete `build/web/` directory through HTTPS with `.wasm` served as
`application/wasm` and `.pck` as `application/octet-stream`. The threadless preset avoids requiring
cross-origin isolation headers. PWA support is intentionally disabled for M1. The game has no
backend or remote gameplay dependency; browser save data remains local to the site's origin, so
changing the hostname or clearing site data creates a fresh local profile.

## Physical Android smoke test

Connect one unlocked Android phone with USB debugging authorized, then run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/android-smoke.ps1
```

The command exports the debug APK, installs it with update-compatible flags, force-stops any old
process, launches `cz.gutcloud.numblop`, verifies the activity and process, and writes PID-filtered
logs to ignored `artifacts/android-smoke/`. Pass `-DeviceSerial <serial>` when several devices are
connected, or `-SkipExport -ApkPath <path>` to validate an existing debug APK.

Complete this checklist on the phone while it remains disconnected from Wi-Fi and mobile data:

1. Confirm the opening and home remain portrait, fill the safe area, and show no clipped text.
2. Select English, relaunch, then select Czech and relaunch; each remembered choice must persist.
3. Pet the blob and confirm the happy face, heart, and animation respond without requiring sound.
4. Open Settings; switch languages, adjust both volume bars, verify mute, cancel one Close game
   confirmation, then confirm Close game and relaunch.
5. Complete one 10-question series, including four choices, six choices, and the numeric keypad.
6. Make one intentional mistake; confirm the full correct equation remains until Continue is tapped.
7. Tap the chest once; confirm one shake/haptic, one opening, a +10 coin/+10 XP count-up,
   and the final tap back to the updated home totals.
8. Start another series, answer at least once, switch apps, and return; the unfinished series must
   be gone while the processed mastery remains saved and no reward is added.
9. Force-stop and relaunch; mastery, language, audio preferences, coins, experience, and level must
   remain intact.

## Release AAB signing

Generate the production keystore once, outside the repository, and back it up securely. Losing
it can prevent updates to the published application. Do not commit its path, alias, or password.

Set these only in the release shell or secure CI secret store:

```powershell
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "C:\secure\numblop-release.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "numblop"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "<secret>"
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-release
```

The output is `build/Numblop.aab`. `tools/export.ps1` asks Godot to install the project-local
Gradle build template when needed. Generated `android/build/` content is ignored until a future
task intentionally customizes and versions it. For scripted release exports, the helper disables
Gradle's background daemon to avoid a Windows redirected-output handle deadlock; interactive
Godot and Gradle settings are not changed.

## Release checklist

1. Full tests pass; both translations and version values are reviewed.
2. Windows, Web, and debug APK export without script/export errors; Web HTTP smoke passes.
3. `tools/android-smoke.ps1` passes and the physical checklist above passes with networking disabled.
4. Save survives pause, force-stop, relaunch, and application update.
5. Signed AAB is verified and uploaded to an internal Play test track.
6. Store listing, screenshots, content rating, data-safety answers, and privacy text match the
   actual offline/no-data-collection behavior.
