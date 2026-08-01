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

- `A1 TODO` Session runtime/result model and per-answer audit records. Depends: A0.
  Owns: `scripts/core/SessionResult.gd`, `tests/core/test_session_result.gd`.
- `A2 TODO` Distractor-quality rules and edge-case tests for ×0, ×1, and repeated products.
  Depends: A0. Owns: `scripts/core/SessionGenerator.gd`, `tests/core/test_distractors.gd`.
- `B1 TODO` Opening/logo scene, remembered language choice, bundled Fredoka font, and license.
  Depends: B0. Owns: opening scene/script, `ui/fonts/`, localization keys, UI tests.
- `B2 TODO` Interactive blob home, idle/petting reactions, hearts, and coin/XP/level display.
  Depends: B1. Owns: home/blob scenes and scripts, UI tests.
- `B3 TODO` Practice screen for four- and six-choice modes. Depends: A0, B1.
  Owns: `scenes/screens/PracticeScreen.tscn`, `scripts/ui/PracticeScreen.gd`, UI tests.
- `B4 TODO` Custom numeric keypad and calm answer feedback, including the complete equation after
  a wrong answer. Depends: B3.
  Owns: keypad scene/script and UI tests.
- `B5 TODO` Five-tap chest, shake/open sequence, reward count-up, and return-home flow.
  Depends: A1, B2, B4, C2. Owns: reward scenes/scripts, translation keys, UI tests.
- `C1 TODO` Session controller, per-answer mastery saves, and discard-on-interruption behavior.
  Depends: A1. Owns: `scripts/app/SessionController.gd`, autoload changes, state tests.
- `C2 TODO` Local coin/XP/level persistence and atomic application of the fixed provisional M1
  reward. Depends: A1, C1. Owns: app state/save changes and state tests.
- `C3 TODO` Android pause/resume/back lifecycle handling. Depends: C1.
  Owns: app controller/autoload changes and state tests.
- `D1 TODO` Responsive screenshot smoke harness at 390×844 and 450×900. Depends: B3.
  Owns: QA scripts, smoke scenes/tests, `artifacts/` output contract.
- `D2 TODO` Physical Android install/run/log smoke command and checklist. Depends: C3.
  Owns: `tools/`, `docs/RELEASES.md`, smoke tests.

Claim the lowest-numbered unblocked task in your track. Only the stated owner changes the task's
owned files; coordinate contract changes through the owning track.
