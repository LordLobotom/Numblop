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

- Short Numblop opening, remembered Czech/English choice, and Fredoka UI.
- Interactive blob home with idle/petting reactions and local coin/XP/level totals.
- Home → 10-question adaptive practice → guaranteed reward chest → home.
- Four-choice, six-choice, and custom numeric-keypad interactions.
- Calm correct feedback; incorrect feedback shows the complete correct equation and waits for
  a tap. Response time remains measured silently.
- Five chest taps with shake/haptic feedback, opening celebration, and coin/XP count-up.
- Mastery saved after every answer; an interrupted series is discarded without a reward.
- Responsive Czech and English UI on a physical Android device.

Acceptance: a child can complete the complete repeating loop without instruction, receive a
reward, return to the blob, and relaunch without losing recorded mastery or earned totals.

## M2 — Feedback and accessibility ☐

- Session summary explains progress without exposing raw mastery scores as pressure.
- Sound/music controls, reduced motion, haptics toggle, and readable feedback states.
- First usability pass with a fresh child/parent observer.
- Learning thresholds reviewed from play evidence, with decisions documented.

Acceptance: the loop is understandable without instruction and remains comfortable when the
child answers slowly or incorrectly.

## M3 — Cosmetics and progression refinement ☐

- Review and tune the provisional reward amount and level-progression formula from M1/M2 play
  evidence.
- Add a small local cosmetic inventory and blob customization entry point.
- Add visual/audio polish without changing the learning model or adding game modes.
- Keep all rewards local and free of dark patterns, advertisements, or purchases.

Acceptance: progression improves willingness to practice again without distracting from answers.

## M4 — Android release candidate ☐

- Final icons, store text/screenshots, privacy disclosure, versioning, and release keystore.
- Signed AAB installed through an internal test track.
- Physical-device lifecycle, safe areas, package size, and offline behavior verified.
- Windows build remains a convenient matching test target.

Acceptance: the internal Play build installs, updates, runs fully offline, and retains its save.
