# Numblop

Numblop is an offline, adaptive multiplication-practice game built with Godot 4.6.2.
The Android app is portrait-only; the Windows build uses the same centered portrait
experience. English and Czech are supported from the first playable version.

## Current foundation

- One local child profile; no accounts, analytics, advertisements, or cloud services.
- Mastery tracked separately for all facts in the 2–9 multiplication tables.
- Deterministic 10-question session generation with no immediate duplicate facts.
- Localized portrait home screen and persistent language preference.
- Headless learning, persistence, localization, and scene smoke tests.
- Windows, Android debug APK, and Android release AAB presets.

## Run

```powershell
C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64.exe --path .
```

## Test

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1
```

## Export

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target windows
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-debug
```

Release AAB signing is intentionally supplied through environment variables, never
committed files. See `docs/RELEASES.md`.

## Source of truth

Read `AGENTS.md` for the documentation hierarchy and repository workflow. The canonical
learning rules are in `docs/didactic_algorithm.md`.
