# Numblop Architecture

## Principles

The learning model is pure and deterministic; Godot scenes are views; autoloads coordinate
local application state. This keeps educational behavior testable without rendering and
makes Android lifecycle events unable to corrupt mastery logic.

## Folders

```text
scenes/                 Composed screens and reusable UI scenes
scripts/core/           Pure learning model and deterministic session generation
scripts/autoload/       EventBus, settings, saves, and current local app state
scripts/ui/             Scene presentation and input handling
localization/           Source translation catalogs
ui/                     Theme, icon, and UI-native assets
tests/core/              Learning rules and session tests
tests/state/             Persistence and state tests
tests/ui/                Scene contract tests
tests/smoke/             Catalog, project, and export-facing smoke tests
tools/                   Repeatable QA and export commands
```

## Core model

- `LearningRules` owns tables, thresholds, modes, response-time limits, and score deltas.
- `LearningProfile` owns all 80 mastery values and the highest unlocked table. Unlocking is
  monotonic; mastery remains allowed to decrease.
- `SessionGenerator` creates exactly 10 deterministic `PracticeQuestion` objects from a
  supplied seed. Its fixed slot plan is 7 current, 2 older weak, and 1 older automated;
  unavailable review slots use the current table.
- `PracticeQuestion` is immutable-by-convention session data: fact, mode, choices, answer.

Core scripts never access nodes, singletons, files, time, locale, or platform APIs.

## Application state

- `EventBus` contains cross-screen domain signals only.
- `SettingsManager` owns `user://settings.cfg` and applies `system`, `en`, or `cs` locale.
- `SaveManager` owns versioned `user://profile.json` serialization.
- `AppState` owns the loaded `LearningProfile` and active question session. Runtime random
  seeds are chosen here, outside the deterministic generator.

## Save contract

Version 1 contains:

```json
{
  "version": 1,
  "highest_unlocked_index": 0,
  "mastery": { "2_x_0": 0 }
}
```

Missing or malformed fields use safe defaults. Unlock progress is never decreased when
loading. Future migrations branch on `version` and preserve existing mastery.

## UI and display

- Logical portrait viewport: 390 × 844.
- Android orientation: locked portrait.
- Desktop override: 450 × 900, centered on the usable monitor area.
- Renderer: GL Compatibility for broad 2D Android hardware support.
- Layout uses Control containers and must tolerate narrow/tall safe areas.
- Number-entry questions use an in-game numeric keypad, not the platform soft keyboard.

## Localization

`localization/strings.csv` is the only source catalog. Godot imports one translation resource
per language. UI scripts may format translated keys, but never assemble translated sentences
from English fragments.

## Testing flow

`tools/run-tests.ps1` first imports the project headlessly, then runs
`tests/run_tests.gd`. The runner discovers track-specific tests and fails non-zero on any
recorded assertion. UI and export work additionally require responsive screenshots and a real
artifact/device check appropriate to the change.
