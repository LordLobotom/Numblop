# Numblop Roadmap

Legend: ☐ todo · ◐ in progress · ☑ done

Status reviewed against the code on 2026-08-12 at version `0.4.1` / Play version code `13`, with 230
tests passing.

## M0 — Foundation ☑

- Godot 4.6.2 project boots in a portrait layout.
- Public name, package ID, offline scope, and localization contract documented.
- Deterministic learning model, local profile, test runner, and export presets exist.
- Windows and Android development environment is verified.

Acceptance: met.

## M1 — Playable learning loop ☑

- ☑ Short Numblop opening, remembered language choice, and Baloo 2 UI.
- ☑ Interactive blob home with idle/petting reactions and a shared coin/XP/level/streak bar.
- ☑ Outfit/Map/Home/Trophies/Settings crest navigation and a read-only multiplication-stage trail
  that continuously reflects didactic mastery, reveals a newly unlocked island, and exposes a
  centered localized ten-fact detail when an unlocked island is tapped.
- ☑ Trophies lists timestamped, strictly increasing correct-answer streak records.
- ☑ Settings with language crests, music/SFX volume, global mute, and confirmed game exit.
- ☑ Background music and friendly interaction sounds for Numblop, navigation, answers, and rewards.
- ☑ Home → adaptive practice → guaranteed reward chest → home.
- ☑ Four-choice, six-choice, and custom numeric-keypad interactions.
- ☑ Calm correct feedback; incorrect feedback shows the complete correct equation and waits for a tap.
  Response time remains measured silently.
- ☑ One chest tap with shake/haptic feedback, opening celebration, and coin/XP count-up.
- ☑ Mastery saved after every answer; an interrupted series is discarded without a reward.
- ☑ Adaptive static Web build that fits a phone viewport and uses a 900×900 desktop reference.
- ☐ Responsive UI verified on a physical Android device — the only remaining item, folded into `D18`.

Acceptance: a child can complete the full repeating loop without instruction, receive a reward,
return to the blob, and relaunch without losing recorded mastery or earned totals. Met in the
Windows and Web builds; the physical-device pass is outstanding.

## M2 — Feedback and accessibility ☑

- ☑ End-of-round summary explains progress with a per-fact dot scale rather than raw mastery scores.
- ☑ Domino-dot correction picture after every wrong answer.
- ☑ Haptics toggle, three deliberate vibration moments, and readable feedback states.
- ☑ One-time guided finger tutorial over the whole loop, resumable and never repeated.
- ☑ Drag-anywhere touch scrolling on every scrolling screen.
- ☐ First usability pass with a fresh child/parent observer.
- ☐ Learning thresholds reviewed from play evidence, with decisions documented.

Acceptance: the loop is understandable without instruction and remains comfortable when the child
answers slowly or incorrectly. The build-side work is done; the two open items need real observed
play, so they stay open until after the internal test track.

## M3 — Cosmetics and progression refinement ☑

- ☑ Accuracy-linked coin/experience rewards replaced the provisional fixed reward.
- ☑ Six cosmetic categories — body colour, belly colour, hats, glasses, necklaces, shoes — with
  persistent purchase/equip state, shader recolouring, and an Outfit entry point.
- ☑ Persistent cross-series correct-answer streaks and timestamped personal-record milestones.
- ☑ Achievements across first round, streak, XP, collection, and island tiers, with one-time coin
  rewards and retroactive evaluation of existing saves.
- ☑ Unified end-of-round page with an itemised reward breakdown.
- ☑ All rewards remain local and free of dark patterns, advertisements, or purchases.

Acceptance: met in build. Whether progression actually improves willingness to practise again is a
question for the usability pass in M2.

## M4 — Android release candidate ◐

- ☑ Final icons (adaptive foreground/background/monochrome), boot splash, store text and 9:16
  screenshots (`store/`), privacy disclosure (`docs/privacy/`).
- ☑ Version `0.4.1` / Play version code `13`, pinned across project and both Android presets by
  `tests/smoke/test_project_contract.gd`.
- ☑ AAB verification tooling (`tools/verify-aab.ps1`) and an interactive signing path that never
  places the keystore password in a file, variable, or shell history.
- ☐ **`D18` — release execution.** All remaining items are manual:
  - generate the release keystore outside the repository and back it up securely;
  - export and verify the signed AAB;
  - enable GitHub Pages so the privacy-policy URL resolves;
  - complete the physical-device checklist in [`RELEASES.md`](RELEASES.md), which also unblocks `D2`;
  - upload to the Play internal test track and complete the data-safety and content-rating answers.
- Windows and Web builds remain convenient matching test targets.

Acceptance: the internal Play build installs, updates, runs fully offline, and retains its save.

## M5 — Google Play Games Services ◐

Sign-in, cloud saves synchronised with the existing local save, and XP and best-streak leaderboards,
with the game remaining fully playable offline and signed-out. Full plan, including Play Console
setup, Families-policy and privacy consequences, and the testing strategy:
[`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md).

- ☑ **P0 — offline prerequisites (save version 10).** Atomic writes with a recoverable backup,
  fall-through loading, an explicit migration step, a monotonic `save_counter`, unknown-field
  preservation, the inert `cloud` block, and the coin ledger. Contains no networking and ships as a
  normal offline release; it closes a real truncation risk that predates any Play work.
- ☐ P0b — `CloudSaveMerge`, the pure two-save merge, unit-tested before any Play API exists.
- ☐ P1 — plugin spike, manifest and export-preset changes, sign-in only.
- ☐ P2 — cloud save.
- ☐ P3 — achievements mirrored to Play.
- ☐ P4 — the two leaderboards. Last on purpose: if Families or privacy review objects, this phase is
  dropped without touching anything before it.
- ☐ P5 — settings UI behind a parent gate, merge messaging, account-deletion path.

The networking phases deliberately break the current "no networking" product contract, so they do not
begin until `D18` has shipped an offline release and the change is accepted as a decision entry. The
privacy policy, Play Console data-safety declaration, and Families declarations are updated **before**
the first networking build reaches any track.

Acceptance: a signed-out player is unaffected in every way; a signed-in player can lose their device
and recover their progress; no conflict path can silently destroy a child's local progress.

## Future concept — Teacher / classroom mode

Class join codes, a pseudonymous class leaderboard, and teacher statistics are designed in
[`adr/0001-teacher-classroom-mode.md`](adr/0001-teacher-classroom-mode.md) (design only; no code,
networking, or permission changes until a dedicated decision). Its offline-first sync sketch predates
M5 and should be re-read against it if it is ever picked up.

## Future concept — Endless trail

- Unlock Endless mode only after the player clears every `2×` through `9×` map island.
- Continue beyond the fixed campaign with gradually higher multiplication factors.
- Design and test separate selection, difficulty, persistence, and child-safety rules before
  implementation; the current adaptive algorithm and its fixed round lengths remain unchanged.
