# Numblop Roadmap

Legend: ☐ todo · ◐ in progress · ☑ done

Status reviewed against the code on 2026-08-13 at version `0.4.2` / Play version code `14`, with 274
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
- ☑ Version `0.4.4` / Play version code `16`, pinned across project and both Android presets by
  `tests/smoke/test_project_contract.gd`.
- ☑ AAB verification tooling (`tools/verify-aab.ps1`) and an interactive signing path that never
  places the keystore password in a file, variable, or shell history.
- ☑ Release keystore generated and stored outside the repository, with signing and
  `tools/verify-aab.ps1` both routine. Producing a verified signed AAB is a solved, repeated step.
- ☑ `0.4.0` / code `12` uploaded to the Play internal test track, so the app entry exists and Play
  App Signing is enrolled — which is what later makes the Play Games credential setup possible.
- ☐ **`D18` — remaining manual items:**
  - complete the physical-device checklist in [`RELEASES.md`](RELEASES.md), which also unblocks `D2`;
  - upload the next build to the internal track when there is a reason to cut one.
- Windows and Web builds remain convenient matching test targets.

Acceptance: the internal Play build installs, updates, runs fully offline, and retains its save.

Note: no *further* upload is required to develop or test M5. The Play Games credential needs the Play
App Signing SHA-1, which code `12` already produced, and tester accounts cover the rest. Cutting an
offline release purely to unblock the integration would buy nothing and would mean two rounds of
store review — the second being the data-safety change that draws the scrutiny.

## M5 — Google Play Games Services ◐

Sign-in, cloud saves synchronised with the existing local save, and XP and best-streak leaderboards,
with the game remaining fully playable offline and signed-out. Full plan, including Play Console
setup, Families-policy and privacy consequences, and the testing strategy:
[`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md).

- ☑ **P0 — offline prerequisites (save version 10).** Atomic writes with a recoverable backup,
  fall-through loading, an explicit migration step, a monotonic `save_counter`, unknown-field
  preservation, the inert `cloud` block, and the coin ledger. Contains no networking and ships as a
  normal offline release; it closes a real truncation risk that predates any Play work.
- ☑ **P0b — `CloudSaveMerge`,** the pure two-save merge: commutative except for this device's own
  identity, never losing mastery, an item, an achievement, or a streak record, and recomputing the
  balance from the ledger rather than summing it. Unit-tested with no plugin, network, or device.
- ☑ **P1 — sign-in.** Play Console configured (PGS project in draft), the community plugin
  vendored and verified, network permissions and Gradle builds on both Android presets, the
  `PlayGames` wrapper, and the Settings row. Cloud save is on by default and initialises
  automatically on Android; Google and Family Link own the account decision. Still to confirm on
  real hardware: a tester account signing in.
- ◐ **P2 — cloud save.** The normal fixed-snapshot load/merge/upload path, first-sign-in handling,
  `.premerge` recovery, newer-schema refusal, account binding, and read-back acknowledgement are
  implemented. The vendored plugin emits both conflict candidates but exposes no supported way to
  resolve the conflict id, so Numblop merges them locally and blocks upload for that launch. Cloud
  convergence and the physical two-device matrix remain blocked on an upstream bridge plus hardware.
- ☐ P3 — achievements mirrored to Play.
- ☐ P4 — the two leaderboards. Last on purpose: if Families or privacy review objects, this phase is
  dropped without touching anything before it.
- ☐ P5 — merge messaging and the account-deletion path. Google and Family Link remain the account
  gate; Numblop does not add a second one.

The networking implementation is accepted in `DECISIONS.md`, but it remains outside every Play track
until the compliance and physical-device gates below are complete.

The bilingual privacy policy is public and the recorded Play Console Data safety declaration and
Families commitment are in `PLAY_CONSOLE_COMPLIANCE.md`. Target-audience and content-rating answers
still need their final release check **before** the first networking build reaches any track.

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
