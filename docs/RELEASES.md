# Release Workflow

## Identity and orientation

- Android package: `cz.gutcloud.numblop` — permanent; do not change after publishing.
- Android: portrait-only.
- Windows: x86-64 centered portrait window.
- Version starts at code `1`, name `0.1.0`.

## Development artifacts

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target windows
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-debug
```

Outputs are `build/Numblop.exe` (+ PCK) and `build/Numblop-debug.apk`. Build products are ignored.
The debug APK uses Godot's local debug keystore and must never be uploaded as a store release.

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
2. Windows and debug APK export without script/export errors.
3. Debug APK installs and runs on a physical phone with networking disabled.
4. Save survives pause, force-stop, relaunch, and application update.
5. Signed AAB is verified and uploaded to an internal Play test track.
6. Store listing, screenshots, content rating, data-safety answers, and privacy text match the
   actual offline/no-data-collection behavior.
