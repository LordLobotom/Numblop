# Numblop Tasks

Status values: `TODO`, `WIP(@agent)`, `BLOCKED(reason)`, `DONE`.

## Open work

Everything below this section is `DONE` and kept as a historical ledger of what each track built and
which files it owned. Only these remain open:

- `D2 BLOCKED(no authorized physical Android device connected)` Physical Android install/run/log
  smoke command and checklist. Depends: C3. Owns: `tools/`, `docs/RELEASES.md`, smoke tests.
- `D18 TODO` Release execution: generate the release keystore, export and verify the signed AAB,
  enable GitHub Pages, complete the physical-device checklist (unblocks D2), and upload to the Play
  internal test track. Depends: D2, D14–D17. Owns: release workflow (manual steps).

The next milestone after those is M5, Google Play Games Services. It has no task lines yet on
purpose: it starts from [`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md) and a decision entry, and its
tasks are written when that phase is actually approved.

**Reading this file:** it records what was built and by which track, not what the game does today.
For current behavior use [`GAME_DESIGN.md`](GAME_DESIGN.md), [`ARCHITECTURE.md`](ARCHITECTURE.md),
and [`SAVE_SYSTEM.md`](SAVE_SYSTEM.md); several entries below describe a save version or a catalog
that has since been superseded.

## Foundation

- `A0 DONE` Learning rules, 80-fact profile, deterministic session generator, core tests.
  Owns: `scripts/core/`, `tests/core/`.
- `B0 DONE` Portrait home scene, theme, localization catalog, UI contract test.
  Owns: `scenes/`, `scripts/ui/`, `ui/`, `localization/`, `tests/ui/`.
- `C0 DONE` Local settings, save manager, app state, persistence test.
  Owns: `scripts/autoload/`, `tests/state/`.
- `D0 DONE` Project configuration, runner, environment/export tools, presets, smoke test.
  Owns: `project.godot`, `export_presets.cfg`, `tools/`, `tests/run_tests.gd`,
  `tests/test_case.gd`, `tests/smoke/`.

## M1 tasks

- `A1 DONE` Session runtime/result model and per-answer audit records. Depends: A0.
  Owns: `scripts/core/SessionResult.gd`, `tests/core/test_session_result.gd`.
- `A2 DONE` Distractor-quality rules and edge-case tests for ×0, ×1, and repeated products.
  Depends: A0. Owns: `scripts/core/SessionGenerator.gd`, `tests/core/test_distractors.gd`.
- `A3 DONE` Prefer unique facts within each 10-question series and repeat only after a required
  adaptive pool is exhausted. Depends: A0. Owns: session generator and generator tests.
- `A4 DONE` Replace the table gate with the confirmed 9-of-10 facts at 80 mastery rule, including
  boundary and permanent-unlock tests. Depends: A0. Owns: learning rules/profile and core tests.
- `B1 DONE` Opening/logo scene, remembered language choice, bundled UI font, and license.
  Depends: B0. Owns: opening scene/script, `ui/fonts/`, localization keys, UI tests.
- `B2 DONE` Interactive blob home, idle/petting reactions, hearts, and coin/XP/level display.
  Depends: B1. Owns: home/blob scenes and scripts, UI tests.
- `B3 DONE` Practice screen for four- and six-choice modes. Depends: A0, B1.
  Owns: `scenes/screens/PracticeScreen.tscn`, `scripts/ui/PracticeScreen.gd`, UI tests.
- `B4 DONE` Custom numeric keypad and calm answer feedback, including the complete equation after
  a wrong answer. Depends: B3.
  Owns: keypad scene/script and UI tests.
- `B5 DONE` Single-tap chest, shake/open sequence, reward count-up, and automatic return-home flow.
  Depends: A1, B2, B4, C2. Owns: reward scenes/scripts, translation keys, UI tests.
- `B6 DONE` Home crest navigation, stage map, bold Play label, and audible music/SFX.
  Depends: B5, C4. Owns: home/map scenes and scripts, main UI flow, audio presentation,
  translation keys, and UI tests.
- `B7 DONE` Settings screen, four-crest navigation, and expanded interaction sound palette.
  Depends: B6, C5. Owns: settings scene/script, home/map navigation changes, audio-player
  presentation, localization keys, audio provenance, and UI tests.
- `B8 DONE` Continuous mastery progress on the map and bilingual next-island reveal flow.
  Depends: B6, C6. Owns: map/main presentation, localization keys, UI tests, responsive captures.
- `B9 DONE` Compact Cosmetics shop, body-color shader, supplied hat/glasses cards and aligned
  character layers, lock/check/coin treatment, purchase UI, and hanger navigation. Depends: B8,
  C7. Owns: cosmetic UI, shader, localization, and UI tests.
- `B10 DONE` Shared four-value home stats bar and bilingual Trophy milestone list. Depends: B9,
  C8. Owns: home/trophy/main UI, localization, and UI tests.
- `B11 DONE` Centered responsive stage trail and tappable bilingual ten-fact island detail.
  Depends: B8, C9. Owns: map scene/script, main back flow, localization, and UI tests.
- `B12 DONE` Add the supplied duck cap and three-necklace Cosmetics row with aligned 768px home
  rendering and artifact clipping. Depends: B9, C10. Owns: catalog/UI presentation, character
  layer, localization, shader, and UI tests.
- `B13 DONE` Apply red/yellow/gold/green fact-detail colors and replace the native exit prompt with
  a compact responsive themed overlay. Depends: B11. Owns: map/settings/main UI and UI tests.
- `B14 DONE` Center Cosmetics item grids within the wider Web layout while preserving the compact
  phone presentation. Depends: B9. Owns: Cosmetics scene and responsive artifacts.
- `B15 DONE` Center the Cosmetics, Trophy, and Settings content in a 540 px column on wide
  displays while preserving the existing phone margins. Owns: shared responsive UI margin,
  affected scenes, and UI tests.
- `B16 DONE` Clear retained answer focus, suppress sticky hover only on touch devices, and restart
  Web music inside the first user gesture for mobile-browser audio policies. Owns: practice/main
  UI and UI tests.
- `B17 DONE` Apply the shared centered 540 px wide-display layout to Home and Map so their top
  content, main content, and bottom navigation align with every other navigation screen. Owns:
  Home/Map scenes and responsive UI tests.
- `B18 DONE` Rename Czech mastery bands, use the red/purple/orange/green presentation, and show
  localized fact-milestone feedback with level-up and coin SFX. Owns: localization, practice/map
  UI, audio scene wiring, and UI tests.
- `B19 DONE` Keep mastery-milestone feedback visible for 3.6 seconds while allowing an early
  full-overlay tap to continue. Owns: practice feedback scene/script, localization, and UI tests.
- `B20 DONE` Show the localized public application version in the Settings header. Owns:
  settings scene/script, localization, and UI tests.
- `B21 DONE` Restructure fact-milestone feedback into a success title, prominent bold fact,
  standalone mastery-band name, and coin reward. Owns: practice scene/script, localization, and
  UI tests.
- `B22 DONE` Replace Web-fragile checkmark and legend-dot glyphs with drawn shapes, and present a
  sixth yellow body-color swatch in the compact Cosmetics row. Owns: UI scenes/scripts,
  localization, and UI tests.
- `C1 DONE` Session controller, per-answer mastery saves, and discard-on-interruption behavior.
  Depends: A1. Owns: `scripts/app/SessionController.gd`, autoload changes, state tests.
- `C2 DONE` Local coin/XP/level persistence and atomic application of the accuracy-linked M1
  reward. Depends: A1, C1. Owns: app state/save changes and state tests.
- `C3 DONE` Android pause/resume/back lifecycle handling. Depends: C1.
  Owns: app controller/autoload changes and state tests.
- `C4 DONE` Read-only map stage presentation state for the UI. Depends: C1.
  Owns: `scripts/autoload/AppState.gd` map-state contract and state tests.
- `C5 DONE` Persistent music/SFX volume and mute preferences with audio-bus application.
  Depends: C0. Owns: `SettingsManager`, audio settings signal/bus contract, and state tests.
- `C6 DONE` Didactic table-unlock event and continuous read-only map progress contract.
  Depends: A0, C1, C4. Owns: session/app coordination, domain signals, and state tests.
- `C7 DONE` Versioned local cosmetic inventory with atomic 100-coin body-color, hat, and glasses
  purchase/equip persistence. Depends: C2. Owns: catalog/state, save/app coordination, state tests.
- `C8 DONE` Persistent cross-series correct-answer streak and timestamped increasing-record history,
  saved atomically per answer. Depends: C1. Owns: streak model, save/app coordination, state tests.
- `C9 DONE` Read-only per-fact mastery-band projection for map island details, including a 99%
  pre-unlock display cap. Depends: C6. Owns: app-state map contract and state tests.
- `C10 DONE` Backward-compatible necklace ownership and equipped-state persistence in save version
  6. Depends: C7. Owns: local cosmetics, save/app projection, and state tests.
- `C11 DONE` Project the 9-of-10 gate into map completion state while retaining the tenth fact's
  real mastery value. Depends: A4, C9. Owns: app-state map projection and state tests.
- `C12 DONE` Detect upward 60/80/90 fact-band crossings in app state and atomically grant a
  separate 5-coin mastery milestone bonus before each answer save. Owns: local progress, app-state
  coordination, persistence tests, and the shared UI presentation dictionary.
- `C13 DONE` Add yellow to the persistent body-color catalog under the existing 100-coin contract.
  Owns: cosmetic catalog and state tests.
- `D1 DONE` Responsive screenshot smoke harness at 390×844 and 450×900. Depends: B3.
  Owns: QA scripts, smoke scenes/tests, `artifacts/` output contract.
- `D2 BLOCKED(no authorized physical Android device connected)` Physical Android install/run/log
  smoke command and checklist. Depends: C3.
  Owns: `tools/`, `docs/RELEASES.md`, smoke tests.
- `D3 DONE` Add the stage map to responsive portrait capture coverage. Depends: B6.
  Owns: responsive capture script, command, and harness test.
- `D4 DONE` Add Settings to responsive portrait capture coverage. Depends: B7.
  Owns: responsive capture script, command, and harness test.
- `D5 DONE` Add compact Cosmetics states and an equipped 768px accessory-alignment home state to
  bilingual responsive captures. Depends: B9. Owns: capture harness and artifact verification.
- `D6 DONE` Add the shared streak bar and populated Trophy history to bilingual responsive capture
  coverage. Depends: B10, C8. Owns: capture harness and artifact verification.
- `D7 DONE` Use the supplied Numblop branding icon for the project, Windows executable, and both
  Android launcher export presets. Owns: project/export icon configuration and smoke contract.
- `D8 DONE` Add the populated island fact detail to bilingual responsive captures at both portrait
  sizes. Depends: B11, C9. Owns: capture harness and artifact verification.
- `D9 DONE` Add a supplied duck-cap plus duck-necklace home alignment state and expanded Cosmetics
  catalog to bilingual responsive captures. Depends: B12, C10. Owns: capture harness and artifacts.
- `D10 DONE` Add the responsive custom exit confirmation to bilingual captures at both portrait
  sizes. Depends: B13. Owns: capture harness and artifacts.
- `D11 DONE` Refresh the root README with the current M1 loop, learning gate, local progression,
  QA/export commands, repository map, and documentation entry points. Owns: `README.md`.
- `D12 DONE` Add a threadless adaptive Web export, targeted template installer, static HTTP/MIME
  smoke server, and 390×844/900×900 responsive QA coverage. Owns: Web preset, `tools/`, smoke
  tests, release documentation, and responsive harness.
- `D13 DONE` Define the public application version in project configuration and verify that the
  Windows and Android export versions stay aligned. Owns: project configuration and smoke tests.

## M4 tasks

- `B23 DONE` Optional local nickname UI: home name pill, kid-friendly top-anchored name dialog
  with LineEdit and 48px+ actions, Android Back integration, localization, and the `home_name`
  responsive capture state. Depends: C14. Owns: home scene/script, main back flow, localization,
  UI tests, capture harness.
- `B24 DONE` Switch the primary typeface from Fredoka to Baloo 2 (variable + Noto Sans fallback,
  OFL bundled), keeping the bold 0.8-embolden variant and Czech glyph coverage. Owns: `ui/fonts/`,
  theme, scene font references, UI tests, docs.
- `B25 DONE` Add the supplied pirate eye patch to the glasses catalog under the 100-coin contract.
  Owns: cosmetic catalog, localization, and state tests.
- `B26 DONE` Belly-color row in the Cosmetics color tab: labeled body/belly swatch rows, shared
  swatch preview/purchase flow, and shader belly mask on the blob. Depends: C15. Owns: cosmetics
  scene/script, blob character, shader, localization, UI tests, capture harness.
- `C14 DONE` Save version 7: optional sanitized nickname (`LocalNickname`, max 16 chars) and a
  stable random `profile_id`, preserved across every save path and cleared on profile reset.
  Owns: save manager, app state, event bus, and state tests.
- `C15 DONE` Belly-color catalog (free cream + six 100-coin pastels) with backward-compatible
  cosmetics persistence in save v7. Owns: cosmetic catalog, local cosmetics, app state, state
  tests.
- `D14 DONE` Adaptive Android launcher icons (foreground/background/monochrome 432px), proper
  192px legacy icon, and branded boot splash. Owns: `ui/branding/android/`, project/export
  configuration, and smoke contract.
- `D15 DONE` Release manifest fixes: VIBRATE permission for the chest haptic, Android device
  backup enabled, and the 0.2.1 / version-code-2 bump across all presets. Owns: export presets,
  project configuration, smoke contract, `docs/RELEASES.md`.
- `D16 DONE` AAB verification tool (`tools/verify-aab.ps1`): structure, both ABIs, jarsigner
  signature, and optional bundletool manifest assertions. Owns: `tools/`, release documentation.
- `D17 DONE` Store submission kit: bilingual privacy policy for GitHub Pages (`docs/privacy/`),
  512px store icon, 1024×500 feature graphic, 9:16 store screenshot harness
  (`tools/capture-store.ps1` → versioned `store/screenshots/`), bilingual listing texts, and the
  repository LICENSE. Owns: `store/`, `docs/index.md`, `docs/privacy/`, capture harness, LICENSE.
- `D18 TODO` Release execution: generate the release keystore, export and verify the signed AAB,
  enable GitHub Pages, complete the physical-device checklist (unblocks D2), and upload to the
  Play internal test track. Depends: D2, D14–D17. Owns: release workflow (manual steps).
- `A9 DONE` Achievement catalog (first round, four streak tiers, one full-mastery island per
  table) and per-fact session mastery gains, both pure and deterministic. Owns: achievement
  catalog, session result, core tests.
- `B27 DONE` Steam-style Trophy tab: best-streak header and achievement cards with icon, title,
  description, progress, and coin reward. Depends: A9, C16. Owns: trophy UI, localization,
  UI tests.
- `B28 DONE` Unified end-of-round page around the single treasure chest: mastery gains above,
  chest in the middle, itemized coin rewards (round, mastery bonus, achievements, total) below,
  all revealed step by step, then held until the auto-return or a tap anywhere. Depends: B27.
  Owns: reward UI, localization, UI tests.
- `C16 DONE` Achievement persistence in save v8: once-only reward grants, the completed-session
  counter, and retroactive evaluation of existing saves on load. Depends: A9. Owns: local
  achievements, local progress, save manager, app state, state tests.
- `D19 DONE` Responsive captures for the island achievement list and the fully revealed
  end-of-round page. Depends: B28. Owns: capture harness, capture command, smoke tests.
- `A10 DONE` Deterministic dot-visualization decomposition and layout solver for the wrong-answer
  correction, with an exhaustive fit test across all 80 facts. Owns: `scripts/core/`, core tests.
- `B29 DONE` Domino dot correction moment on the wrong-answer feedback panel: drawn control,
  staggered reveal, continue withheld until the picture completes, bilingual hints. Depends: A10.
  Owns: practice scene/script, `scripts/ui/DotFactVisual.gd`, localization, UI tests.
- `D20 DONE` Responsive captures for the correction moment (typical 7×4 and the 9×9 worst case).
  Depends: B29. Owns: capture harness, capture command, smoke tests.

## M2 tasks

- `C17 DONE` Save v9 onboarding state (`completed` plus the resumed step), pre-v9 saves adopted
  as onboarded, and profile reset replaying the tutorial. Owns: local onboarding, save manager,
  app state, state tests.
- `B30 DONE` One-time guided finger tutorial over the whole loop, plus the target accessors the
  screens expose for it. Depends: C17. Owns: `scenes/Main.tscn`, `scripts/ui/OnboardingTutorial.gd`,
  practice/cosmetics/map target accessors, UI tests.
- `B31 DONE` Cosmetics color page fits the readable column (wrapped belly row, inset color-tab
  icon) and the Play caption sits on the pill face. Owns: cosmetics scene/script, home scene,
  UI tests.
- `B32 DONE` Drag-anywhere touch scrolling on every scrolling screen, with the child's press
  canceled once the gesture is taken over, plus hidden scrollbars. Owns: `scripts/ui/TouchScrollContainer.gd`,
  scrolling scenes, UI tests.
- `D21 DONE` Test runner awaits each test so gestures can be exercised across real frames.
  Owns: `tests/run_tests.gd`.
- `B33 DONE` Petting is a stroke across the avatar; a tap does nothing. Bilingual hint updated,
  and the reaction draws its voice from a three-clip no-repeat pool.
  Owns: `scripts/ui/BlobCharacter.gd`, blob scene audio, localization, UI tests.

Claim the lowest-numbered unblocked task in your track. Only the stated owner changes the task's
owned files; coordinate contract changes through the owning track.
