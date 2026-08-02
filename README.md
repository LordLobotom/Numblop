# Numblop

<p align="center">
  <img src="ui/branding/numblop_wordmark.png" alt="Numblop" width="360">
</p>

Numblop is a friendly, offline multiplication-practice game for children, built with Godot 4.6.2
and GDScript. It is portrait-first on Android, runs in a centered portrait format on Windows, and
has an adaptive Web build that fits a phone while using a wider canvas on desktop. The complete
interface is available in English and Czech.

The Android package ID is permanently fixed as `cz.gutcloud.numblop`.

## Project status

The in-repository M1 learning loop is playable and covered by automated and responsive UI tests.
The remaining M1 release gate is hands-on validation on a physical Android device. Several local
progression and Cosmetics features originally planned for later milestones are already integrated.

## What is playable

- Remembered English/Czech opening flow and a portrait home screen with an interactive Numblop.
- Ten-question adaptive practice using four choices, six choices, or a custom numeric keypad.
- Calm answer feedback with no visible countdown; response time is measured only by the learning
  model.
- A guaranteed reward chest after a completed series. Each correct answer earns one coin and one
  XP, with a minimum completed-series reward of one coin and one XP.
- A winding map for the `2×` through `9×` tables, including continuous island progress, unlock
  celebrations, and a detailed view of all ten facts.
- Permanent next-island unlocking once at least 9 of 10 facts in the current table reach 80 mastery.
  The remaining weak fact continues to be reviewed.
- Traffic-light mastery presentation: red and yellow while learning, orange-gold when mastered,
  and green when automated.
- Coins, XP, level, and a correct-answer streak shared across practice series. Trophies records
  timestamped, increasing personal streak milestones.
- A local Cosmetics shop with shader-based body colors plus supplied hats, glasses, and necklaces.
  Purchases and equipped items persist on the device.
- Background music, interaction and reward sounds, separate music/SFX volumes, global mute, and a
  responsive in-game exit confirmation.

## Learning model

Numblop tracks all 80 ordered facts from the `2×` through `9×` tables independently. A session
always contains exactly ten adaptively selected questions using the canonical mix:

- 7 from the table currently being learned,
- 2 from older weak facts,
- 1 from older automated facts.

Eligible facts are used before repetition whenever the required pools allow it, and selection is
deterministic when given the same seed. Mastery uses a 0–100 scale:

| Mastery | Interaction |
|---:|---|
| 0–59 | Choose from 4 answers |
| 60–89 | Choose from 6 answers |
| 90–100 | Enter the answer on the in-game keypad |

Correct answers add `+5` when fast or `+3` when slower; incorrect answers subtract `−2`. Mastery is
saved after every submitted answer. Table unlocks never roll back, even if an older fact later
drops below 80. The complete contract is documented in
[`docs/didactic_algorithm.md`](docs/didactic_algorithm.md).

## Offline and local by design

Numblop uses one local child profile and works without networking. The MVP has no accounts, cloud
sync, analytics, advertisements, remote configuration, or in-app purchases. Versioned saves keep
mastery, coins, XP, Cosmetics, settings, and streak records on the device and load older save
formats with safe defaults.

## Requirements

- Godot `4.6.2` with export templates.
- PowerShell on Windows.
- Android SDK/JDK and an authorized device for Android export and device checks.
- Godot threadless Web export templates; the repository helper can install them when missing.

Verify the local toolchain with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/check-environment.ps1
```

## Run

From the repository root:

```powershell
C:\Users\eMich\source\Godot\Godot_v4.6.2-stable_win64.exe --path .
```

The logical viewport is `390×844`; the Windows development window defaults to a centered
`450×900` portrait view. Web uses an adaptive canvas: a phone fits its available viewport, while
`900×900` is the wide desktop QA reference.

## Test and visual QA

Import the project headlessly and run the complete deterministic, persistence, localization, UI,
and smoke suite:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-tests.ps1
```

Generate and validate bilingual responsive screenshots at phone, Windows, and wide Web sizes:

```powershell
powershell -ExecutionPolicy Bypass -File tools/capture-responsive.ps1
```

With an unlocked Android phone connected and USB debugging authorized, export, install, launch,
and collect filtered logs with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/android-smoke.ps1
```

## Export

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target windows
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target android-debug
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Target web
```

If the Web templates are missing, run `tools/install-web-templates.ps1`. Validate the generated
HTML, JavaScript, WebAssembly, and pack files with `tools/web-smoke.ps1 -SkipExport`, or serve the
build locally by double-clicking `tools/start-web.cmd`. Do not open `build/web/index.html` directly:
WebAssembly and the game pack must be fetched over HTTP, and a `file://` launch will fail. These
commands produce ignored development artifacts in `build/`. Android release signing values must
come from environment variables and must never be stored in the repository. See
[`docs/RELEASES.md`](docs/RELEASES.md) for the signed AAB workflow and release checklist.

## Repository map

```text
scenes/                 Screens and reusable Godot scenes
scripts/core/           Pure deterministic learning rules and session generation
scripts/app/            Application services without scene ownership
scripts/autoload/       Local saves, settings, events, and runtime coordination
scripts/ui/             UI presentation and input handling
localization/           English/Czech source catalog
assets/                 Character, background, VFX, and Cosmetics artwork
ui/                     Theme, fonts, crests, branding, and UI shaders
audio/                  Music, SFX, and provenance notes
tests/                  Core, state, UI, and smoke tests
tools/                  Repeatable test, capture, device, and export commands
docs/                   Product, learning, architecture, decisions, and release contracts
```

The learning core never accesses scenes, autoloads, files, clocks, locale, or platform APIs.
Scenes present application state but do not calculate mastery, session quotas, or unlocking.

## Documentation

Start with [`AGENTS.md`](AGENTS.md) for repository rules and the source-of-truth hierarchy. The main
product documents are:

1. [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — product scope and experience.
2. [`docs/didactic_algorithm.md`](docs/didactic_algorithm.md) — canonical learning rules.
3. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical boundaries and save contract.
4. [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md) — English/Czech text contract.
5. [`docs/ROADMAP.md`](docs/ROADMAP.md) — milestone order and acceptance gates.
6. [`docs/TASKS.md`](docs/TASKS.md) — task status and ownership.
7. [`docs/DECISIONS.md`](docs/DECISIONS.md) — accepted implementation decisions.

## Bundled assets

Fredoka is bundled under the SIL Open Font License. Audio supplied for the project includes assets
from Pixabay; provenance and the applicable Pixabay Content License notes are recorded in
[`audio/README.md`](audio/README.md). No repository-wide software license is currently declared.
