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
- `SettingsManager` owns `user://settings.cfg`, applies `system`, `en`, or `cs` locale, and applies
  persisted music/SFX volume and global mute through separate `Music` and `SFX` audio buses.
- `SaveManager` owns versioned `user://profile.json` serialization.
- `CosmeticCatalog` defines stable local item IDs, prices, display keys, and palette colors;
  `LocalCosmetics` validates owned and equipped items without accessing scenes or files.
- `LocalStreak` validates the active streak and strictly increasing record milestones without
  accessing clocks, scenes, or files. `AppState` supplies the system timestamp and timezone offset
  when an incorrect answer interrupts a streak.
- `AppState` owns the loaded `LearningProfile` and active question session. Runtime random
  seeds are chosen here, outside the deterministic generator. It projects capped aggregate
  mastery plus each fact's mastery band into read-only map-stage progress and forwards table-unlock
  domain events; scenes never calculate mastery or decide unlocking.

## Save contract

Version 5 contains:

```json
{
  "version": 5,
  "highest_unlocked_index": 0,
  "mastery": { "2_x_0": 0 },
  "coins": 0,
  "experience": 0,
  "cosmetics": {
    "unlocked_body_colors": ["green"],
    "selected_body_color": "green",
    "unlocked_hats": ["hat_none"],
    "selected_hat": "hat_none",
    "unlocked_glasses": ["glasses_none"],
    "selected_glasses": "glasses_none"
  },
  "streak": {
    "current_count": 0,
    "all_time_high": 0,
    "milestones": [
      { "count": 12, "ended_at_unix": 1785765600, "utc_offset_minutes": 120 }
    ]
  }
}
```

All earlier save versions remain valid. Missing or malformed fields use safe defaults, including free
green cosmetics and an empty streak. Unlock progress is never decreased when loading. Every
mastery, streak update, reward, purchase, and equip save preserves the other local state fields.

## UI and display

- Logical portrait viewport: 390 × 844.
- Android orientation: locked portrait.
- Desktop override: 450 × 900, centered on the usable monitor area.
- Renderer: GL Compatibility for broad 2D Android hardware support.
- Layout uses Control containers and must tolerate narrow/tall safe areas.
- Number-entry questions use an in-game numeric keypad, not the platform soft keyboard.
- The stage map consumes `AppState` presentation dictionaries. Partial mastery moves its progress
  bars, and an unlock event can reveal the next island without giving UI code authority over the
  learning rule. Unlocked islands are touch targets that open a bilingual ten-fact detail. The
  winding canvas remains 350px wide inside a centering container so wider portrait windows add
  balanced side space instead of stretching the trail.
- The Cosmetics screen consumes an `AppState` catalog/inventory projection. A palette shader
  recolors only body, arm, and leg pixels while preserving facial layers, outlines, and the belly.
  Supplied accessories keep their 768×768 authoring coordinates: their layer spans 150% of the
  512×512 character bounds. It starts at −25% horizontally and −175/512 vertically after the
  shared accessory layer was visually tuned. Hats may extend above the
  base canvas while glasses remain aligned with the eyes.
- The home screen presents coins, XP, level, and streak in one shared bar. The Trophies screen is a
  read-only projection of `LocalStreak`; UI code formats stored timestamps but never decides which
  answers extend a streak or qualify as a record.

## Localization

`localization/strings.csv` is the only source catalog. Godot imports one translation resource
per language. UI scripts may format translated keys, but never assemble translated sentences
from English fragments.

## Testing flow

`tools/run-tests.ps1` first imports the project headlessly, then runs
`tests/run_tests.gd`. The runner discovers track-specific tests and fails non-zero on any
recorded assertion. UI and export work additionally require responsive screenshots and a real
artifact/device check appropriate to the change.
