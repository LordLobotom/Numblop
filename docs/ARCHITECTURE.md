# Numblop Architecture

## Principles

The learning model is pure and deterministic; Godot scenes are views; autoloads coordinate local
application state. This keeps educational behavior testable without rendering and makes Android
lifecycle events unable to corrupt mastery logic.

Three rules follow from that and are enforced by review and tests:

1. `scripts/core/` has no scene, autoload, filesystem, clock, locale, or platform dependency.
   Randomness always takes an explicit seed, and timestamps are passed in by the caller.
2. UI displays state. It never calculates mastery, session quotas, rewards, or unlocking.
3. Only `AppState` writes saves during play.

## Folders

```text
scenes/                 Composed screens and reusable UI scenes
scripts/core/           Pure learning model, deterministic session generation, achievement catalog
scripts/app/            Application services and persisted models; no scenes, no autoload access
scripts/autoload/       EventBus, settings, saves, and current local app state
scripts/ui/             Scene presentation and input handling
localization/           Source translation catalog
ui/                     Theme, fonts, icons, branding, shaders, and UI-native assets
addons/                 Vendored third-party plugins; never edited in place
tests/core/             Learning rules, generator, and catalog tests
tests/state/            Persistence, lifecycle, and app-state tests
tests/ui/               Scene contract and interaction tests
tests/smoke/            Catalog, project, capture, and export-facing smoke tests
tools/                  Repeatable QA, capture, device, and export commands
```

## Core model — `scripts/core/`

- `LearningRules` owns tables, thresholds, question modes, response-time limits, score deltas, and
  round length. `SESSION_LENGTH` is 10 and `EXTENDED_SESSION_LENGTH` is 12 from `EXTENDED_MIX_TABLE`
  (`6`) onwards. `REVIEW_MASTERY` (100) is deliberately distinct from `AUTOMATED_MASTERY` (90): the
  first decides how often a fact comes back, the second decides how it is asked.
- `LearningProfile` owns all 80 mastery values, all 80 `last_practiced` stamps, and the highest
  unlocked table. Unlocking is monotonic and re-derived on load; mastery remains allowed to decrease.
  The stamps are supplied by the caller, never read from a clock here.
- `SessionGenerator` creates deterministic `PracticeQuestion` objects from a supplied seed: 10 up to
  the 5× table (7 current, 2 older weak, 1 older automated) and 12 from the 6× table onwards
  (8 current, 3 older weak, 1 older automated). Unavailable review slots fall back to the current
  table. The automated slot picks the longest-waiting fact by `last_practiced`; every other slot picks
  the lowest mastery.
- `PracticeQuestion` is immutable-by-convention session data: fact, mode, choices, answer.
- `SessionResult` records the round: per-answer audit records, correctness counts, and the per-fact
  mastery gains the end-of-round page presents.
- `AchievementCatalog` defines and evaluates every achievement from supplied statistics plus a
  profile. It is pure, so the same statistics always produce the same progress. It restates the paid
  cosmetic count per category rather than importing `CosmeticCatalog`, and a test pins the two
  together.
- `DotVisualization` solves the domino-dot decomposition and layout for the wrong-answer correction
  for all 80 facts.

## Application services — `scripts/app/`

These are plain `RefCounted` models and services. They own rules that are not learning rules and
must not live in a scene, but they do not read files or drive the frame loop either.

- `SessionController` runs one round on top of `SessionGenerator` and `SessionResult`, applies each
  answer to the profile, supplies the clock value for `last_practiced`, triggers the per-answer save
  through an injected callable, and emits table-unlock signals.
- `LocalProgress` owns coins, XP, level, the completed-round counter, the completed-round reward, the
  5-coin mastery-milestone bonus, and achievement coin payouts.
- `LocalCosmetics` validates owned and equipped items across six categories against `CosmeticCatalog`.
- `LocalStreak` validates the active streak and the strictly increasing record milestones. It takes
  the timestamp and timezone offset from the caller.
- `LocalAchievements` records which achievement rewards have already been paid out. That granted set
  is the single guard that makes a reward one-time.
- `LocalOnboarding` holds the tutorial's `completed` flag and resumed `step`.
- `LocalNickname` sanitises the optional nickname (control characters stripped, max 16 characters).
- `LocalCloudSync` holds the Play Games synchronisation bookkeeping: the confirmed account binding,
  last acknowledged local counter, and acknowledgement time.
- `CoinLedger` is pure, static coin accounting: the two stored lifetime buckets plus achievement
  earnings and cosmetic spending, both *derived* from sets rather than stored. A balance cannot be
  merged between two devices; these four terms can.
- `SaveMigration` brings a loaded save dictionary up to the current schema in memory. It exists for
  the changes field tolerance cannot cover — a field whose value must be computed from other fields.
- `CloudSaveMerge` reconciles two saves of the same profile into one. Pure and static, so the code
  that could silently destroy a childhood of practice is provable without a device or a network. It
  is commutative except for this device's own identity, monotonic on everything earned, and
  recomputes the balance through `CoinLedger` rather than carrying it.
- `CosmeticCatalog` defines stable local item ids, prices, display keys, palette colors, and the
  authoring rectangle each accessory is framed by.
- `LanguageCatalog` is the single list of shipped languages, used by `SettingsManager` to validate a
  preference and by both the opening and settings screens to build their flag buttons.

## Autoloads — `scripts/autoload/`

- `EventBus` contains cross-screen domain signals only.
- `SettingsManager` owns `user://settings.cfg`: the language preference, music/SFX volume, global
  mute, and the haptics toggle. It resolves `system` to the device language when Numblop ships it,
  applies the locale to `TranslationServer`, applies volume through separate `Music` and `SFX` audio
  buses, and is the only caller of `Input.vibrate_handheld`.
- `SaveManager` owns `user://profile.json` serialization. Every write rewrites the whole file, and any
  argument a caller omits is re-read from disk first, so no save path can drop another system's data.
  Writes go through a temporary file and two atomic renames, keeping the previous save as a backup
  that loading falls through to; unknown fields written by a newer build are preserved.
- `AppState` owns the loaded `LearningProfile`, the `SessionController`, and every `Local*` model. It
  chooses runtime random seeds, so the deterministic generator never has to. It projects capped
  aggregate mastery and per-fact bands into read-only map-stage progress, projects the cosmetics
  catalog and inventory for the shop, projects achievements for the Trophies screen, and forwards
  domain events. When an answer moves a fact upward across the 60, 80, or 90 band it asks
  `LocalProgress` for the 5-coin bonus before the normal per-answer save, then exposes a one-answer
  presentation dictionary to the practice UI. Achievement grants are evaluated after every answer,
  every purchase, and every finished round; the coins are banked immediately while the celebration is
  queued for the next end-of-round page.

- `PlayGames` is the only file that knows Play Games Services exists. It wraps the vendored
  `addons/GodotPlayGameServices` plugin, resolving it by node path and script path rather than by
  `class_name`, so removing the addon leaves this file parsing and simply reporting unavailable.
  Cloud save is on by default: on Android it initialises at startup and checks the existing session,
  and Google — with Family Link for supervised children — owns the account decision rather than any
  gate of Numblop's own. Everywhere else `available()` is false and every method returns
  immediately. A failed or refused sign-in changes nothing about the game. A test walks
  `scripts/core/`, `scripts/app/`, `scripts/ui/` and `scenes/` and fails if anything except the
  Settings screen references it. On sign-in it loads the fixed `numblop_profile_v1` snapshot,
  refuses newer schemas, writes a `.premerge` recovery copy before combining two progressed saves,
  persists the pure `CloudSaveMerge` result, reloads `AppState` through a provider-neutral method,
  and uploads asynchronously. A dispatched upload is acknowledged only after an exact read-back.
  Three consecutive read-back mismatches block uploads for the launch instead of retrying after
  every answer indefinitely.
  The current vendored plugin cannot resolve a Play conflict id; that path merges both candidates
  locally and blocks further uploads for the launch rather than overwriting either side. Because
  the server conflict persists, Settings exposes the blocked state instead of presenting backup as
  healthy.

Milestone and achievement rewards never enter the deterministic learning core. No game rule waits on
a network call.

## Persistence

Two files: `user://profile.json` for everything the child earned, and `user://settings.cfg` for
device preferences. Compatibility comes from field-tolerant loaders plus an explicit `SaveMigration`
step for the fields that must be computed rather than defaulted.

The current save version is `10`. **Every field, every write path, the durability guarantees, the
migration history, and the coin ledger are documented in [`SAVE_SYSTEM.md`](SAVE_SYSTEM.md)** — that
file is the contract; do not restate its field list here.

## UI and display

- Logical portrait viewport: 390 × 844.
- Android orientation: locked portrait.
- Desktop override: 450 × 900, centered on the usable monitor area.
- Web export: adaptive browser canvas with 390 × 844 phone and 900 × 900 wide-desktop QA references.
  `canvas_items` plus `expand` preserves the logical scale while containers use the additional width;
  centered content such as the map and cosmetics grids does not stretch. `CenteredContentMargin`
  applies the shared 540 px readable column on wide displays.
- Web uses the threadless Godot template and WebGL 2 through the Compatibility renderer. It is a
  static build with no backend, PWA, remote configuration, or gameplay networking.
- Renderer: GL Compatibility for broad 2D Android hardware support.
- Layout uses Control containers and must tolerate narrow/tall safe areas. Touch targets are at
  least 48 px.
- Number-entry questions use an in-game numeric keypad, not the platform soft keyboard.
- `TouchScrollContainer` lets a drag that begins on a child control take over the gesture and scroll
  the page, cancelling the child's press. Scrollbars are hidden. The takeover distance comes from the
  project's `gui/common/default_scroll_deadzone`.
- All four navigation screens share one header shape: a `SafeArea/Content/Header` PanelContainer on
  `ui/styles/header_panel.tres` with a 52 px title card. The headers are intentionally *not* an
  instanced component, because `unique_name_in_owner` resolves against the owner and would break.
  `tests/ui/test_main_scene.gd` pins the shared size and face instead.
- The stage map consumes `AppState` presentation dictionaries. Partial mastery moves its progress
  bars and an unlock event reveals the next island, without giving UI code authority over the rule.
  Unlocked islands open a localized ten-fact detail whose bands render red, purple, orange, green.
  The winding canvas stays 350 px wide inside a centering container.
- The Cosmetics screen consumes an `AppState` catalog/inventory projection across six categories. A
  palette shader recolors body, arm, and leg pixels and a second mask recolors the belly, both
  preserving facial layers and outlines. Supplied accessories keep their 768 × 768 authoring
  coordinates: their layer spans 150 % of the 512 × 512 character bounds, starting at −25 %
  horizontally and −175/512 vertically. A necklace-only shader clips stray transparent-source pixels
  above the authored region without modifying the PNGs.
- The home screen presents coins, XP, level, and streak in one shared bar, plus the optional nickname
  pill. The Trophies screen is a read-only projection: the best streak, timestamped record
  milestones, and achievement cards with progress and coin reward. UI code formats stored timestamps
  but never decides which answers extend a streak or qualify as a record.
- Correct-answer feedback may present an `AppState`-supplied mastery milestone. It localizes the new
  band and plays the level-up and coin cues, but does not calculate thresholds or mutate progression.
- The end-of-round page reveals the mastery summary, the chest, and an itemised reward breakdown
  (round, mastery bonus, achievements, total) step by step, then holds until the auto-return or a tap.
- `OnboardingTutorial` is a sibling overlay in `Main.tscn` that drives a finger through the whole
  loop. It resolves its targets through accessors the screens expose, so it never reaches into their
  internals, and it records its step through `AppState` so a restart resumes there.

## Localization

`localization/strings.csv` is the only source catalog, with one column per shipped language. Godot
imports one translation resource per language. UI scripts may format translated keys but never
assemble translated sentences from fragments. See [`LOCALIZATION.md`](LOCALIZATION.md).

## Testing flow

`tools/run-tests.ps1` first imports the project headlessly, then runs `tests/run_tests.gd`. The runner
discovers track-specific tests, awaits each one so gestures can be exercised across real frames, and
fails non-zero on any recorded assertion.

Scene and layout changes additionally require a headless boot (`--headless --path . --quit-after`),
because tests instantiate scenes but never run a real layout pass — a container recursion crash
passes the suite undetected. UI and export work also require responsive screenshots and a real
artifact or device check appropriate to the change.
