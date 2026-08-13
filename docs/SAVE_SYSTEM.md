# Save and Persistence System

This document describes what the code does today. It is written from `scripts/autoload/SaveManager.gd`,
`scripts/autoload/SettingsManager.gd`, `scripts/autoload/AppState.gd`, and the models in
`scripts/app/`. When this file and any other document disagree, the code wins and this file is the
one to correct first.

Current save version: **10**.

## Two files, two purposes

| File | Owner | Format | Contains |
|---|---|---|---|
| `user://profile.json` | `SaveManager` | JSON, pretty-printed | Everything the child earned: mastery, coins and the coin ledger, cosmetics, streak, achievements, tutorial state, nickname, profile id, sync bookkeeping |
| `user://settings.cfg` | `SettingsManager` | Godot `ConfigFile` | Device preferences: language, music/SFX volume, mute, haptics |

They are deliberately separate. Language and volume are properties of the device, not of the child's
progress, and a reset profile must not reset them.

Two sidecar files exist beside the profile:

- `profile.json.bak` — the previous save, kept as the recovery copy.
- `profile.json.tmp` — exists only during a write. A leftover one means the process died mid-save;
  it is overwritten by the next write and never read.

`user://` resolves to the app-private data directory: `%APPDATA%\Godot\app_userdata\Numblop\` on
Windows, the app sandbox on Android, and origin-scoped IndexedDB storage in a browser.

## `profile.json` — the single progress file

There is exactly one profile. There are no slots, no accounts, and no per-child selection.

Every write goes through `SaveManager.save_game_state()`, which rewrites the **whole** file. Callers
that only change one thing (a purchase, a nickname) pass the rest through unchanged, and any argument
left out is re-read from disk before writing, so no save path can silently drop another system's data.

### Current shape

```json
{
  "version": 10,
  "save_counter": 4213,
  "updated_at_unix": 1786000000,
  "highest_unlocked_index": 0,
  "mastery": { "2_x_0": 0, "2_x_1": 0, "…": 0, "9_x_9": 0 },
  "last_practiced": { "2_x_0": 0, "…": 0, "9_x_9": 0 },
  "coins": 0,
  "experience": 0,
  "completed_sessions": 0,
  "earned_rounds": 0,
  "earned_milestones": 0,
  "cosmetics": {
    "unlocked_body_colors": ["green"],
    "selected_body_color": "green",
    "unlocked_belly_colors": ["cream"],
    "selected_belly_color": "cream",
    "unlocked_hats": ["hat_none"],
    "selected_hat": "hat_none",
    "unlocked_glasses": ["glasses_none"],
    "selected_glasses": "glasses_none",
    "unlocked_necklaces": ["necklace_none"],
    "selected_necklace": "necklace_none",
    "unlocked_footwear": ["footwear_none"],
    "selected_footwear": "footwear_none"
  },
  "streak": {
    "current_count": 0,
    "all_time_high": 0,
    "milestones": [
      { "count": 12, "ended_at_unix": 1785765600, "utc_offset_minutes": 120 }
    ]
  },
  "achievements": { "granted": [] },
  "onboarding": { "completed": false, "step": 0 },
  "nickname": "",
  "profile_id": "9f1c…",
  "cloud": {
    "last_synced_counter": 0,
    "last_synced_at_unix": 0,
    "player_id": ""
  }
}
```

### Field reference

| Field | Type | Written by | Rules on load |
|---|---|---|---|
| `version` | int | `SaveManager.SAVE_VERSION` | Read by `SaveMigration` to decide which migration steps to run, and to detect a save from a newer build. |
| `save_counter` | int ≥ 0 | `SaveManager` | Increments on **every** write and never resets. The ordering signal a wrong device clock cannot corrupt. A non-numeric value reads as `0`. |
| `updated_at_unix` | int | `SaveManager` | Informational; only ever a tie-breaker of last resort. `SaveManager.clock_override` lets a test freeze it. |
| `highest_unlocked_index` | int `0–7` | `LearningProfile` | Clamped to the table range, then `_advance_unlocks()` re-derives any unlock the mastery values already earn. Never decreases. |
| `mastery` | 80 × `"<table>_x_<multiplier>"` → int | `LearningProfile` | Only known keys are copied; each value is clamped to `0–100`. Unknown keys are dropped, missing keys stay `0`. |
| `last_practiced` | 80 × fact key → unix seconds | `LearningProfile` | `0` means "never practised", which sorts as longest-waiting. Supplied by `SessionController`, never read from a clock inside `scripts/core/`. |
| `coins` | int ≥ 0 | `LocalProgress` | The authoritative balance at runtime. Negative values clamp to `0`. |
| `experience` | int ≥ 0 | `LocalProgress` | Also the lifetime correct-answer count (one XP per correct answer). |
| `completed_sessions` | int ≥ 0 | `LocalProgress` | If it is `0` while `experience > 0`, it is back-filled to `1`: that save predates the counter but proves at least one finished round. |
| `earned_rounds` | int ≥ 0 | `LocalProgress` | Lifetime coins from finished rounds. Monotonic. See "The coin ledger". |
| `earned_milestones` | int ≥ 0 | `LocalProgress` | Lifetime coins from mastery-band milestones. Monotonic. |
| `cosmetics` | 6 `unlocked_*` arrays + 6 `selected_*` ids | `LocalCosmetics` | Item ids are validated against `CosmeticCatalog`; unknown ids are dropped. The free default of each category is always present. A `selected_*` id that is not owned falls back to the category default. |
| `streak` | `current_count`, `all_time_high`, `milestones[]` | `LocalStreak` | Milestones must be strictly increasing in `count`; any row that is not is dropped. `utc_offset_minutes` is clamped to ±14 h. `all_time_high` is raised to the highest surviving milestone. |
| `achievements.granted` | array of achievement ids | `LocalAchievements` | Ids are validated against `AchievementCatalog`; unknown and duplicate ids are dropped. This set is the only thing that makes an achievement reward one-time, **and** the source the ledger derives achievement earnings from. |
| `onboarding` | `completed` bool, `step` int | `LocalOnboarding` | Anything that is not a real bool counts as "not finished", so a corrupt save replays the tutorial rather than skipping it. |
| `nickname` | string, ≤ 16 chars | `LocalNickname.sanitize` | Control characters stripped, trimmed, truncated to 16. Optional; empty is normal. |
| `profile_id` | 32 lowercase hex chars | `SaveManager` | 16 random bytes from `Crypto`, generated on the first save and preserved by every later one, **including a profile reset** (see "Resetting"). A device-local pseudonym that links to no identity. |
| `cloud` | `last_synced_counter`, `last_synced_at_unix`, `player_id` | `LocalCloudSync` | Play Games acknowledgement and account binding. Carried through validated on every save. Non-numeric counters read as `0`, so a corrupt value cannot suppress a future upload. |

Unknown top-level fields are **preserved**. If a newer build writes something this build does not
know, it is round-tripped rather than deleted, so a downgrade — or an older device handling a newer
cloud snapshot — cannot silently drop data. `SaveManager.KNOWN_FIELDS` is the list that decides this.

Before combining two saves that both contain progress, `SaveManager` writes the exact local parent
to `profile.json.premerge`. The ordinary `.bak` protects one atomic write; `.premerge` protects the
merge decision and is cleared only after the uploaded JSON has been read back exactly. An unresolved
Play conflict deliberately leaves this copy in place. `save_merged_state()` seeds the next
`save_counter` above both parents, so a remote parent with a higher counter cannot make the merged
result look stale.

### The coin ledger

`coins` is a balance, and balances cannot be merged: two devices that each earn 100 coins and each
buy a different hat both read `0`, and nothing in those two numbers says the child owns two hats.
The save therefore also records **what was earned**, in a form that survives a merge.

`CoinLedger` (`scripts/app/CoinLedger.gd`) owns the arithmetic. It is pure and static, so a future
cloud merge calls exactly the same code the running game does. Four terms:

| Term | Where it comes from | Why it merges |
|---|---|---|
| `earned_rounds` | stored, monotonic | `max` of two devices is correct |
| `earned_milestones` | stored, monotonic | `max` of two devices is correct |
| achievement earnings | **derived** — `Σ AchievementCatalog.reward_coins(id)` over `granted` | the granted set unions cleanly |
| spending | **derived** — `Σ CosmeticCatalog` price of every paid item owned | the owned sets union cleanly |

```
balance = max(0, earned_rounds + earned_milestones + achievement_coins - spent_coins)
```

Achievement earnings are deliberately *not* stored: a stored total and the granted set would be two
sources for the same number with nothing keeping them in step.

**The invariant:** for any state reachable by playing, `CoinLedger.balance(...)` equals the stored
`coins`. The stored balance stays authoritative at runtime — the ledger is not re-derived on load —
but a divergence means a bug. `tests/state/test_coin_ledger.gd` walks the real earning and spending
paths and asserts the invariant after each one.

`CloudSaveMerge` is the one caller that *does* re-derive the balance, because that is the case a
stored balance cannot survive. Its rules are in [`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md) §7;
the summary is that everything earned merges upward and only the balance is approximated, downward.

### When a save happens

Writes are frequent and small, and every one is a full-file rewrite:

- **After every submitted answer** — `SessionController._save_after_answer()` persists mastery and
  `last_practiced` immediately, so a killed app never loses answered questions.
- **On a mastery-band crossing** — the 5-coin bonus is applied to `LocalProgress` before that same
  per-answer save, so the coins and the mastery that earned them land together.
- **On a finished round** — `LocalProgress.apply_completed_session()` writes coins, XP, the
  incremented `completed_sessions`, and the raised `earned_rounds` in one save. The counter and the
  ledger bucket are both rolled back if the write fails, so a reward that never reached disk cannot
  survive in the ledger.
- **On an achievement grant** — `AppState.sync_achievements()` writes the granted ids and the coin
  reward together. If the write fails, the coins and the granted flags are both rolled back and the
  achievement is re-evaluated on the next opportunity.
- **On a purchase or equip** — `AppState._save_state_with_cosmetics()`.
- **On a nickname change, a tutorial step, and tutorial completion.**

`AppState` holds the loaded state in memory and is the only thing that calls `SaveManager` during
play. Scenes never write saves.

### What is deliberately *not* saved

- **The active question session.** An interrupted round (app paused, Android Back, force-stop) is
  discarded by `AppState._interrupt_unfinished_session()`. Mastery from answers already submitted is
  already on disk and stays; the unfinished round grants no chest and is not resumed.
- **Any answer log or timing history.** Only the aggregate mastery value and the `last_practiced`
  stamp survive a question.

## Durability: atomic writes, backup, and recovery

`SaveManager._write_atomically()`:

1. writes the full JSON to `profile.json.tmp` and closes it;
2. renames the existing `profile.json` to `profile.json.bak`, replacing any previous backup;
3. renames `profile.json.tmp` over `profile.json`.

Both renames replace atomically on every platform Godot targets. `FileAccess.WRITE` truncates on
open, so writing in place would mean a process killed mid-write leaves a half file that parses as
nothing and loads as a brand-new profile — this sequence removes that window. A crash between steps
2 and 3 leaves the previous save under the backup name, which is exactly what loading falls through
to.

Failing to refresh the backup is a warning, not a failure: losing the safety net is not a reason to
lose the save.

The rename pair was verified by hand on Windows **and in the Web build**, where `user://` is a
browser-backed virtual filesystem rather than real files: continue an existing profile, play a round,
buy an item, reload the page, progress intact. That check matters because a failed commit rename on
Web would fail every save — worse than the truncation this replaced.

`SaveManager._load_state_dictionary()` tries in order:

1. `profile.json` — if it parses to a non-empty object, migrate and use it;
2. `profile.json.bak` — same, and increment `SaveManager.recovered_loads`;
3. otherwise return empty, meaning a fresh profile.

A missing primary with a readable backup is treated identically to a corrupt one, because it is the
crash-between-renames case. `recovered_loads` exists so a test can assert that recovery actually
happened rather than merely that nothing crashed; nothing in the game reads it.

`SaveManager.delete_profile(path)` removes the profile, the backup, and any leftover temporary file.
Tests use it so one case cannot resurrect another's data through the backup.

## Versioning and migration

`SAVE_VERSION` is `10`, defined as `SaveMigration.CURRENT_VERSION` so the two cannot drift.

Two mechanisms work together:

- **Field-tolerant loading** handles an *added* field for free. Each model takes a dictionary,
  ignores what it does not recognise, and substitutes a documented default for whatever is missing.
  `LearningProfile.from_dictionary()` does the same for the 80 facts.
- **`SaveMigration`** handles the other kind of change: a field whose value must be **computed** from
  other fields, which no default can stand in for. It runs on every loaded dictionary before any
  model sees it.

Migration is in-memory only. Booting an old profile never writes to it; the migrated shape lands on
disk with the next ordinary save — the same rule the pre-tutorial adoption in `AppState` follows.

Each step is guarded by the fields it produces rather than by the version alone, so re-running a
migration is a no-op. That matters because an older build round-trips a newer save and stamps its own
version on the way out, so a step can meet a dictionary it has already produced.

### Migration history

| To | Adds | Migration work |
|---|---|---|
| 7 | `nickname`, `profile_id` | none — defaults suffice |
| 8 | `achievements`, `completed_sessions` | none, beyond the `experience > 0` back-fill in `LocalProgress` |
| 9 | `onboarding` | none — plus `AppState` adopting a save with finished rounds as onboarded |
| 10 | `save_counter`, `updated_at_unix`, `cloud`, `earned_rounds`, `earned_milestones` | **the ledger back-fill**: `earned_rounds = max(0, coins + derived_spent − derived_achievement_coins)`, with `earned_milestones = 0` |

The v10 back-fill attributes everything not derivable to rounds. The split between rounds and
milestones cannot be recovered after the fact, and only the sum is ever used — so the reconstructed
ledger reproduces the exact balance the save already had, which is what
`tests/state/test_save_migration.gd` asserts.

### A save from a newer build

`SaveMigration.is_from_newer_build()` reports it. The local game keeps playing regardless — refusing
to load would look like data loss to a child — and unknown-field preservation means the round trip
does not destroy anything. It matters for a **cloud snapshot**, where overwriting a newer schema
really would destroy fields this build cannot represent; that rule is specified in
[`GOOGLE_PLAY_GAMES.md`](GOOGLE_PLAY_GAMES.md) §6.2.

### Adding a field in future

Adding a field is free. Renaming or re-meaning one is not: add a guarded step to `SaveMigration`,
bump `CURRENT_VERSION`, and freeze a fixture of the old payload in the migration test so the step
stays covered forever.

## `settings.cfg` — device preferences

```ini
[language]
locale="system"        ; "system" or a locale from LanguageCatalog

[audio]
music_volume=0.75      ; 0.0–1.0, applied to the Music bus
sfx_volume=0.9         ; 0.0–1.0, applied to the SFX bus
muted=false

[haptics]
enabled=true

[play_games]
enabled=true           ; cloud save through Play Games Services; on unless switched off
```

- `locale="system"` resolves through `SettingsManager.effective_locale()`: the device language when
  Numblop ships it, English otherwise, with `no`/`nn` folded to `nb`.
- An unknown saved locale is ignored and falls back to `system`.
- Volumes are clamped on load and applied to the `Music` and `SFX` audio buses.
- Missing file or missing keys → the defaults above.
- `SettingsManager.play_haptic()` is the only caller of `Input.vibrate_handheld`, so the toggle
  cannot be bypassed by a new call site.

Settings are written in place, without the atomic dance. A corrupt settings file costs the player a
volume slider, not their progress.

`play_games/enabled` lives here rather than in the profile on purpose: it records a decision about
this device, not a child's progress, so resetting a profile must not silently change it. It defaults
to **on** — a missing key or a settings file written before the key existed both read as on, so
nobody has to find a switch to get their progress backed up. Switching it off stops Numblop talking
to Play Games entirely; it does not sign the account out of Play, which is the account's business.

## Android backup

`user_data_backup/allow=true` in both Android presets, so `profile.json` and `settings.cfg` are
included in Android's own device-to-device transfer and cloud backup when the player's Google account
has backup enabled. This is Android's mechanism, not the app's — the app performs no networking and
the current privacy policy describes exactly this.

## Resetting

`AppState.reset_local_profile()` abandons any active session, replaces every model with a fresh
instance — including `onboarding`, so the tutorial replays — and writes the empty profile. Settings
are untouched.

**`profile_id` survives a reset.** The reset writes over the existing file rather than deleting it,
and `save_game_state` only generates an id when it finds none. `save_counter` likewise keeps
climbing, which is correct: a reset profile must not look older than what a cloud snapshot holds.

If a reset is ever meant to produce a new pseudonym — [`adr/0001`](adr/0001-teacher-classroom-mode.md)
assumes it does — that is a deliberate change to make, not something the code does today. Call
`SaveManager.delete_profile()` before the reset write to get that behaviour.

There is currently no in-game control that calls `reset_local_profile()`; it exists for tests and for
a future parent-facing action.

## Where the tests are

| Area | Test |
|---|---|
| Whole-file round trip, defaults, corrupt input | `tests/state/test_profile_persistence.gd` |
| Atomic write, backup, recovery, deletion | `tests/state/test_save_durability.gd` |
| Migration, ledger back-fill, write counter, cloud block, unknown fields | `tests/state/test_save_migration.gd` |
| Coin ledger arithmetic and the balance invariant | `tests/state/test_coin_ledger.gd` |
| Two-save merge: commutativity, monotonicity, balance recompute | `tests/state/test_cloud_save_merge.gd` |
| Snapshot payload, normal sync, schema refusal, unresolved conflict safety | `tests/state/test_play_games.gd` |
| Coins, XP, level, completed rounds, milestone bonus | `tests/state/test_progression_persistence.gd` |
| Cosmetic ownership and equip persistence | `tests/state/test_cosmetics_persistence.gd` |
| Streak counters and milestone rows | `tests/state/test_streak_persistence.gd` |
| One-time achievement grants, retroactive award | `tests/state/test_achievements_persistence.gd` |
| Nickname sanitising and `profile_id` stability | `tests/state/test_nickname_persistence.gd` |
| Tutorial state and pre-v9 adoption | `tests/state/test_onboarding_persistence.gd` |
| Settings file and audio bus application | `tests/state/test_settings_persistence.gd` |
| Pause / resume / Back discarding a round | `tests/state/test_android_lifecycle.gd` |

`AppState` writes the live save file, so tests must always pass an explicit temporary path to
`SaveManager` — and clean up with `SaveManager.delete_profile()` rather than deleting only the
primary file, or one case can recover another case's save through the backup and the suite starts
depending on its own order.
