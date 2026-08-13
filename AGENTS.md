# Numblop Repository Operating Manual

## Product contract

- Numblop is a portrait-first, offline multiplication-practice game for Android, also
  exported as a centered portrait Windows application and an adaptive browser build.
- The permanent Android package ID is `cz.gutcloud.numblop`.
- Every practice series is adaptively selected and fixed in length: 10 questions up to the
  5x table (7 current / 2 older weak / 1 older automated) and 12 from the 6x table onwards
  (8 current / 3 older weak / 1 older automated). A fact counts as automated only at mastery
  100, and the automated slot always takes the fact that has waited longest.
- The game must remain **fully playable offline, signed out, and with no account**. That is the
  product promise and it does not expire. Do not add analytics, advertisements, remote
  configuration, or any third-party SDK beyond the approved one below.
- Play Games Services is approved as milestone M5 (`docs/GOOGLE_PLAY_GAMES.md`) and the Android
  builds request `INTERNET` and `ACCESS_NETWORK_STATE`. Cloud save is on by default and initialises
  automatically on Android; Google and Family Link own the account decision, and Numblop adds no
  gate of its own. All of it is confined to `scripts/autoload/PlayGames.gd` — no scene except the
  Settings screen, no learning rule, and no `scripts/app/` model may reference it, and a test
  enforces that. No game rule may ever wait on a network call, and a failed sign-in must cost a
  child nothing.
- `addons/GodotPlayGameServices/` is vendored third-party code. Never edit it; replace it wholesale
  from an upstream release and re-verify, per its `VENDORED.txt`.
- **Before any networking build reaches a Play track**, `docs/privacy/index.md`, the Play Console
  data-safety declaration, and the Families/target-audience answers must be updated in the same
  change. Today's published policy still says the app cannot send anything off the device.
- All ten shipped languages are required for every user-facing string. Never place
  user-facing prose directly in GDScript.
- The canonical learning behavior is `docs/didactic_algorithm.md`, including its confirmed
  implementation decisions. Do not change learning thresholds or scoring incidentally.

## Source-of-truth order

1. **The code.** Where a document and the shipped behavior disagree, the code is right and the
   document is the bug — fix the document in the same change, unless the code contradicts the
   didactic algorithm or a decision entry, which makes it a real bug worth raising.
2. `docs/GAME_DESIGN.md` — product scope and experience.
3. `docs/didactic_algorithm.md` — learning rules and mastery algorithm.
4. `docs/ARCHITECTURE.md` — technical boundaries and data flow.
5. `docs/SAVE_SYSTEM.md` — save files, persisted fields, and versioning.
6. `docs/LOCALIZATION.md` — ten-language text contract.
7. `docs/ROADMAP.md` — milestone order and acceptance gates.
8. `docs/DECISIONS.md` — accepted decisions that extend the documents above.
9. `docs/RELEASES.md` — Windows, Android, and Web delivery process.
10. `docs/TASKS.md` — historical task ledger, remaining manual release work, and active M5 tasks.

If documents conflict, use the highest applicable source and record the resolution in
`docs/DECISIONS.md`.

## Development baseline

- Engine: Godot `4.6.2`, GDScript, GL Compatibility renderer.
- Run: `C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64.exe --path .`.
- Test: `powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1` (274 tests).
- Boot smoke after any scene or layout change:
  `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 120`. Tests instantiate
  scenes but never run a real layout pass, so a recursion crash passes the suite undetected.
- Check Android tools: `powershell -ExecutionPolicy Bypass -File tools/check-environment.ps1`.
- Export Windows/debug APK/Web through `tools/export.ps1`; release signing credentials must
  come from environment variables or an encrypted password file kept outside the repository,
  never from repository files.

## Engineering rules

- Typed GDScript, four-space indentation, `snake_case` members, `PascalCase` classes.
- `scripts/core/` is deterministic and has no scene, autoload, filesystem, clock, or device
  dependency. Randomness always accepts an explicit seed.
- UI displays state; it does not calculate mastery, session quotas, or unlocking.
- Saves are local and backward-compatible through field-tolerant loading, not version branching.
  A corrupt save must fall back safely. See `docs/SAVE_SYSTEM.md` before changing a persisted field.
- Use translation keys for every user-facing string. Every language column must be non-empty.
- Baloo 2 is the primary UI font. Keep its OFL license with the asset and verify Czech glyphs.
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
- **Track C — App State & Persistence:** `scripts/autoload/`, `scripts/app/`,
  `tests/state/`, and Track-C task/decision lines. No scenes or core rule changes.
- **Track D — QA & Releases:** `project.godot`, `export_presets.cfg`, `tools/`, test runner
  infrastructure, `tests/smoke/`, `docs/RELEASES.md`, and Track-D task/decision lines.

Shared contracts require coordination. An agent needing a file outside its boundary should
request the owning track to make that change.

## Definition of done

A task is done only when its acceptance criteria pass, relevant tests were added or updated,
the complete suite passes, the project imports and boots without script errors, every language
column remains complete, the documentation it contradicts was corrected in the same change, and
the task status is updated. Export changes also require a real artifact check.
