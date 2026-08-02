# Numblop Tasks

Status values: `TODO`, `WIP(@agent)`, `BLOCKED(reason)`, `DONE`.

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
- `B1 DONE` Opening/logo scene, remembered language choice, bundled Fredoka font, and license.
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

Claim the lowest-numbered unblocked task in your track. Only the stated owner changes the task's
owned files; coordinate contract changes through the owning track.
