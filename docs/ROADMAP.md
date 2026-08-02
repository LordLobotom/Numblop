# Numblop Roadmap

Legend: ☐ todo · ◐ in progress · ☑ done

## M0 — Foundation ☑

- Godot 4.6.2 project boots in a portrait layout.
- Public name, package ID, offline scope, and English/Czech contract documented.
- Deterministic learning model, local profile, test runner, and export presets exist.
- Windows and Android development environment is verified.

Acceptance: project imports without errors; complete tests pass; Windows and debug APK exports
are produced successfully.

## M1 — Playable learning loop ☐

- Short Numblop opening, remembered Czech/English choice, and Baloo 2 UI.
- Interactive blob home with idle/petting reactions and a shared coin/XP/level/streak bar.
- Outfit/Map/Home/Trophies/Settings crest navigation and a read-only multiplication-stage trail
  that continuously reflects didactic mastery, reveals a newly unlocked island, and exposes a
  centered bilingual ten-fact detail when an unlocked island is tapped.
- Trophies lists timestamped, strictly increasing correct-answer streak records.
- Settings with English/Czech crests, music/SFX volume, global mute, and confirmed game exit.
- Background music and friendly interaction sounds for Numblop, navigation, answers, and rewards.
- Home → 10-question adaptive practice → guaranteed reward chest → home.
- Four-choice, six-choice, and custom numeric-keypad interactions.
- Calm correct feedback; incorrect feedback shows the complete correct equation and waits for
  a tap. Response time remains measured silently.
- One chest tap with shake/haptic feedback, opening celebration, and coin/XP count-up.
- Mastery saved after every answer; an interrupted series is discarded without a reward.
- Responsive Czech and English UI on a physical Android device.
- Adaptive static Web build that fits a phone viewport and uses a 900×900 desktop reference.

Acceptance: a child can complete the complete repeating loop without instruction, receive a
reward, return to the blob, and relaunch without losing recorded mastery or earned totals.

## M2 — Feedback and accessibility ☐

- Session summary explains progress without exposing raw mastery scores as pressure.
- Reduced motion, haptics toggle, and readable feedback states.
- First usability pass with a fresh child/parent observer.
- Learning thresholds reviewed from play evidence, with decisions documented.

Acceptance: the loop is understandable without instruction and remains comfortable when the
child answers slowly or incorrectly.

## M3 — Cosmetics and progression refinement ◐

- Accuracy-linked coin/experience rewards replace the provisional fixed reward.
- The local cosmetic inventory and Outfit entry point support five shader-based body colors plus
  the supplied hats, glasses, and necklaces with persistent purchase/equip state.
- Persistent cross-series correct-answer streaks and timestamped personal-record milestones.
- Extend the rounded-card catalog with belly patterns, shoes, and future supplied artwork.
- Add visual/audio polish without changing the learning model or adding game modes.
- Keep all rewards local and free of dark patterns, advertisements, or purchases.

Acceptance: progression improves willingness to practice again without distracting from answers.

## M4 — Android release candidate ◐

- ☑ Final icons (adaptive foreground/background/monochrome), boot splash, store text and
  9:16 screenshots (`store/`), privacy disclosure (`docs/privacy/`, GitHub Pages), and
  versioning (1.0.0 / code 2). ☐ Release keystore generation remains a manual step.
- ☐ Signed AAB verified via `tools/verify-aab.ps1` and installed through an internal test track.
- ☐ Physical-device lifecycle, safe areas, package size, and offline behavior verified.
- Windows and Web builds remain convenient matching test targets.

Acceptance: the internal Play build installs, updates, runs fully offline, and retains its save.

## Future concept — Teacher / classroom mode

- Class join codes, pseudonymous class leaderboard, and teacher statistics are designed in
  [`docs/adr/0001-teacher-classroom-mode.md`](adr/0001-teacher-classroom-mode.md) (design
  only; no code, networking, or permission changes until a dedicated decision).

## Future concept — Endless trail

- Unlock Endless mode only after the player clears every `2×` through `9×` map island.
- Continue beyond the fixed campaign with gradually higher multiplication factors.
- Design and test separate selection, difficulty, persistence, and child-safety rules before
  implementation; the MVP adaptive algorithm and its exact 10-question sessions remain unchanged.
