# Release Workflow

## Identity and orientation

- Android package: `cz.gutcloud.numblop` — permanent; do not change after publishing.
- Android: portrait-only.
- Windows: x86-64 centered portrait window.
- Web: adaptive static canvas; phone view fits the available viewport and 900×900 is the wide
  desktop QA reference.
- The public version comes from `application/config/version` (currently `0.5.1`) and stays
  aligned with the Android version name and the Windows product version. All three are pinned by
  `tests/smoke/test_project_contract.gd`; bump them together. There is a fourth place the contract
  also checks — `application/file_version` in the Windows preset — so a bump touches
  `project.godot`, both Android presets, and both Windows version fields.
- The Play version code (currently `23`) is pinned by the same test but moves on its own: every
  upload needs a higher code, including a re-upload of an unchanged version name.
- Android SDK levels: Min SDK `24`, Target SDK `36`, pinned in the Android Release preset and by
  the same contract test.
- Privacy policy URL for Play Console, the store listing, and Settings:
  `https://numblop.gutcloud.cz/en/privacy/` and `https://numblop.gutcloud.cz/cs/privacy/`, published
  from the `numblop-landing` repository. `docs/privacy/index.md` is the bilingual source text that
  the site content is kept in step with; it is not itself served anywhere. Both public pages must
  return HTTP 200 before release.

## App icons

Every launcher and application icon derives from one source set:

- `ui/branding/numblop_mascot_full_512.png` — the complete opaque 512×512 icon.
- `ui/branding/numblop_mascot_512.png` — the transparent 512×512 adaptive foreground.
- `ui/branding/numblop_mascot_bg_512.png` — the plate artwork behind it.

All three are inputs only. Regenerate everything after changing any of them:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate-app-icons.ps1
```

The tool overwrites `ui/branding/numblop_ico.png` (Windows executable, editor, project icon), the
four `ui/branding/android/icon_*.png` layers and `store/icon_512.png` (the Play Console listing
icon) in place, so paths, UIDs and `.import` files stay valid and neither `export_presets.cfg` nor
the contract test changes.

The adaptive foreground is fitted **radially**, not by bounding box: the mascot is scaled so no
drawn pixel sits further than 132 px from the centre of the 432 px canvas, which is Android's 66/108
safe zone. A launcher mask cuts by distance from the centre, so the pixel at risk is a head or foot
tip rather than a bbox corner — bounding the box alone would let a circular mask clip the mascot.
The themed monochrome glyph is cut from that same fitted foreground, so it always tracks the icon;
its light areas (belly, eye whites) are knocked out of the alpha because Android keeps only alpha
and would otherwise render one featureless blob. The Windows icon, Android legacy icon, and Play
listing icon derive directly from the supplied full composition; Windows bakes rounded corners
into its copy, since desktop applies no mask of its own, while the listing stays square and opaque
as the Console requires.

Review the regenerated PNGs before committing.

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
cross-origin isolation headers. PWA support is intentionally disabled. The game has no backend or
remote gameplay dependency; browser save data remains local to the site's origin, so changing the
hostname or clearing site data creates a fresh local profile.

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
   Spot-check German and Finnish for the longest strings overflowing a button.
3. On a fresh install, follow the guided finger tutorial end to end; then kill the app mid-tutorial
   and confirm it resumes on the step it stopped at, and never replays once completed. Leave the
   shop **without buying anything** at least once and confirm the finger moves on to Home.
4. Stroke the blob and confirm the happy face, heart, and animation respond without requiring sound.
   A plain tap must do nothing.
5. Open Settings; switch languages, adjust both volume bars, verify mute, toggle haptics off and
   confirm the chest no longer buzzes, cancel one Close game confirmation, then confirm it.
6. Complete one full series, including four choices, six choices, and the numeric keypad.
7. Make one intentional mistake; confirm the full correct equation and the domino dot picture appear,
   that Continue is withheld until the picture completes, and that it then waits for a tap.
8. Tap the chest once; confirm one shake with a real haptic buzz, one opening, the mastery summary,
   the itemised reward breakdown, the coin/XP count-up, and the return to updated home totals.
9. Drag-scroll the Cosmetics, Trophies, Settings, and Map screens starting the drag on top of a
   button or slider; the page must scroll and the control must not activate.
10. Start another series, answer at least once, switch apps, and return; the unfinished series must
    be gone while the processed mastery remains saved and no reward is added.
11. Force-stop and relaunch; mastery, language, audio and haptics preferences, coins, experience,
    level, streak, achievements, and owned/equipped cosmetics must remain intact.

## Release AAB signing

Target SDK 36 needs the matching platform in the local Android SDK. Install it once:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "platforms;android-36"
```

Godot 4.6.2 ships a Gradle build template pinned to compile SDK 35 and Android Gradle Plugin
8.6.1, so a target of 36 would fail the build. `tools/patch-android-template.ps1` raises
`compileSdk`/`targetSdk`/`minSdk` in `android/build/config.gradle` and sets
`android.suppressUnsupportedCompileSdk` in `android/build/gradle.properties`. It is idempotent
and `tools/export.ps1 -Target android-release` runs it automatically on every export, because
`android/` is ignored and Godot overwrites it whenever the template is reinstalled. Build tools
`35.0.1` stay as shipped; AGP 8.6.1 builds compile SDK 36 with them.

Generate the production keystore once, outside the repository, and back it up securely. Losing
it can prevent updates to the published application. Do not commit its path, alias, or password.

There are two ways to produce the signed bundle. Both end at `build/Numblop.aab`.

### What the tools discover for themselves

Only one thing genuinely has to be configured — **where the keystore is**:

```powershell
setx GODOT_ANDROID_KEYSTORE_RELEASE_PATH "C:\path\to\numblop-upload.jks"
```

It holds no secret, and `setx` only reaches processes started afterwards, so open a new shell.
From there both scripts fill in the rest:

- **The password file** is looked for at `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD_FILE`, then
  beside the keystore under the same base name — `numblop-upload.jks` → `numblop-upload.pwd`.
  Finding nothing is not an error; `sign-aab.ps1` falls back to prompting exactly as before.
- **The alias** comes from `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, or is read out of the keystore
  itself with `keytool`, which needs no configuration because a keystore knows its own alias. Only
  when the keystore holds exactly one key — otherwise picking one is not the script's decision, and
  it asks.

So the routine case is argument-free:

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-release
```

Every explicit parameter still wins over what would have been discovered.

### Export unsigned, then sign interactively (preferred)

The password is never placed in an environment variable, a file, or the shell history —
`jarsigner` prompts for it and does not echo it.

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-release-unsigned
powershell -ExecutionPolicy Bypass -File tools/sign-aab.ps1 `
    -KeystorePath "C:\path\to\numblop-upload.jks" -Alias "<alias>"
```

`sign-aab.ps1` signs in place and then runs `verify-aab.ps1` itself, so a successful run ends
with `NUMBLOP_AAB_VERIFY_OK` followed by `NUMBLOP_AAB_SIGN_OK`. jarsigner prints
`The signer's certificate is self-signed` and a missing-timestamp warning on every run: a Play
upload key is required to be self-signed and Play does not need a timestamp, so both are expected.
`verify-aab.ps1` treats exactly those two `-strict` findings as normal and still fails on any
other, such as an unsigned entry or a mismatched alias.

To skip the prompt, store the password once, encrypted with Windows DPAPI, **outside the
repository**:

```powershell
powershell -ExecutionPolicy Bypass -File tools/save-keystore-password.ps1 `
    -PasswordFile "C:\path\to\numblop-upload.pwd"
```

The ciphertext only decrypts under the Windows account and machine that wrote it, so a copied
file is worthless. `save-keystore-password.ps1` refuses to write anywhere inside the repository.
Then pass `-PasswordFile` to the signing step:

```powershell
powershell -ExecutionPolicy Bypass -File tools/sign-aab.ps1 `
    -KeystorePath "C:\path\to\numblop-upload.jks" -Alias "<alias>" `
    -PasswordFile "C:\path\to\numblop-upload.pwd"
```

The password is handed to jarsigner through `-storepass:env` with a process-scoped variable that
is cleared in a `finally` block, so it never appears on a command line or in a process listing.
It is still only a convenience: the encrypted file does not survive a Windows reinstall, so keep
the password itself in a password manager. It refuses to sign a bundle that
already carries a signature — re-export instead, because stacked signature blocks are rejected by
Play. `-KeystorePath` and `-Alias` fall back to `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` and
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` when omitted; neither holds a secret.

The unsigned export needs `package/signed=false`, which Godot cannot override from the command
line. `export.ps1` therefore rewrites only that one line in the Android Release options block for
the duration of the build and restores `export_presets.cfg` verbatim afterwards, so the committed
preset never drifts.

### Export and sign in one step

Godot signs during the export when it finds the keystore environment variables. With the
encrypted password file above, one command produces the finished bundle:

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-release `
    -KeystorePath "C:\path\to\numblop-upload.jks" -Alias "<alias>" `
    -PasswordFile "C:\path\to\numblop-upload.pwd"
```

The three parameters only populate process-scoped environment variables and the password one is
cleared in a `finally` block, so nothing persists in the calling shell. They apply to
`android-release` only; passing them to another target fails immediately. Verify afterwards with
`tools/verify-aab.ps1` — the export does not run it.

Without the parameters the variables must already be set, in the release shell or a secure CI
secret store:

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

## Verify the AAB

After a release export, verify the bundle before uploading:

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify-aab.ps1
```

The tool checks the bundle structure (manifest, dex, both ABIs' native libraries), verifies the
upload signature with `jarsigner`, and — when `NUMBLOP_BUNDLETOOL_JAR` points at a
`bundletool-all-<version>.jar` downloaded once from `github.com/google/bundletool/releases` —
asserts the merged manifest: package id, version code/name, `VIBRATE`, `INTERNET`, and
`ACCESS_NETWORK_STATE` present, `allowBackup="true"`, and no advertising-id, location, camera,
microphone, or contacts permission. Success prints `NUMBLOP_AAB_VERIFY_OK`.

## Release checklist

1. Full tests pass; every language column and the version values are reviewed.
2. Windows, Web, and debug APK export without script/export errors; Web HTTP smoke passes.
3. `tools/android-smoke.ps1` passes and the physical checklist above passes with networking disabled.
   With networking restored, a listed Play Games tester also signs in successfully and switching
   cloud save off returns the app to purely local behavior. On that signed-in device, finishing a
   round unlocks First Steps in the Play Games app, and a profile with offline progress shows its
   earned achievements after the first sign-in rather than starting from zero.
4. Save survives pause, force-stop, relaunch, and application update.
5. Signed AAB passes `tools/verify-aab.ps1` and is uploaded to an internal Play test track.
6. Store listing, screenshots, content rating, data-safety answers, Families/target-audience answers,
   and privacy text match the Play Games build. The policy and declarations are updated before the
   first networking build reaches any Play track.
7. Play Console assets in `store/` are current: `icon_512.png`, `feature_graphic_1024x500.png`,
   `screenshots/`, `listing/`, and — once achievements are configured — the 25 icons in
   `store/achievements/`. That folder carries a `.gdignore` and is excluded from every export
   preset, so it is uploaded by hand and never reaches a build. Regenerate it together with
   `ui/achievements/` through `tools/resize-achievement-icons.ps1` whenever the art is redrawn.
