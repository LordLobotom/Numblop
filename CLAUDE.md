# Numblop — Claude Code guide

Godot 4.6.2 + GDScript offline multiplication game for children. Portrait 390x844, ten languages
(en, cs, sk, de, es, fi, fr, nb, pl, sv).

**Read `AGENTS.md` first** — it is the source-of-truth hierarchy, engineering rules, and the
Track A–D ownership split. Track-scoped subagents live in `.claude/agents/` (learning-core,
ui-localization, app-state, qa-release); delegate to them for work confined to one track.

## Commands

```powershell
# Full test suite (230 tests). -GodotPath is required from a .claude/worktrees/ checkout.
powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1 -GodotPath "C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64_console.exe"

# Bilingual responsive screenshots -> artifacts/responsive/
powershell -ExecutionPolicy Bypass -File tools/capture-responsive.ps1 -GodotPath "C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64_console.exe"

# Headless boot smoke — REQUIRED after scene/layout changes; tests instantiate scenes but
# never run a real layout pass, so recursion crashes pass the suite undetected.
& "C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit-after 120
```

In a fresh worktree run `--headless --path . --import` once first, so `*.translation` binaries exist.

## Non-negotiables

- Every user-facing string is a key in `localization/strings.csv`, non-empty in all ten columns.
- Typed GDScript, 4-space indent; touch targets >= 48 px; no visible answer countdown.
- `scripts/core/` never touches scenes, autoloads, files, clock, locale, or platform APIs.
- UI displays state; it never computes mastery, quotas, or unlocks.
- Contract tests in `tests/ui/test_main_scene.gd` pin scene structure (unique names, grid
  columns, node paths) — changing UI structure means updating them deliberately, in the same change.
- Never trigger a real purchase/save from a test; `AppState` writes live save files. Pass an
  explicit temporary path to `SaveManager` instead — see `docs/SAVE_SYSTEM.md`.
