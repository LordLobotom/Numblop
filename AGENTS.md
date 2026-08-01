# Numblop Repository Operating Manual

## Product contract

- Numblop is a portrait-first, offline multiplication-practice game for Android, also
  exported as a centered portrait Windows application.
- The permanent Android package ID is `cz.gutcloud.numblop`.
- Every MVP practice series contains exactly 10 adaptively selected questions using the
  canonical 7 current / 2 older weak / 1 older automated mix.
- MVP data stays on one device in one local child profile. Do not add accounts, analytics,
  advertisements, cloud services, networking, or remote configuration.
- English and Czech are both required. Never place user-facing prose directly in GDScript.
- The canonical learning behavior is `docs/didactic_algorithm.md`, including its confirmed
  implementation decisions. Do not change learning thresholds or scoring incidentally.

## Source-of-truth order

1. `docs/GAME_DESIGN.md` — product scope and experience.
2. `docs/didactic_algorithm.md` — learning rules and mastery algorithm.
3. `docs/ARCHITECTURE.md` — technical boundaries and data flow.
4. `docs/LOCALIZATION.md` — Czech/English text contract.
5. `docs/ROADMAP.md` — milestone order and acceptance gates.
6. `docs/TASKS.md` — claimable work and agent ownership.
7. `docs/DECISIONS.md` — accepted decisions that extend the documents above.
8. `docs/RELEASES.md` — Windows and Android delivery process.

If documents conflict, use the highest applicable source and record the resolution in
`docs/DECISIONS.md`.

## Development baseline

- Engine: Godot `4.6.2`, GDScript, GL Compatibility renderer.
- Run: `C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64.exe --path .`.
- Test: `powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1`.
- Check Android tools: `powershell -ExecutionPolicy Bypass -File tools/check-environment.ps1`.
- Export Windows/debug APK through `tools/export.ps1`; release signing credentials must
  come from environment variables, never repository files.

## Engineering rules

- Typed GDScript, four-space indentation, `snake_case` members, `PascalCase` classes.
- `scripts/core/` is deterministic and has no scene, autoload, filesystem, clock, or device
  dependency. Randomness always accepts an explicit seed.
- UI displays state; it does not calculate mastery, session quotas, or unlocking.
- Saves are versioned, local, and backward-compatible. A corrupt save must fall back safely.
- Use translation keys for every user-facing string. Both `en` and `cs` must be non-empty.
- Fredoka is the primary UI font. Keep its OFL license with the asset and verify Czech glyphs.
- Use Control containers, minimum 48 px touch targets, portrait-safe layout, and no visible
  answer countdown.
- Never commit `.godot/`, build products, export credentials, keystores, or passwords.
- Keep the game bootable and the tests green after each logical change.

## Agent tracks and ownership

When work is parallel, claim a task in `docs/TASKS.md` before editing. Only edit files owned
by the claimed task. Do not run two tasks with overlapping ownership.

- **Track A — Learning Core:** `scripts/core/`, `tests/core/`, learning-rule data, and Track-A
  task/decision lines. No scenes, autoloads, saves, or export files.
- **Track B — UI & Localization:** `scenes/`, `scripts/ui/`, `ui/`, `localization/`,
  `tests/ui/`, and Track-B task/decision lines. No learning calculations.
- **Track C — App State & Persistence:** `scripts/autoload/`, future `scripts/app/`,
  `tests/state/`, and Track-C task/decision lines. No scenes or core rule changes.
- **Track D — QA & Releases:** `project.godot`, `export_presets.cfg`, `tools/`, test runner
  infrastructure, `tests/smoke/`, `docs/RELEASES.md`, and Track-D task/decision lines.

Shared contracts require coordination. An agent needing a file outside its boundary should
request the owning track to make that change.

## Definition of done

A task is done only when its acceptance criteria pass, relevant tests were added or updated,
the complete suite passes, the project imports without script errors, both languages remain
complete, and the task status is updated. Export changes also require a real artifact check.
